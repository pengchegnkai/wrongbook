// scripts/seed.js —— 导入 data/seed.json 示例数据（幂等：subjects/chapters/kps/templates 按 name 去重）
// 用法：cd ~/cuoti/server && node scripts/seed.js
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool, ensureSchema } = require('../db');

async function main() {
  await ensureSchema();
  const seed = JSON.parse(fs.readFileSync(path.join(__dirname, '../../data/seed.json'), 'utf8'));

  // subjects
  const subjectId = {};
  for (const s of seed.subjects || []) {
    const r = await pool.query(
      'INSERT INTO subjects (name, sort_order) VALUES ($1,$2) ON CONFLICT (name) DO UPDATE SET sort_order=EXCLUDED.sort_order RETURNING id, name',
      [s.name, s.sort_order || 0]);
    subjectId[r.rows[0].name] = r.rows[0].id;
  }

  // chapters
  const chapterId = {};
  for (const c of seed.chapters || []) {
    if (!subjectId[c.subject]) { console.warn('跳过章节（学科不存在）:', c.name); continue; }
    const r = await pool.query(
      'SELECT id FROM chapters WHERE subject_id=$1 AND name=$2',
      [subjectId[c.subject], c.name]);
    if (r.rows.length) { chapterId[c.name] = r.rows[0].id; continue; }
    const ins = await pool.query(
      'INSERT INTO chapters (subject_id, name, sort_order) VALUES ($1,$2,$3) RETURNING id',
      [subjectId[c.subject], c.name, c.sort_order || 0]);
    chapterId[c.name] = ins.rows[0].id;
  }

  // knowledge_points
  for (const kp of seed.knowledge_points || []) {
    if (!chapterId[kp.chapter]) { console.warn('跳过知识点（章节不存在）:', kp.name); continue; }
    await pool.query(
      'SELECT id FROM knowledge_points WHERE chapter_id=$1 AND name=$2', [chapterId[kp.chapter], kp.name]).then(async r => {
        if (!r.rows.length) {
          await pool.query('INSERT INTO knowledge_points (chapter_id, name, level) VALUES ($1,$2,$3)',
            [chapterId[kp.chapter], kp.name, kp.level || 1]);
        }
      });
  }

  // prompt_templates（挂到 demo 用户或第一个用户）
  const u = await pool.query('SELECT id FROM users ORDER BY id LIMIT 1');
  if (u.rows.length && (seed.prompt_templates || []).length) {
    for (const t of seed.prompt_templates) {
      const exists = await pool.query('SELECT 1 FROM prompt_templates WHERE user_id=$1 AND name=$2', [u.rows[0].id, t.name]);
      if (!exists.rows.length) {
        await pool.query(
          `INSERT INTO prompt_templates (user_id, name, subject, course_type, question_type, template_content, variables, is_default)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
          [u.rows[0].id, t.name, t.subject, t.course_type, t.question_type, t.template_content,
           JSON.stringify(t.variables || {}), t.is_default || false]);
      }
    }
  }

  // 示例错题（挂在第一个用户下；替换真实数据时删除 example_questions 或覆盖 seed.json）
  if (u.rows.length) {
    for (const q of seed.example_questions || []) {
      const exists = await pool.query(
        'SELECT 1 FROM questions WHERE user_id=$1 AND original_question=$2', [u.rows[0].id, q.original_question]);
      if (!exists.rows.length) {
        await pool.query(
          `INSERT INTO questions (user_id, original_question, my_answer, correct_answer, analysis, error_type, mastery, source)
           VALUES ($1,$2,$3,$4,$5,$6,$7,'seed')`,
          [u.rows[0].id, q.original_question, q.my_answer, q.correct_answer, q.analysis, q.error_type, q.mastery]);
      }
    }
  }

  console.log('seed 完成');
  await pool.end();
}

main().catch(e => { console.error('seed 失败:', e.message); process.exit(1); });
