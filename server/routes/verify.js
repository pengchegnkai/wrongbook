// routes/verify.js —— 联网核验（依赖 services/verifyQuestion.js）
const express = require('express');
const { query } = require('../db');
const ensureUserScope = require('../middleware/ensureUserScope');
const { verifyQuestion } = require('../services/verifyQuestion');
const router = express.Router();

// 对指定错题联网核验，返回候选来源并写入 question_sources
router.post('/:id', ensureUserScope('questions'), async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    const q = await query('SELECT * FROM questions WHERE id=$1 AND user_id=$2', [id, req.userId]);
    if (!q.rows.length) return res.status(404).json({ code: 404, data: null, message: '不存在' });
    const question = q.rows[0];
    await query("UPDATE questions SET search_status='searching', updated_at=now() WHERE id=$1", [id]);

    try {
      const result = await verifyQuestion(question);
      // 写入候选来源
      await query('DELETE FROM question_sources WHERE question_id=$1 AND adopted=false', [id]);
      for (const s of result.sources) {
        await query(
          `INSERT INTO question_sources (question_id, provider, url, title, author, authority, snippet, similarity_score)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [id, s.provider, s.url, s.title, s.author, s.authority || 'C', s.snippet, s.similarityScore || null]
        );
      }
      await query(
        "UPDATE questions SET search_status='done', last_verified_at=now(), similarity_score=$2, updated_at=now() WHERE id=$1",
        [id, result.bestSimilarity || null]
      );
      await query('INSERT INTO verification_logs (question_id, status, detail) VALUES ($1,$2,$3)',
        [id, 'done', JSON.stringify({ count: result.sources.length })]);
      const sources = await query('SELECT * FROM question_sources WHERE question_id=$1 ORDER BY similarity_score DESC NULLS LAST', [id]);
      res.json({ code: 0, data: { sources: sources.rows, bestSimilarity: result.bestSimilarity }, message: 'ok' });
    } catch (searchErr) {
      await query("UPDATE questions SET search_status='failed', updated_at=now() WHERE id=$1", [id]);
      await query('INSERT INTO verification_logs (question_id, status, detail) VALUES ($1,$2,$3)',
        [id, 'failed', JSON.stringify({ error: searchErr.message })]);
      res.status(502).json({ code: 502, data: null, message: '联网核验失败：' + searchErr.message });
    }
  } catch (e) { next(e); }
});

module.exports = router;
