// routes/auth.js —— 注册/登录/刷新/设备管理
const express = require('express');
const bcrypt = require('bcryptjs');
const { query } = require('../db');
const tokens = require('../services/tokenService');
// index.js 挂载 /api/auth 时不带全局鉴权（register/login/refresh 必须公开），
// 需要登录态的端点在此逐个挂 authMiddleware（否则 req.userId 是 undefined）
const auth = require('../middleware/auth');

const router = express.Router();

// 登录限流：同 IP 5 次失败锁定 15 分钟（内存版，重启即清）
// 局限：单进程内存存储，多实例不共享；反代场景需 app.set('trust proxy') 正确取 IP
const failedMap = new Map();
function isLocked(ip) {
  const rec = failedMap.get(ip);
  if (!rec) return false;
  if (Date.now() - rec.first > 15 * 60 * 1000) { failedMap.delete(ip); return false; }
  return rec.count >= 5;
}
function recordFail(ip) {
  const rec = failedMap.get(ip) || { count: 0, first: Date.now() };
  if (Date.now() - rec.first > 15 * 60 * 1000) { rec.count = 0; rec.first = Date.now(); }
  rec.count++; failedMap.set(ip, rec);
}

async function logAction(userId, action, req, success, message) {
  await query(
    'INSERT INTO login_logs (user_id, action, ip, device_info, success, message) VALUES ($1,$2,$3,$4,$5,$6)',
    [userId, action, req.ip, req.headers['user-agent'] || '', success, message || '']
  );
}

// 用户名格式：3-20 位，字母/数字/下划线/中文（与 App 端注册页校验一致）
const USERNAME_RE = /^[A-Za-z0-9_]{3,20}$|^[\u4e00-\u9fa5A-Za-z0-9_]{3,20}$/u;

router.post('/register', async (req, res, next) => {
  try {
    const { username, password, nickname } = req.body || {};
    if (!username || !password) return res.status(400).json({ code: 400, data: null, message: '用户名和密码必填' });
    if (typeof username !== 'string' || !USERNAME_RE.test(username)) {
      return res.status(400).json({ code: 400, data: null, message: '用户名需 3-20 位：字母/数字/下划线/中文' });
    }
    if (String(password).length < 6) return res.status(400).json({ code: 400, data: null, message: '密码至少 6 位' });
    const dup = await query('SELECT 1 FROM users WHERE username=$1', [username]);
    if (dup.rows.length) return res.status(409).json({ code: 409, data: null, message: '用户名已存在' });
    const hash = await bcrypt.hash(password, 10);
    let r;
    try {
      r = await query(
        'INSERT INTO users (username, password_hash, nickname) VALUES ($1,$2,$3) RETURNING id, username, nickname, role, status',
        [username, hash, nickname || username]
      );
    } catch (e) {
      // 并发注册同名：唯一约束冲突（23505）返回 409 而非 500
      if (e && e.code === '23505') return res.status(409).json({ code: 409, data: null, message: '用户名已存在' });
      throw e;
    }
    await query('INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [r.rows[0].id]);
    await query('INSERT INTO user_ai_profile (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [r.rows[0].id]);
    const accessToken = tokens.signAccess(r.rows[0]);
    const refreshToken = await tokens.issueRefresh(r.rows[0].id, req);
    await logAction(r.rows[0].id, 'register', req, true);
    res.json({ code: 0, data: { user: r.rows[0], accessToken, refreshToken }, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/login', async (req, res, next) => {
  try {
    const ip = req.ip;
    if (isLocked(ip)) return res.status(429).json({ code: 429, data: null, message: '失败次数过多，请 15 分钟后再试' });
    const { username, password } = req.body || {};
    const r = await query('SELECT * FROM users WHERE username=$1', [username || '']);
    const user = r.rows[0];
    // bcrypt 异步版：同步 API 会阻塞事件循环 ~100ms，并发登录时拖慢所有请求
    const ok = user ? await bcrypt.compare(password || '', user.password_hash) : false;
    if (!user || !ok) {
      recordFail(ip);
      await logAction(user ? user.id : null, 'login', req, false, '用户名或密码错误');
      return res.status(401).json({ code: 401, data: null, message: '用户名或密码错误' });
    }
    if (user.status !== 'active') return res.status(403).json({ code: 403, data: null, message: '账号已被禁用' });
    await query('UPDATE users SET last_login_at=now() WHERE id=$1', [user.id]);
    const accessToken = tokens.signAccess(user);
    const refreshToken = await tokens.issueRefresh(user.id, req);
    await logAction(user.id, 'login', req, true);
    res.json({ code: 0, data: { user: { id: user.id, username: user.username, nickname: user.nickname, role: user.role }, accessToken, refreshToken }, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {};
    if (!refreshToken) return res.status(400).json({ code: 400, data: null, message: '缺少 refreshToken' });
    const result = await tokens.rotateRefresh(refreshToken, req);
    if (!result) return res.status(401).json({ code: 401, data: null, message: 'refresh token 无效' });
    // 禁用账号：rotateRefresh 只吊销不发新 token，accessToken 为 null
    if (result.status !== 'active' || !result.accessToken) {
      return res.status(403).json({ code: 403, data: null, message: '账号已被禁用' });
    }
    res.json({ code: 0, data: { accessToken: result.accessToken, refreshToken: result.refreshToken }, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/logout', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {};
    await tokens.revokeRefresh(refreshToken);
    await logAction(req.userId, 'logout', req, true);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/me', auth, async (req, res, next) => {
  try {
    const r = await query('SELECT id, username, nickname, avatar_url, role, status, last_login_at, created_at FROM users WHERE id=$1', [req.userId]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '用户不存在' });
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.put('/me', auth, async (req, res, next) => {
  try {
    const { nickname, avatarUrl } = req.body || {};
    await query('UPDATE users SET nickname=COALESCE($1,nickname), avatar_url=COALESCE($2,avatar_url), updated_at=now() WHERE id=$3', [nickname, avatarUrl, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/change-password', auth, async (req, res, next) => {
  try {
    const { oldPassword, newPassword } = req.body || {};
    const r = await query('SELECT password_hash FROM users WHERE id=$1', [req.userId]);
    if (!r.rows.length) return res.status(401).json({ code: 401, data: null, message: '用户不存在或已删除' });
    const ok = await bcrypt.compare(oldPassword || '', r.rows[0].password_hash);
    if (!ok) return res.status(401).json({ code: 401, data: null, message: '旧密码错误' });
    if (!newPassword || String(newPassword).length < 6) return res.status(400).json({ code: 400, data: null, message: '新密码至少 6 位' });
    await query('UPDATE users SET password_hash=$1, updated_at=now() WHERE id=$2', [await bcrypt.hash(newPassword, 10), req.userId]);
    await tokens.revokeAllForUser(req.userId);
    await logAction(req.userId, 'change-password', req, true);
    res.json({ code: 0, data: null, message: '密码已修改，其他设备已下线' });
  } catch (e) { next(e); }
});

router.get('/devices', auth, async (req, res, next) => {
  try {
    const r = await query(
      'SELECT id, device_info, ip, expires_at, created_at FROM refresh_tokens WHERE user_id=$1 AND revoked=false AND expires_at > now() ORDER BY created_at DESC',
      [req.userId]
    );
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/logout-device', auth, async (req, res, next) => {
  try {
    const { deviceId } = req.body || {};
    await query('UPDATE refresh_tokens SET revoked=true WHERE id=$1 AND user_id=$2', [deviceId, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
