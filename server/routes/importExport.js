// routes/importExport.js —— 导入导出（仅当前用户数据）
const express = require('express');
const { query, pool } = require('../db');
const router = express.Router();

router.get('/json', async (req, res, next) => {
  try {
    const uid = req.userId;
    const [questions, templates, memories, profile, strength] = await Promise.all([
      query('SELECT * FROM questions WHERE user_id=$1 ORDER BY id', [uid]),
      query('SELECT * FROM prompt_templates WHERE user_id=$1', [uid]),
      query('SELECT * FROM user_ai_memory WHERE user_id=$1', [uid]),
      query('SELECT * FROM user_ai_profile WHERE user_id=$1', [uid]),
      query('SELECT * FROM analysis_strength_configs WHERE user_id=$1', [uid])
    ]);
    res.json({
      code: 0,
      data: {
        exportedAt: new Date().toISOString(),
        questions: questions.rows,
        promptTemplates: templates.rows,
        aiMemories: memories.rows,
        aiProfile: profile.rows[0] || null,
        strengthConfigs: strength.rows
      },
      message: 'ok'
    });
  } catch (e) { next(e); }
});

router.post('/json', async (req, res, next) => {
  const client = await pool.connect();
  try {
    const data = req.body && req.body.data ? req.body.data : req.body;
    if (!data || !Array.isArray(data.questions)) {
      return res.status(400).json({ code: 400, data: null, message: '格式错误：缺少 questions 数组' });
    }
    await client.query('BEGIN');
    let imported = 0;
    for (const q of data.questions) {
      await client.query(
        `INSERT INTO questions (user_id, original_question, my_answer, correct_answer, analysis, subject_id, error_type, error_reason, mastery, difficulty, source)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
        [req.userId, q.original_question || q.originalQuestion, q.my_answer || q.myAnswer || null,
         q.correct_answer || q.correctAnswer || null, q.analysis || null, q.subject_id || q.subjectId || null,
         q.error_type || q.errorType || null, q.error_reason || q.errorReason || null,
         q.mastery || 'red', q.difficulty || null, 'import']);
      imported++;
    }
    if (Array.isArray(data.promptTemplates)) {
      for (const t of data.promptTemplates) {
        await client.query(
          `INSERT INTO prompt_templates (user_id, name, subject, course_type, question_type, template_content, variables, is_default)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [req.userId, t.name, t.subject || null, t.course_type || t.courseType || null,
           t.question_type || t.questionType || null, t.template_content || t.templateContent,
           t.variables ? JSON.stringify(t.variables) : '{}', t.is_default || t.isDefault || false]);
      }
    }
    await client.query('COMMIT');
    res.json({ code: 0, data: { imported }, message: 'ok' });
  } catch (e) {
    await client.query('ROLLBACK');
    next(e);
  } finally { client.release(); }
});

router.get('/csv', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT q.id, s.name AS subject, c.name AS chapter, q.original_question, q.my_answer, q.correct_answer, q.analysis, q.error_type, q.mastery, q.created_at
       FROM questions q LEFT JOIN subjects s ON s.id=q.subject_id LEFT JOIN chapters c ON c.id=q.chapter_id
       WHERE q.user_id=$1 ORDER BY q.id`, [req.userId]);
    const esc = v => '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"';
    const header = ['id','subject','chapter','original_question','my_answer','correct_answer','analysis','error_type','mastery','created_at'];
    const lines = [header.join(',')];
    for (const row of r.rows) lines.push(header.map(h => esc(row[h])).join(','));
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', 'attachment; filename="cuoti-export.csv"');
    // BOM 以便 Excel 打开
    res.send('\ufeff' + lines.join('\n'));
  } catch (e) { next(e); }
});

module.exports = router;
