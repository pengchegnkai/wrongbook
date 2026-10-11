// routes/questions.js —— 错题 CRUD（全部按 user_id 过滤）
const express = require('express');
const { query, pool } = require('../db');
const ensureUserScope = require('../middleware/ensureUserScope');
const router = express.Router();

const FIELDS = ['subject_id','chapter_id','source','difficulty','original_question','my_answer','correct_answer',
  'analysis','error_type','error_reason','mastery','key_breakthrough','warning','same_type_signal','search_keywords'];

function buildFilters(userId, q) {
  const conds = ['user_id = $1']; const params = [userId]; let i = 2;
  if (q.subjectId) { conds.push(`subject_id=$${i++}`); params.push(q.subjectId); }
  if (q.chapterId) { conds.push(`chapter_id=$${i++}`); params.push(q.chapterId); }
  if (q.kpId) { conds.push(`id IN (SELECT question_id FROM question_kps WHERE kp_id=$${i++})`); params.push(q.kpId); }
  if (q.mastery) { conds.push(`mastery=$${i++}`); params.push(q.mastery); }
  if (q.errorType) { conds.push(`error_type=$${i++}`); params.push(q.errorType); }
  if (q.verificationStatus) { conds.push(`verification_status=$${i++}`); params.push(q.verificationStatus); }
  if (q.reviewToday === 'true') { conds.push('review_today=true'); }
  if (q.search) { conds.push(`(original_question ILIKE $${i} OR correct_answer ILIKE $${i} OR analysis ILIKE $${i})`); params.push(`%${q.search}%`); i++; }
  if (q.tag) { conds.push(`id IN (SELECT qt.question_id FROM question_tags qt JOIN tags t ON t.id=qt.tag_id WHERE t.name=$${i++})`); params.push(q.tag); }
  return { where: conds.join(' AND '), params, nextIdx: i };
}

