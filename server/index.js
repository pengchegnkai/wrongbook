// index.js —— 服务端入口
require('dotenv').config();
const express = require('express');
const path = require('path');
const { ensureSchema } = require('./db');
const corsMiddleware = require('./middleware/cors');
const authMiddleware = require('./middleware/auth');

const app = express();
const HOST = process.env.HOST || '0.0.0.0';
const PORT = parseInt(process.env.PORT || '3000', 10);

app.use(express.json({ limit: '20mb' }));
app.use(corsMiddleware);

// 静态托管（如导出文件、模型页面资源）
app.use('/static', express.static(path.join(__dirname, 'public')));

// 健康与网络发现（无需鉴权）
app.use('/api/health', require('./routes/health'));
app.use('/api/network', require('./routes/network'));

// 根路径：内网浏览器访问友好页（服务信息 + 接口清单）
app.get('/', (req, res) => {
  res.json({
    service: 'cuoti-server',
    version: '1.0.0',
    message: '错题本后端运行中。请使用 Flutter App 连接，或访问以下接口验证：',
    endpoints: {
      health: '/api/health',
      networkInfo: '/api/network/info',
      discover: '/api/network/discover',
      auth: 'POST /api/auth/register, /api/auth/login',
      docs: '其余业务接口需登录（JWT），由 App 调用'
    },
    time: new Date().toISOString()
  });
});

// 业务路由（需 JWT）
const auth = authMiddleware;
app.use('/api/auth', require('./routes/auth'));
app.use('/api/subjects', auth, require('./routes/subjects'));
app.use('/api/questions', auth, require('./routes/questions'));
app.use('/api/verify', auth, require('./routes/verify'));
app.use('/api/search', auth, require('./routes/search'));
app.use('/api/stats', auth, require('./routes/stats'));
app.use('/api/review', auth, require('./routes/review'));
app.use('/api/import-export', auth, require('./routes/importExport'));
app.use('/api/ai', auth, require('./routes/ai'));
app.use('/api/prompt-templates', auth, require('./routes/promptTemplates'));
app.use('/api/analysis', auth, require('./routes/analysisStrength'));
app.use('/api/ai-memory', auth, require('./routes/aiMemory'));
app.use('/api/ocr', auth, require('./routes/ocr'));

// 统一错误处理：不抛原始堆栈
app.use((err, req, res, next) => {
  console.error('[error]', err.message);
  res.status(err.status || 500).json({ code: err.status || 500, data: null, message: '服务器内部错误' });
});

async function start() {
  await ensureSchema();
  app.listen(PORT, HOST, () => {
    console.log(`[server] listening on http://${HOST}:${PORT}`);
    console.log(`[server] 局域网访问: http://<本机内网IP>:${PORT}/api/health`);
  });
}

start().catch(e => {
  console.error('[server] 启动失败:', e.message);
  process.exit(1);
});
