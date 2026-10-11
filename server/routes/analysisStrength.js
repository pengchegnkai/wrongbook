// routes/analysisStrength.js —— 思考强度
const express = require('express');
const { query } = require('../db');
const { STRENGTHS, resolveStrength } = require('../services/strengthResolver');
const router = express.Router();

router.get('/strengths', (req, res) => {
  res.json({ code: 0, data: STRENGTHS, message: 'ok' });
});

router.get('/strength-config', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM analysis_strength_configs WHERE user_id=$1 ORDER BY id', [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.put('/strength-config', async (req, res, next) => {
  try {
    const { subject, questionType, defaultStrength } = req.body || {};
    if (!STRENGTHS.some(s => s.id === defaultStrength)) {
      return res.status(400).json({ code: 400, data: null, message: '无效强度值' });
    }
    const exists = await query(
      'SELECT id FROM analysis_strength_configs WHERE user_id=$1 AND subject IS NOT DISTINCT FROM $2 AND question_type IS NOT DISTINCT FROM $3',
      [req.userId, subject || null, questionType || null]);
    if (exists.rows.length) {
      await query('UPDATE analysis_strength_configs SET default_strength=$1, updated_at=now() WHERE id=$2',
        [defaultStrength, exists.rows[0].id]);
    } else {
      await query(
        'INSERT INTO analysis_strength_configs (user_id, subject, question_type, default_strength) VALUES ($1,$2,$3,$4)',
        [req.userId, subject || null, questionType || null, defaultStrength]);
    }
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

// 解析指定条件下的实际强度（App 用于预览）
router.get('/resolve', async (req, res, next) => {
  try {
    const { subject, questionType } = req.query;
    const r = await query(
      'SELECT default_strength FROM analysis_strength_configs WHERE user_id=$1 AND subject IS NOT DISTINCT FROM $2 AND question_type IS NOT DISTINCT FROM $3 LIMIT 1',
      [req.userId, subject || null, questionType || null]);
    const strength = resolveStrength(r.rows[0] ? r.rows[0].default_strength : null);
    res.json({ code: 0, data: strength, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
