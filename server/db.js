// db.js —— PostgreSQL 连接池
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER || 'cuoti',
  password: process.env.DB_PASSWORD || 'CHANGE_ME_DB_PASSWORD',
  database: process.env.DB_NAME || 'cuoti',
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000, // 连接拿不到 5s 报错，不无限等待占死池子
});

// 每条语句 30s 超时：一条挂死查询不至于占满连接池拖垮全服务
pool.on('connect', (client) => {
  client.query('SET statement_timeout = 30000').catch(() => {});
});

// 启动时自动执行 schema.sql（幂等，CREATE TABLE IF NOT EXISTS）
async function ensureSchema() {
  const sqlPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(sqlPath, 'utf8');
  await pool.query(sql);
  console.log('[db] schema.sql 已执行（幂等）');
}

// 统一返回 { code, data, message } 中的 code：0 成功
module.exports = {
  pool,
  ensureSchema,
  query: (text, params) => pool.query(text, params)
};
