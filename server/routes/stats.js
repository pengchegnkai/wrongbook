// routes/stats.js —— 统计
const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.get('/overview', async (req, res, next) => {
  try {
    const uid = req.userId;
    const total = await query('SELECT COUNT(*)::int AS n FROM questions WHERE user_id=$1', [uid]);
    const subjects = await query('SELECT COUNT(DISTINCT subject_id)::int AS n FROM questions WHERE user_id=$1', [uid]);
    const mastery = await query('SELECT mastery, COUNT(*)::int AS n FROM questions WHERE user_id=$1 GROUP BY mastery', [uid]);
    const today = await query('SELECT COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND review_today=true', [uid]);
    const verified = await query("SELECT COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND verification_status='verified'", [uid]);
    const unverified = await query("SELECT COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND verification_status='unverified'", [uid]);
    res.json({
      code: 0,
      data: {
        total: total.rows[0].n,
        subjectCount: subjects.rows[0].n,
        mastery: Object.fromEntries(mastery.rows.map(r => [r.mastery, r.n])),
        todayReview: today.rows[0].n,
        verifiedSources: verified.rows[0].n,
        pendingVerify: unverified.rows[0].n
      },
      message: 'ok'
    });
  } catch (e) { next(e); }
});

router.get('/subject/:id', async (req, res, next) => {
  try {
    const uid = req.userId;
    const byChapter = await query(
      'SELECT c.name AS chapter, COUNT(q.id)::int AS n FROM chapters c LEFT JOIN questions q ON q.chapter_id=c.id AND q.user_id=$1 WHERE c.subject_id=$2 GROUP BY c.name ORDER BY c.sort_order',
      [uid, req.params.id]
    );
    const mastery = await query('SELECT mastery, COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND subject_id=$2 GROUP BY mastery', [uid, req.params.id]);
    const errors = await query('SELECT error_type, COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND subject_id=$2 GROUP BY error_type', [uid, req.params.id]);
    res.json({ code: 0, data: { byChapter: byChapter.rows, mastery: mastery.rows, errors: errors.rows }, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/errors', async (req, res, next) => {
  try {
    const r = await query('SELECT error_type, COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND error_type IS NOT NULL GROUP BY error_type ORDER BY n DESC', [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/mastery', async (req, res, next) => {
  try {
    const r = await query('SELECT mastery, COUNT(*)::int AS n FROM questions WHERE user_id=$1 GROUP BY mastery', [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

// 周趋势
router.get('/weekly', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT to_char(date_trunc('day', created_at), 'MM-DD') AS day, COUNT(*)::int AS n
       FROM questions WHERE user_id=$1 AND created_at > now() - interval '7 days'
       GROUP BY 1 ORDER BY 1`, [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