router.get('/', async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page || '1', 10));
    const size = Math.min(100, Math.max(1, parseInt(req.query.pageSize || '20', 10)));
    const { where, params } = buildFilters(req.userId, req.query);
    const orderBy = { created_asc: 'created_at ASC', updated_desc: 'updated_at DESC' }[req.query.sort] || 'created_at DESC';
    const total = await query(`SELECT COUNT(*)::int AS n FROM questions WHERE ${where}`, params);
    const rows = await query(
      `SELECT q.*, s.name AS subject_name, c.name AS chapter_name,
              COALESCE((SELECT json_agg(kp.name) FROM question_kps qk JOIN knowledge_points kp ON kp.id=qk.kp_id WHERE qk.question_id=q.id), '[]') AS knowledge_points
       FROM questions q LEFT JOIN subjects s ON s.id=q.subject_id LEFT JOIN chapters c ON c.id=q.chapter_id
       WHERE ${where} ORDER BY ${orderBy} LIMIT ${size} OFFSET ${(page-1)*size}`,
      params
    );
    res.json({ code: 0, data: { items: rows.rows, total: total.rows[0].n, page, pageSize: size }, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/:id', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM questions WHERE id=$1 AND user_id=$2', [req.params.id, req.userId]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '不存在' });
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try {
    const b = req.body || {};
    if (!b.originalQuestion && !b.original_question) return res.status(400).json({ code: 400, data: null, message: '原题不能为空' });
    // 复习轮次：录入即排期 d1/d3/d7/d15
    const r = await query(
      `INSERT INTO questions (user_id, ${FIELDS.join(',')}, review_d1, review_d3, review_d7, review_d15)
       VALUES ($1, ${FIELDS.map((_, i) => '$' + (i + 2)).join(',')}, now()+interval '1 day', now()+interval '3 days', now()+interval '7 days', now()+interval '15 days')
       RETURNING *`,
      [req.userId, ...FIELDS.map(f => b[f] !== undefined ? b[f] : b[toCamel(f)])]
    );
    const q = r.rows[0];
    if (Array.isArray(b.kpIds) && b.kpIds.length) {
      for (const kpId of b.kpIds) await query('INSERT INTO question_kps (question_id, kp_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [q.id, kpId]);
    }
    if (Array.isArray(b.tags) && b.tags.length) {
      for (const name of b.tags) {
        const t = await query('INSERT INTO tags (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id', [name]);
        await query('INSERT INTO question_tags (question_id, tag_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [q.id, t.rows[0].id]);
      }
    }
    res.json({ code: 0, data: q, message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/batch', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const items = req.body && req.body.items;
    if (!Array.isArray(items)) return res.status(400).json({ code: 400, data: null, message: 'items 必须为数组' });
    await client.query('BEGIN');
    const ids = [];
    for (const b of items) {
      if (!b.original_question && !b.originalQuestion) continue;
      const r = await client.query(
        `INSERT INTO questions (user_id, original_question, my_answer, correct_answer, analysis, subject_id, error_type, mastery)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
        [req.userId, b.original_question || b.originalQuestion, b.my_answer || b.myAnswer || null,
         b.correct_answer || b.correctAnswer || null, b.analysis || null, b.subject_id || b.subjectId || null,
         b.error_type || b.errorType || null, b.mastery || 'red']
      );
      ids.push(r.rows[0].id);
    }
    await client.query('COMMIT');
    res.json({ code: 0, data: { ids, count: ids.length }, message: 'ok' });
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally { client.release(); }
});

router.put('/:id', ensureUserScope('questions'), async (req, res, next) => {
  try {
    const b = req.body || {};
    const sets = []; const params = []; let i = 1;
    for (const f of FIELDS) {
      const camel = toCamel(f);
      if (b[f] !== undefined || b[camel] !== undefined) {
        sets.push(`${f}=$${i++}`);
        params.push(b[f] !== undefined ? b[f] : b[camel]);
      }
    }
    if (!sets.length) return res.status(400).json({ code: 400, data: null, message: '无更新字段' });
    sets.push('updated_at=now()');
    params.push(req.params.id, req.userId);
    const r = await query(`UPDATE questions SET ${sets.join(',')} WHERE id=$${i++} AND user_id=$${i} RETURNING *`, params);
    if (Array.isArray(b.kpIds)) {
      await query('DELETE FROM question_kps WHERE question_id=$1', [req.params.id]);
      for (const kpId of b.kpIds) await query('INSERT INTO question_kps (question_id, kp_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [req.params.id, kpId]);
    }
    res.json({ code: 0, data: r.rows[0] || null, message: 'ok' });
  } catch (e) { next(e); }
});

router.delete('/:id', ensureUserScope('questions'), async (req, res, next) => {
  try {
    await query('DELETE FROM questions WHERE id=$1 AND user_id=$2', [req.params.id, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

// 来源列表
router.get('/:id/sources', ensureUserScope('questions'), async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM question_sources WHERE question_id=$1 ORDER BY similarity_score DESC NULLS LAST, id', [req.params.id]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

// 采纳来源
router.post('/:id/apply-source', ensureUserScope('questions'), async (req, res, next) => {
  try {
    const { sourceId } = req.body || {};
    const s = await query('SELECT * FROM question_sources WHERE id=$1', [sourceId]);
    if (!s.rows.length) return res.status(404).json({ code: 404, data: null, message: '来源不存在' });
    await query(
      `UPDATE questions SET answer_source_url=$1, answer_source_name=$2, answer_source_author=$3,
        answer_source_authority=$4, answer_source_accessed_at=now(), answer_source_snippet=$5,
        adopted_source_id=$6, verification_status='verified', last_verified_at=now(), updated_at=now()
       WHERE id=$7 AND user_id=$8`,
      [s.rows[0].url, s.rows[0].title, s.rows[0].author, s.rows[0].authority, s.rows[0].snippet, sourceId, req.params.id, req.userId]
    );
    await query('UPDATE question_sources SET adopted=true WHERE id=$1', [sourceId]);
    await query("UPDATE question_sources SET adopted=false WHERE question_id=$1 AND id<>$2", [req.params.id, sourceId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

function toCamel(s) { return s.replace(/_([a-z])/g, (_, c) => c.toUpperCase()); }

module.exports = router;
