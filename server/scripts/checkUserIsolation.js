// scripts/checkUserIsolation.js —— 用户数据隔离自检
// 用法：cd ~/cuoti/server && node scripts/checkUserIsolation.js
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool, ensureSchema } = require('../db');

// 业务表：这些表必须全部带 user_id（否则必须在白名单里说明理由）
const ISOLATED_TABLES = [
  'refresh_tokens','login_logs','user_settings','questions','prompt_templates',
  'question_analysis_logs','analysis_strength_configs','user_ai_memory','user_feedback',
  'local_records','search_cache'
];
// 全局表（无 user_id 是正常的）
const GLOBAL_TABLES = ['users','subjects','chapters','knowledge_points','api_providers','tags'];
// 挂靠表（通过父表 user_id 级联）
const NESTED_TABLES = ['question_kps','question_tags','review_logs','question_sources','verification_logs'];

async function checkDb() {
  const problems = [];
  for (const t of ISOLATED_TABLES) {
    const r = await pool.query(
      `SELECT COUNT(*)::int AS n FROM information_schema.columns
       WHERE table_name=$1 AND column_name='user_id'`, [t]);
    if (r.rows[0].n === 0) problems.push(`表 ${t} 缺少 user_id 列`);
    const fk = await pool.query(
      `SELECT COUNT(*)::int AS n FROM information_schema.table_constraints tc
       JOIN information_schema.key_column_usage k ON k.constraint_name=tc.constraint_name
       WHERE tc.table_name=$1 AND tc.constraint_type='FOREIGN KEY' AND k.column_name='user_id'`, [t]);
    if (fk.rows[0].n === 0) problems.push(`表 ${t} 缺少 user_id 外键`);
  }
  return problems;
}

function checkRoutes() {
  const problems = [];
  const dir = path.join(__dirname, '../routes');
  for (const file of fs.readdirSync(dir)) {
    const code = fs.readFileSync(path.join(dir, file), 'utf8');
    // 粗检：业务路由文件应出现 req.userId
    // 白名单：auth（登录入口）、health/network（无鉴权健康与发现）、
    // subjects（全局只读字典：学科/章节/知识点，不含任何用户数据，不返回 user 内容）
    if (['auth.js', 'health.js', 'network.js', 'subjects.js'].includes(file)) continue;
    if (!code.includes('req.userId')) {
      problems.push(`routes/${file} 未使用 req.userId（可能存在越权风险）`);
    }
  }
  return problems;
}

async function main() {
  await ensureSchema();
  const dbProblems = await checkDb();
  const routeProblems = checkRoutes();
  const all = [...dbProblems, ...routeProblems];
  if (all.length) {
    console.error('隔离自检未通过：');
    all.forEach(p => console.error(' -', p));
    process.exit(1);
  }
  console.log(`隔离自检通过：${ISOLATED_TABLES.length} 张隔离表均有 user_id 外键，业务路由均使用 req.userId 过滤。`);
  console.log(`全局表（无需隔离）：${GLOBAL_TABLES.join(', ')}；级联表：${NESTED_TABLES.join(', ')}`);
  await pool.end();
}

main().catch(e => { console.error('自检失败:', e.message); process.exit(1); });
