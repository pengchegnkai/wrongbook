// middleware/cors.js —— 内网 CORS（白名单来自 .env CORS_ORIGINS，支持通配前缀如 http://192.168.*.*）
const allowedPatterns = (process.env.CORS_ORIGINS ||
  'http://localhost:*,http://127.0.0.1:*,http://192.168.*.*:*,http://10.*.*.*:*,http://172.16.*.*:*'
).split(',').map(s => s.trim()).filter(Boolean);

function isAllowed(origin) {
  if (!origin) return true; // 非浏览器客户端（curl、Flutter 直连）
  return allowedPatterns.some(pattern => {
    const rx = new RegExp('^' + pattern.replace(/[.*+?^${}()|[\]\\]/g, m => (m === '*' ? '.*' : '\\' + m)) + '$');
    return rx.test(origin);
  });
}

module.exports = function corsMiddleware(req, res, next) {
  const origin = req.headers.origin;
  if (origin && isAllowed(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization,X-API-Token');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }
  next();
};
