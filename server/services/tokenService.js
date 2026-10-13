// services/tokenService.js —— access/refresh token 统一签发、校验、轮换
// 设计：
// - access token：JWT，30 分钟有效，供 API 鉴权（middleware/auth.js 校验）
// - refresh token：96 位随机串，数据库只存 SHA256 哈希；每个设备登录/注册独立签发；
//   刷新时轮换（旧 token 吊销 + 发新 token），30 天过期
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { query } = require('../db');

const JWT_SECRET = () => process.env.JWT_SECRET || 'CHANGE_ME';
const ACCESS_TTL = '30m';
const REFRESH_DAYS = 30;

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

/// 校验 refresh token 并轮换：旧 token 吊销、发新 token。
/// 返回 { user:{id,username,nickname}, status, accessToken, refreshToken }；无效返回 null
async function rotateRefresh(refreshToken, req) {
  if (!refreshToken) return null;
  const r = await query(
    `SELECT rt.id AS rt_id, rt.user_id, u.id AS uid, u.username, u.nickname, u.status
     FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id
     WHERE rt.token_hash = $1 AND rt.revoked = false AND rt.expires_at > now()`,
    [hashToken(refreshToken)]
  );
  if (!r.rows.length) return null;
  const row = r.rows[0];
  await query('UPDATE refresh_tokens SET revoked = true WHERE id = $1', [row.rt_id]);
  const newRefresh = await issueRefresh(row.user_id, req);
  const user = { id: row.uid, username: row.username, nickname: row.nickname };
  return {
    user,
    status: row.status,
    accessToken: signAccess(user),
    refreshToken: newRefresh,
  };
}

/// 吊销单个 refresh token（登出当前设备）
function revokeRefresh(refreshToken) {
  if (!refreshToken) return Promise.resolve();
  return query('UPDATE refresh_tokens SET revoked = true WHERE token_hash = $1', [hashToken(refreshToken)]);
}

/// 吊销用户全部 refresh token（改密码/强制下线，其他设备全部失效）
function revokeAllForUser(userId) {
  return query('UPDATE refresh_tokens SET revoked = true WHERE user_id = $1', [userId]);
}

module.exports = { signAccess, verifyAccess, issueRefresh, rotateRefresh, revokeRefresh, revokeAllForUser, REFRESH_DAYS };
