// services/ragRetriever.js —— 用户级 RAG：检索历史相似错题 + AI 记忆
// 按用户严格隔离；轻量文本相似度（不装 pgvector）
const { query } = require('../db');
const { cosineTokens, extractKeywords } = require('./similarity');

async function retrieveContext(userId, questionText) {
  // 1. 该用户最近 200 道错题做内存相似度筛选（错题量级在个人场景足够）
  const r = await query(
    'SELECT id, original_question, error_type, correct_answer FROM questions WHERE user_id=$1 ORDER BY created_at DESC LIMIT 200',
    [userId]);
  const scored = r.rows
    .map(q => ({ ...q, score: cosineTokens(questionText, q.original_question) }))
    .filter(q => q.id && q.score > 0.35)
    .sort((a, b) => b.score - a.score)
    .slice(0, 3);

  const similarQuestions = scored.map(q =>
    `-（题目 ${q.id}，错因：${q.error_type || '未知'}）${String(q.original_question).slice(0, 120)}`);

  // 2. AI 记忆（限制条数，避免 prompt 过长）
  const m = await query(
    "SELECT key, value FROM user_ai_memory WHERE user_id=$1 AND memory_type IN ('preference','weak_signal') ORDER BY confidence DESC, updated_at DESC LIMIT 10",
    [userId]);
  const memories = m.rows.map(x => `- ${x.key}: ${String(x.value).slice(0, 80)}`);

  // 3. 知识点名称（当前题目关联）
  const kp = await query(
    `SELECT DISTINCT kp.name FROM question_kps qk JOIN knowledge_points kp ON kp.id=qk.kp_id
     JOIN questions q ON q.id=qk.question_id WHERE q.user_id=$1 AND q.original_question ILIKE $2 LIMIT 5`,
    [userId, `%${String(questionText).slice(0, 40)}%`]);

  return {
    similarQuestions,
    memories: memories.length ? memories : ['（暂无）'],
    kpNames: kp.rows.map(x => x.name),
    keywords: extractKeywords(questionText)
  };
}

module.exports = { retrieveContext };
