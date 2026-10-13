// middleware/auth.js —— JWT 鉴权，注入 req.userId
const { verifyAccess } = require('../services/tokenService');

module.exports = async function authMiddleware(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ code: 401, data: null, message: '未登录' });

    const payload = verifyAccess(token);
    // access token 30 分钟短期有效，不做逐请求吊销检查
    req.userId = payload.uid;
    req.username = payload.username;

    // 可选调试 token
    const apiToken = req.headers['x-api-token'];
    if (apiToken && process.env.API_TOKEN && apiToken === process.env.API_TOKEN) {
      req.debugToken = true;
    }
    next();
  } catch (e) {
    return res.status(401).json({ code: 401, data: null, message: '登录已过期，请重新登录' });
  }
};
