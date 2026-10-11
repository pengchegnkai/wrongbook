// routes/network.js —— 内网信息与发现（无需鉴权；发现接口只返回服务标识）
const express = require('express');
const os = require('os');
const router = express.Router();

function lanIps() {
  const out = [];
  for (const ifaces of Object.values(os.networkInterfaces())) {
    for (const it of ifaces) {
      if (it.family === 'IPv4' && !it.internal) out.push(it.address);
    }
  }
  return out;
}

router.get('/info', (req, res) => {
  const ips = lanIps();
  res.json({
    code: 0,
    data: {
      ips,
      port: parseInt(process.env.PORT || '3000', 10),
      modelPort: 8080,
      addresses: ips.map(ip => `http://${ip}:${process.env.PORT || 3000}`),
      hostname: os.hostname()
    },
    message: 'ok'
  });
});

// Flutter 扫描识别用
router.get('/discover', (req, res) => {
  res.json({ code: 0, data: { service: 'cuoti-server', version: '1.0.0' }, message: 'ok' });
});

module.exports = router;
