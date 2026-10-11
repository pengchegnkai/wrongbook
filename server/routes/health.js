// routes/health.js —— 健康检查（无需鉴权）
const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.get('/', async (req, res) => {
  let dbOk = false, modelOk = false, queueLen = 0;
  try { await query('SELECT 1'); dbOk = true; } catch (_) {}
  try {
    const r = await fetch('http://127.0.0.1:8080/health', { signal: AbortSignal.timeout(2000) });
    modelOk = r.ok;
  } catch (_) {}
  try {
    const r = await query("SELECT COUNT(*)::int AS n FROM local_records WHERE status='pending'");
    queueLen = r.rows[0].n;
  } catch (_) {}
  res.json({
    code: 0,
    data: { status: 'ok', db: dbOk, model: modelOk, queueLength: queueLen, time: new Date().toISOString() },
    message: 'ok'
  });
});

module.exports = router;
