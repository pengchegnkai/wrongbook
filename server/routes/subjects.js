// routes/subjects.js —— 学科/章节/知识点（全局字典，不按用户隔离，只读）
const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM subjects ORDER BY sort_order, id');
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/:id/chapters', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM chapters WHERE subject_id=$1 ORDER BY sort_order, id', [req.params.id]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/:id/kps', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT kp.* FROM knowledge_points kp JOIN chapters c ON c.id=kp.chapter_id WHERE c.subject_id=$1 ORDER BY kp.level, kp.id`,
      [req.params.id]
    );
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

// 全部章节
router.get('/chapters/all', async (req, res, next) => {
  try {
    const r = await query('SELECT c.*, s.name AS subject_name FROM chapters c JOIN subjects s ON s.id=c.subject_id ORDER BY s.sort_order, c.sort_order');
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

// 全部知识点
router.get('/kps/all', async (req, res, next) => {
  try {
    const r = await query('SELECT kp.*, c.name AS chapter_name FROM knowledge_points kp JOIN chapters c ON c.id=kp.chapter_id ORDER BY kp.chapter_id, kp.id');
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
