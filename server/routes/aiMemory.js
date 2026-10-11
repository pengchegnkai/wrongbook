// routes/aiMemory.js —— AI 记忆管理（按用户隔离，可查看/编辑/删除）
const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM user_ai_memory WHERE user_id=$1 ORDER BY updated_at DESC LIMIT 200', [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try {
    const { memoryType, key, value, confidence, source } = req.body || {};
    if (!memoryType || !key || !value) return res.status(400).json({ code: 400, data: null, message: 'memoryType/key/value 必填' });
    const r = await query(
      `INSERT INTO user_ai_memory (user_id, memory_type, key, value, confidence, source)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [req.userId, memoryType, key, value, confidence || 0.5, source || 'explicit']);
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { value, confidence } = req.body || {};
    const r = await query(
      `UPDATE user_ai_memory SET value=COALESCE($1,value), confidence=COALESCE($2,confidence), updated_at=now()
       WHERE id=$3 AND user_id=$4 RETURNING *`,
      [value, confidence, req.params.id, req.userId]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '不存在' });
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    await query('DELETE FROM user_ai_memory WHERE id=$1 AND user_id=$2', [req.params.id, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
