// services/userMemoryService.js —— 用户 AI 记忆读写封装
const { query } = require('../db');

async function addMemory(userId, { memoryType, key, value, confidence = 0.5, source = 'implicit' }) {
  const r = await query(
    `INSERT INTO user_ai_memory (user_id, memory_type, key, value, confidence, source)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [userId, memoryType, key, value, confidence, source]);
  return r.rows[0];
}

async function touchMemory(userId, id) {
  await query('UPDATE user_ai_memory SET hit_count=hit_count+1, last_used_at=now(), updated_at=now() WHERE id=$1 AND user_id=$2', [id, userId]);
}

module.exports = { addMemory, touchMemory };
