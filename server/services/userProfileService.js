// services/userProfileService.js —— AI 自进化：反馈信号 → 记忆与画像
const { query } = require('../db');

const FEEDBACK_MAP = {
  useful:    { type: 'preference',   key: 'analysis_useful',   conf: 0.3 },
  useless:   { type: 'preference',   key: 'analysis_useless',  conf: 0.5 },
  wrong:     { type: 'preference',   key: 'analysis_wrong',    conf: 0.6 },
  too_long:  { type: 'preference',   key: 'style_too_verbose', conf: 0.5 },
  too_brief: { type: 'preference',   key: 'style_too_brief',   conf: 0.5 },
  confused:  { type: 'preference',   key: 'style_confused',    conf: 0.5 }
};

async function recordFeedbackSignal(userId, feedbackType, comment) {
  const sig = FEEDBACK_MAP[feedbackType];
  if (!sig) return;
  await query(
    `INSERT INTO user_ai_memory (user_id, memory_type, key, value, confidence, source)
     VALUES ($1,$2,$3,$4,$5,'explicit')`,
    [userId, sig.type, sig.key, comment || feedbackType, sig.conf]);
  await refreshWeakSubjects(userId);
}

// 从错题统计更新薄弱学科/错因画像
async function refreshWeakSubjects(userId) {
  const subj = await query(
    `SELECT s.name, COUNT(*)::int AS n,
       COUNT(*) FILTER (WHERE q.mastery='red')::int AS red
     FROM questions q LEFT JOIN subjects s ON s.id=q.subject_id
     WHERE q.user_id=$1 AND s.name IS NOT NULL
     GROUP BY s.name HAVING COUNT(*) > 0 ORDER BY red DESC, n DESC LIMIT 5`,
    [userId]);
  const errs = await query(
    'SELECT error_type, COUNT(*)::int AS n FROM questions WHERE user_id=$1 AND error_type IS NOT NULL GROUP BY error_type ORDER BY n DESC LIMIT 5',
    [userId]);
  await query(
    `UPDATE user_ai_profile SET
       weak_subjects=$2, common_error_types=$3, updated_at=now()
     WHERE user_id=$1`,
    [userId, JSON.stringify(subj.rows.map(r => r.name)), JSON.stringify(errs.rows.map(r => r.error_type))]);
}

async function updateProfileFromStats(userId) {
  await refreshWeakSubjects(userId);
}

module.exports = { recordFeedbackSignal, updateProfileFromStats, refreshWeakSubjects };
