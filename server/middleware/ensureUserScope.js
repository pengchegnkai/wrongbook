// middleware/ensureUserScope.js —— 防止越权：校验 :id 资源归属当前用户
const { query } = require('../db');

const TABLES = ['questions', 'prompt_templates', 'question_analysis_logs'];

module.exports = function ensureUserScope(table, idField = 'id') {
  if (!TABLES.includes(table)) throw new Error(`ensureUserScope: 表 ${table} 未登记`);
  return async (req, res, next) => {
    try {
      const id = parseInt(req.params.id, 10);
      if (!Number.isInteger(id)) return res.status(400).json({ code: 400, data: null, message: '无效 id' });
      const r = await query(`SELECT user_id FROM ${table} WHERE ${idField} = $1`, [id]);
      if (r.rows.length === 0) return res.status(404).json({ code: 404, data: null, message: '资源不存在' });
      if (r.rows[0].user_id !== req.userId) {
        return res.status(403).json({ code: 403, data: null, message: '无权访问该资源' });
      }
      next();
    } catch (e) {
      next(e);
    }
  };
};
