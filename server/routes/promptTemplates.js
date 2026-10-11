// routes/promptTemplates.js —— 提示词模板 CRUD（按用户隔离）
const express = require('express');
const { query } = require('../db');
const ensureUserScope = require('../middleware/ensureUserScope');
const { renderTemplate } = require('../services/templateRenderer');
const router = express.Router();

router.get('/', async (req, res, next) => {
  try {
    const conds = ['user_id=$1']; const params = [req.userId];
    if (req.query.subject) { conds.push('(subject=$2 OR subject IS NULL)'); params.push(req.query.subject); }
    if (req.query.questionType) { conds.push('(question_type=$' + params.length + 1 + ' OR question_type IS NULL)'); params.push(req.query.questionType); }
    const r = await query(`SELECT * FROM prompt_templates WHERE ${conds.join(' AND ')} ORDER BY is_default DESC, updated_at DESC`, params);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/default', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM prompt_templates WHERE user_id=$1 AND is_default=true LIMIT 1', [req.userId]);
    res.json({ code: 0, data: r.rows[0] || null, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/:id', ensureUserScope('prompt_templates'), async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM prompt_templates WHERE id=$1', [req.params.id]);
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/', async (req, res, next) => {
  try {
    const { name, subject, courseType, questionType, templateContent, variables, isDefault } = req.body || {};
    if (!name || !templateContent) return res.status(400).json({ code: 400, data: null, message: 'name 与 templateContent 必填' });
    if (isDefault) await query('UPDATE prompt_templates SET is_default=false WHERE user_id=$1', [req.userId]);
    const r = await query(
      `INSERT INTO prompt_templates (user_id, name, subject, course_type, question_type, template_content, variables, is_default)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [req.userId, name, subject || null, courseType || null, questionType || null,
       templateContent, JSON.stringify(variables || {}), isDefault || false]);
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.put('/:id', ensureUserScope('prompt_templates'), async (req, res, next) => {
  try {
    const { name, subject, courseType, questionType, templateContent, variables, isDefault } = req.body || {};
    if (isDefault) await query('UPDATE prompt_templates SET is_default=false WHERE user_id=$1', [req.userId]);
    const r = await query(
      `UPDATE prompt_templates SET name=COALESCE($1,name), subject=COALESCE($2,subject), course_type=COALESCE($3,course_type),
        question_type=COALESCE($4,question_type), template_content=COALESCE($5,template_content),
        variables=COALESCE($6,variables), is_default=COALESCE($7,is_default), updated_at=now()
       WHERE id=$8 RETURNING *`,
      [name, subject, courseType, questionType, templateContent,
       variables ? JSON.stringify(variables) : null, isDefault, req.params.id]);
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

router.post('/:id/duplicate', ensureUserScope('prompt_templates'), async (req, res, next) => {
  try {
    const r = await query(
      `INSERT INTO prompt_templates (user_id, name, subject, course_type, question_type, template_content, variables, is_default)
       SELECT user_id, name || '（副本）', subject, course_type, question_type, template_content, variables, false
       FROM prompt_templates WHERE id=$1 RETURNING *`, [req.params.id]);
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

// 预览：用传入的变量渲染模板
router.post('/:id/preview', ensureUserScope('prompt_templates'), async (req, res, next) => {
  try {
    const r = await query('SELECT template_content FROM prompt_templates WHERE id=$1', [req.params.id]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '不存在' });
    const rendered = renderTemplate(r.rows[0].template_content, req.body || {});
    res.json({ code: 0, data: { rendered }, message: 'ok' });
  } catch (e) { next(e); }
});

router.delete('/:id', ensureUserScope('prompt_templates'), async (req, res, next) => {
  try {
    await query('DELETE FROM prompt_templates WHERE id=$1 AND user_id=$2', [req.params.id, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

module.exports = router;
