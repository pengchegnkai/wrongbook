// routes/review.js —— 复习（艾宾浩斯：今天/1/3/7/15 天）
const express = require('express');
const { query } = require('../db');
const ensureUserScope = require('../middleware/ensureUserScope');
const router = express.Router();

const CARD_SELECT = `q.id, q.original_question, q.my_answer, q.correct_answer, q.analysis, q.mastery,
  q.error_type, q.answer_source_url, q.answer_source_name, q.answer_source_authority, q.verification_status,
  s.name AS subject_name`;

router.get('/today', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT ${CARD_SELECT} FROM questions q LEFT JOIN subjects s ON s.id=q.subject_id
       WHERE q.user_id=$1 AND q.review_today=true ORDER BY q.created_at`,
      [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/upcoming', async (req, res, next) => {
  try {
    const uid = req.userId;
    const groups = {};
    for (const d of ['d1', 'd3', 'd7', 'd15']) {
      const r = await query(
        `SELECT ${CARD_SELECT} FROM questions q LEFT JOIN subjects s ON s.id=q.subject_id
         WHERE q.user_id=$1 AND review_${d}::date = (now() + interval '${d === 'd1' ? 1 : d === 'd3' ? 3 : d === 'd7' ? 7 : 15} days')::date
         LIMIT 50`, [uid]);
      groups[d] = r.rows;
    }
    res.json({ code: 0, data: groups, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/cards', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT ${CARD_SELECT} FROM questions q LEFT JOIN subjects s ON s.id=q.subject_id
       WHERE q.user_id=$1 AND (q.review_today=true OR q.review_d1 < now() OR q.review_d3 < now() OR q.review_d7 < now() OR q.review_d15 < now())
       ORDER BY q.review_d1 NULLS LAST LIMIT 100`,
      [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

// 提交一次复习：result = again(红) / hard(黄) / good(绿)
router.post('/:id', ensureUserScope('questions'), async (req, res, next) => {
  try {
    const { result, note } = req.body || {};
    const id = req.params.id;
    await query('INSERT INTO review_logs (question_id, result, note) VALUES ($1,$2,$3)', [id, result || '', note || '']);
    // 掌握度与复习安排联动
    if (result === 'again') {
      await query("UPDATE questions SET mastery='red', review_today=true, review_d1=now()+interval '1 day', updated_at=now() WHERE id=$1", [id]);
    } else if (result === 'hard') {
      await query("UPDATE questions SET mastery='yellow', review_today=false, review_d3=now()+interval '3 days', updated_at=now() WHERE id=$1", [id]);
    } else if (result === 'good') {
      await query("UPDATE questions SET mastery='green', review_today=false, updated_at=now() WHERE id=$1", [id]);
    }
    // 隐式反馈 → AI 记忆
    if (result === 'again') {
      await query(
        `INSERT INTO user_ai_memory (user_id, memory_type, key, value, confidence, source)
         VALUES ($1,'weak_signal','question_review_again','复习再次答错（题目 ' || $2 || '）', 0.7, 'implicit')`,
        [req.userId, id]);
    }
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
