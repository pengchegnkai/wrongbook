// services/tokenService.js —— access/refresh token 统一签发、校验、轮换
// 设计：
// - access token：JWT，30 分钟有效，供 API 鉴权（middleware/auth.js 校验）
// - refresh token：96 位随机串，数据库只存 SHA256 哈希；每个设备登录/注册独立签发；
//   刷新时轮换（旧 token 吊销 + 发新 token），30 天过期
// - 轮换用单条原子 UPDATE ... WHERE revoked=false RETURNING 抢占，
//   并发携带同一 refresh token 只有一个请求成功（防轮换竞态）
// - 已吊销 token 被再次使用（疑似被盗）→ 级联吊销该用户全部 token
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { query } = require('../db');

const JWT_SECRET = () => process.env.JWT_SECRET || 'CHANGE_ME';
const ACCESS_TTL = '30m';
const REFRESH_DAYS = 30;

/// 启动时校验：JWT_SECRET 未设置或仍为占位值直接退出（拒绝静默用可猜密钥）
function assertSecretConfigured() {
  const s = process.env.JWT_SECRET;
  if (!s || s === 'CHANGE_ME' || s.length < 16) {
    console.error('[tokenService] 拒绝启动：JWT_SECRET 未设置、仍为占位值或长度 <16。请在 server/.env 设置强随机密钥');
    process.exit(1);
  }
}

/// 签发 access token（user 至少含 id、username）
function signAccess(user) {
  return jwt.sign({ uid: user.id, username: user.username }, JWT_SECRET(), { expiresIn: ACCESS_TTL });
}

/// 校验 access token；无效/过期会抛错，调用方自行捕获
function verifyAccess(token) {
  return jwt.verify(token, JWT_SECRET());
}

/// token 哈希（refresh token 只存哈希，防库泄露后 token 被直接利用）
function hashToken(t) {
  return crypto.createHash('sha256').update(t).digest('hex');
}

/// 为当前设备签发一个 refresh token，返回原始 token（明文只发给客户端）
async function issueRefresh(userId, req) {
  const raw = crypto.randomBytes(48).toString('hex');
  await query(
    'INSERT INTO refresh_tokens (user_id, token_hash, device_info, ip, expires_at) VALUES ($1,$2,$3,$4, now() + interval \'30 days\')',
    [userId, hashToken(raw), req.headers['user-agent'] || '', req.ip]
  );
  return raw;
}

/// 校验 refresh token 并轮换：旧 token 原子吊销、发新 token。
/// - 并发同 token：只有一个请求能成功吊销（rows.length 判断），其余返回 null
/// - 已吊销 token 被再次使用：疑似 token 被盗 → 级联吊销该用户全部 refresh token，返回 null
/// - 账号被禁用：只吊销旧 token，不发新 token，返回 { status } 供路由返回 403
/// 返回 { user:{id,username,nickname}, status, accessToken, refreshToken }；无效返回 null
async function rotateRefresh(refreshToken, req) {
  if (!refreshToken) return null;
  // 原子抢占：仅当 revoked=false 且未过期时吊销成功
  const r = await query(
    `UPDATE refresh_tokens rt SET revoked = true
     WHERE rt.token_hash = $1 AND rt.revoked = false AND rt.expires_at > now()
     RETURNING rt.id, rt.user_id`,
    [hashToken(refreshToken)]
  );
  if (!r.rows.length) {
    // 没抢到锁：区分"token 早已无效"与"有效 token 被重复使用（已被轮换吊销过）"
    const probe = await query(
      'SELECT user_id, revoked, expires_at FROM refresh_tokens WHERE token_hash = $1',
      [hashToken(refreshToken)]
    );
    if (probe.rows.length && probe.rows[0].revoked === true && probe.rows[0].expires_at > new Date()) {
      // 未过期的已吊销 token 再次出现 → 疑似被盗，级联吊销该用户全部 token
      console.warn('[tokenService] 检测到已吊销 refresh token 被重用，级联吊销该用户全部 token (user_id=%s)', probe.rows[0].user_id);
      await revokeAllForUser(probe.rows[0].user_id);
    }
    return null;
  }
  const revoked = r.rows[0];
  const u = await query('SELECT id, username, nickname, status FROM users WHERE id = $1', [revoked.user_id]);
  if (!u.rows.length) return null;
  const user = u.rows[0];
  if (user.status !== 'active') {
    // 禁用账号：旧 token 已吊销，绝不签发新 token
    return { user: { id: user.id, username: user.username, nickname: user.nickname }, status: user.status, accessToken: null, refreshToken: null };
  }
  const newRefresh = await issueRefresh(user.id, req);
  return {
    user: { id: user.id, username: user.username, nickname: user.nickname },
    status: user.status,
    accessToken: signAccess(user),
    refreshToken: newRefresh,
  };
}

/// 吊销单个 refresh token（登出当前设备）
function revokeRefresh(refreshToken) {
  if (!refreshToken) return Promise.resolve();
  return query('UPDATE refresh_tokens SET revoked = true WHERE token_hash = $1', [hashToken(refreshToken)]);
}

/// 吊销用户全部 refresh token（改密码/强制下线/盗用检测，其他设备全部失效）
function revokeAllForUser(userId) {
  return query('UPDATE refresh_tokens SET revoked = true WHERE user_id = $1', [userId]);
}

module.exports = { signAccess, verifyAccess, issueRefresh, rotateRefresh, revokeRefresh, revokeAllForUser, assertSecretConfigured, REFRESH_DAYS };
