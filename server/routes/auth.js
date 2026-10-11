// routes/auth.js —— 注册/登录/刷新/设备管理
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { query } = require('../db');

const router = express.Router();
const JWT_SECRET = () => process.env.JWT_SECRET || 'CHANGE_ME';
const ACCESS_TTL = '30m';
const REFRESH_DAYS = 30;

// 登录限流：同 IP 5 次失败锁定 15 分钟（内存版，重启即清）
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

function signAccess(user) {
  return jwt.sign({ uid: user.id, username: user.username }, JWT_SECRET(), { expiresIn: ACCESS_TTL });
}

function hashToken(t) { return crypto.createHash('sha256').update(t).digest('hex'); }

async function logAction(userId, action, req, success, message) {
  await query(
    'INSERT INTO login_logs (user_id, action, ip, device_info, success, message) VALUES ($1,$2,$3,$4,$5,$6)',
    [userId, action, req.ip, req.headers['user-agent'] || '', success, message || '']
  );
}

async function issueRefresh(userId, req) {
  const raw = crypto.randomBytes(48).toString('hex');
  await query(
    'INSERT INTO refresh_tokens (user_id, token_hash, device_info, ip, expires_at) VALUES ($1,$2,$3,$4, now() + interval \'30 days\')',
    [userId, hashToken(raw), req.headers['user-agent'] || '', req.ip]
  );
  return raw;
}

router.post('/register', async (req, res, next) => {
  try {
    const { username, password, nickname } = req.body || {};
    if (!username || !password) return res.status(400).json({ code: 400, data: null, message: '用户名和密码必填' });
    if (String(password).length < 6) return res.status(400).json({ code: 400, data: null, message: '密码至少 6 位' });
    const dup = await query('SELECT 1 FROM users WHERE username=$1', [username]);
    if (dup.rows.length) return res.status(409).json({ code: 409, data: null, message: '用户名已存在' });
    const hash = bcrypt.hashSync(password, 10);
    const r = await query(
      'INSERT INTO users (username, password_hash, nickname) VALUES ($1,$2,$3) RETURNING id, username, nickname, role, status',
      [username, hash, nickname || username]
    );
    await query('INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [r.rows[0].id]);
    await query('INSERT INTO user_ai_profile (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [r.rows[0].id]);
    const accessToken = signAccess(r.rows[0]);
    const refreshToken = await issueRefresh(r.rows[0].id, req);
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
    if (!user || !bcrypt.compareSync(password || '', user.password_hash)) {
      recordFail(ip);
      await logAction(user ? user.id : null, 'login', req, false, '用户名或密码错误');
      return res.status(401).json({ code: 401, data: null, message: '用户名或密码错误' });
    }
    if (user.status !== 'active') return res.status(403).json({ code: 403, data: null, message: '账号已被禁用' });
    await query('UPDATE users SET last_login_at=now() WHERE id=$1', [user.id]);
    const accessToken = signAccess(user);
    const refreshToken = await issueRefresh(user.id, req);
    await logAction(user.id, 'login', req, true);
    res.json({ code: 0, data: { user: { id: user.id, username: user.username, nickname: user.nickname, role: user.role }, accessToken, refreshToken }, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {};
    if (!refreshToken) return res.status(400).json({ code: 400, data: null, message: '缺少 refreshToken' });
    const h = hashToken(refreshToken);
    const r = await query(
      'SELECT rt.id, rt.user_id, u.username, u.status FROM refresh_tokens rt JOIN users u ON u.id=rt.user_id WHERE rt.token_hash=$1 AND rt.revoked=false AND rt.expires_at > now()',
      [h]
    );
    if (!r.rows.length) return res.status(401).json({ code: 401, data: null, message: 'refresh token 无效' });
    const row = r.rows[0];
    if (row.status !== 'active') return res.status(403).json({ code: 403, data: null, message: '账号已被禁用' });
    // 旧 token 吊销 + 换发新 token（轮换）
    await query('UPDATE refresh_tokens SET revoked=true WHERE id=$1', [row.id]);
    const newRefresh = await issueRefresh(row.user_id, req);
    res.json({ code: 0, data: { accessToken: signAccess(row), refreshToken: newRefresh }, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/logout', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {};
    if (refreshToken) await query('UPDATE refresh_tokens SET revoked=true WHERE token_hash=$1', [hashToken(refreshToken)]);
    await logAction(req.userId, 'logout', req, true);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/me', async (req, res, next) => {
  try {
    const r = await query('SELECT id, username, nickname, avatar_url, role, status, last_login_at, created_at FROM users WHERE id=$1', [req.userId]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '用户不存在' });
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.put('/me', async (req, res, next) => {
  try {
    const { nickname, avatarUrl } = req.body || {};
    await query('UPDATE users SET nickname=COALESCE($1,nickname), avatar_url=COALESCE($2,avatar_url), updated_at=now() WHERE id=$3', [nickname, avatarUrl, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/change-password', async (req, res, next) => {
  try {
    const { oldPassword, newPassword } = req.body || {};
    const r = await query('SELECT password_hash FROM users WHERE id=$1', [req.userId]);
    if (!bcrypt.compareSync(oldPassword || '', r.rows[0].password_hash)) {
      return res.status(401).json({ code: 401, data: null, message: '旧密码错误' });
    }
    if (!newPassword || String(newPassword).length < 6) return res.status(400).json({ code: 400, data: null, message: '新密码至少 6 位' });
    await query('UPDATE users SET password_hash=$1, updated_at=now() WHERE id=$2', [bcrypt.hashSync(newPassword, 10), req.userId]);
    await query('UPDATE refresh_tokens SET revoked=true WHERE user_id=$1', [req.userId]);
    await logAction(req.userId, 'change-password', req, true);
    res.json({ code: 0, data: null, message: '密码已修改，其他设备已下线' });
  } catch (e) { next(e); }
});

router.get('/devices', async (req, res, next) => {
  try {
    const r = await query(
      'SELECT id, device_info, ip, expires_at, created_at FROM refresh_tokens WHERE user_id=$1 AND revoked=false AND expires_at > now() ORDER BY created_at DESC',
      [req.userId]
    );
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/logout-device', async (req, res, next) => {
  try {
    const { deviceId } = req.body || {};
    await query('UPDATE refresh_tokens SET revoked=true WHERE id=$1 AND user_id=$2', [deviceId, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
