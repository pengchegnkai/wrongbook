// routes/search.js —— 搜索（题库 + AI 记忆 + 缓存）
const express = require('express');
const { query } = require('../db');
const { searchWeb } = require('../services/webSearch');
const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const kw = (req.query.q || '').trim();
    if (!kw) return res.status(400).json({ code: 400, data: null, message: '缺少关键词 q' });
    const uid = req.userId;
    const questions = await query(
      `SELECT id, subject_id, original_question, error_type, mastery FROM questions
       WHERE user_id=$1 AND (original_question ILIKE $2 OR analysis ILIKE $2 OR correct_answer ILIKE $2)
       ORDER BY created_at DESC LIMIT 20`,
      [uid, `%${kw}%`]);
    const memories = await query(
      `SELECT id, memory_type, key, value FROM user_ai_memory
       WHERE user_id=$1 AND (key ILIKE $2 OR value ILIKE $2) LIMIT 10`,
      [uid, `%${kw}%`]);
    const kps = await query(
      `SELECT kp.id, kp.name, c.name AS chapter FROM knowledge_points kp JOIN chapters c ON c.id=kp.chapter_id WHERE kp.name ILIKE $1 LIMIT 10`,
      [`%${kw}%`]);
    res.json({ code: 0, data: { questions: questions.rows, memories: memories.rows, knowledgePoints: kps.rows }, message: 'ok' });
  } catch (e) { next(e); }
});

// 网络搜索（代理给 webSearch 服务）
router.get('/web', async (req, res, next) => {
  try {
    const kw = (req.query.q || '').trim();
    if (!kw) return res.status(400).json({ code: 400, data: null, message: '缺少关键词 q' });
    // 缓存
    const cacheKey = `web:${kw}`;
    const cached = await query('SELECT payload FROM search_cache WHERE user_id=$1 AND cache_key=$2 AND created_at > now() - interval \'7 days\'', [req.userId, cacheKey]);
    if (cached.rows.length) return res.json({ code: 0, data: cached.rows[0].payload, message: 'ok（缓存）' });
    const results = await searchWeb(kw);
    await query('INSERT INTO search_cache (user_id, cache_key, payload) VALUES ($1,$2,$3) ON CONFLICT (user_id, cache_key) DO UPDATE SET payload=$3, created_at=now()',
      [req.userId, cacheKey, JSON.stringify(results)]);
    res.json({ code: 0, data: results, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
