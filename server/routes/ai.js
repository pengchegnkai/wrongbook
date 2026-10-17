// routes/ai.js —— AI 分析 / 图片理解 / 反馈 / profile
const express = require('express');
const multer = require('multer');
const { query } = require('../db');
const { analyzeQuestion } = require('../services/analyzeQuestion');
const { autoUnderstand } = require('../services/autoUnderstand');
const { renderTemplate } = require('../services/templateRenderer');
const { resolveStrength } = require('../services/strengthResolver');
const { retrieveContext } = require('../services/ragRetriever');
const { getBaseInstructions } = require('../services/promptAdapter');
const { recordFeedbackSignal, updateProfileFromStats } = require('../services/userProfileService');
const router = express.Router();

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// .env 写入串行化锁：并发切换模型时排队执行，防止读-改-写互相覆盖
let _envQueue = Promise.resolve();
function withEnvLock(fn) {
  const p = _envQueue.then(fn, fn);
  _envQueue = p.catch(() => {});
  return p;
}

// 分析错题：选模板 → 渲染 → RAG 注入 → 调 llama → 存日志
router.post('/analyze-question', async (req, res, next) => {
  const started = Date.now();
  try {
    const { questionId, templateId, strength, extra } = req.body || {};
    if (!questionId) return res.status(400).json({ code: 400, data: null, message: '缺少 questionId' });
    const qr = await query('SELECT * FROM questions WHERE id=$1 AND user_id=$2', [questionId, req.userId]);
    if (!qr.rows.length) return res.status(404).json({ code: 404, data: null, message: '错题不存在' });
    const q = qr.rows[0];

    // 模板：指定或默认
    let tpl = null;
    if (templateId) {
      const tr = await query('SELECT * FROM prompt_templates WHERE id=$1 AND user_id=$2', [templateId, req.userId]);
      tpl = tr.rows[0] || null;
    }
    if (!tpl) {
      const tr = await query('SELECT * FROM prompt_templates WHERE user_id=$1 AND is_default=true LIMIT 1', [req.userId]);
      tpl = tr.rows[0] || null;
    }
    if (!tpl) return res.status(400).json({ code: 400, data: null, message: '没有可用模板，请先创建' });

    // 实际强度：请求指定 > 用户配置 > standard
    let effective = strength ? resolveStrength(strength) : null;
    if (!effective) {
      const cr = await query('SELECT default_strength FROM analysis_strength_configs WHERE user_id=$1 AND subject IS NOT DISTINCT FROM $2 LIMIT 1',
        [req.userId, q.subject_id || null]);
      effective = resolveStrength(cr.rows[0] ? cr.rows[0].default_strength : null);
    }

    // RAG：检索本用户历史相似错题 + AI 记忆
    const rag = await retrieveContext(req.userId, q.original_question);

    const rendered = renderTemplate(tpl.template_content, {
      subject: q.subject_id, chapter: q.chapter_id, knowledgePoints: rag.kpNames.join('、'),
      originalQuestion: q.original_question, myAnswer: q.my_answer || '', correctAnswer: q.correct_answer || '',
      analysis: q.analysis || '', errorType: q.error_type || '', mastery: q.mastery || '',
      questionType: q.question_type || '', courseType: '普通高中', extra: extra || ''
    }) + '\n\n【历史相似错题参考】\n' + rag.similarQuestions.join('\n') + '\n\n【用户偏好记忆】\n' + rag.memories.join('\n')
      + '\n\n【输出格式要求】\n' + getBaseInstructions();

    // ---- 异步模式 ----
    // 经 Cloudflare 隧道（免费版）调用时，代理对源站响应有约 100s 超时，
    // 标准/深度档分析会被 524 掐断。async=true 时立即返回 logId，
    // 后台执行，App 轮询 GET /analysis-status/:logId 取结果。
    if (req.body && req.body.async === true) {
      const logR = await query(
        `INSERT INTO question_analysis_logs (user_id, question_id, template_id, rendered_prompt, ai_response, model, mode, platform, strength, duration_ms, provider)
         VALUES ($1,$2,$3,$4,NULL,NULL,'local','termux-server',$5,NULL,'llama.cpp') RETURNING id`,
        [req.userId, questionId, tpl.id, rendered, effective.id]);
      const logId = logR.rows[0].id;
      // 后台执行（不阻塞响应）；结果写回日志与题目
      (async () => {
        try {
          const t0 = Date.now();
          const result = await analyzeQuestion({ prompt: rendered, strength: effective });
          await query(
            `UPDATE question_analysis_logs SET ai_response=$2, model=$3, duration_ms=$4, total_tokens=$5 WHERE id=$1`,
            [logId, result.text, result.model || 'local', Date.now() - t0, result.totalTokens || null]);
          await query("UPDATE questions SET ai_generated_answer=$2, updated_at=now() WHERE id=$1",
            [questionId, result.text]);
        } catch (e) {
          try {
            await query("UPDATE question_analysis_logs SET ai_response=$2 WHERE id=$1",
              [logId, '__ANALYSIS_ERROR__:' + (e && e.message ? e.message : String(e))]);
          } catch (_) { /* 日志写失败只能放弃，无法通知 */ }
        }
      })();
      return res.json({ code: 0, data: { logId, async: true, strength: effective.id }, message: 'ok' });
    }

    const result = await analyzeQuestion({ prompt: rendered, strength: effective });

    // 写分析日志（load_time_ms/first_token_ms 尚未实现，不写假数据）
    const logR = await query(
      `INSERT INTO question_analysis_logs (user_id, question_id, template_id, rendered_prompt, ai_response, model, mode, platform, strength, duration_ms, provider, total_tokens)
       VALUES ($1,$2,$3,$4,$5,$6,'local','termux-server',$7,$8,'llama.cpp',$9) RETURNING id`,
      [req.userId, questionId, tpl.id, rendered, result.text, result.model || 'local', effective.id,
       Date.now() - started, result.totalTokens || null]);

    // 把 AI 生成答案写回题目（供详情页展示）；
    // analysis 字段保持自身语义（人工/来源解析），不被 AI 文本覆盖
    await query("UPDATE questions SET ai_generated_answer=$2, updated_at=now() WHERE id=$1", [questionId, result.text]);

    res.json({ code: 0, data: { logId: logR.rows[0].id, response: result.text, strength: effective.id, model: result.model }, message: 'ok' });
  } catch (e) { next(e); }
});

// 轮询异步分析结果：ai_response 为 NULL = 仍在执行（running）
router.get('/analysis-status/:logId', async (req, res, next) => {
  try {
    const r = await query(
      `SELECT id, ai_response, strength, model, duration_ms, total_tokens
         FROM question_analysis_logs WHERE id=$1 AND user_id=$2`,
      [req.params.logId, req.userId]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '分析日志不存在' });
    const row = r.rows[0];
    const errTag = '__ANALYSIS_ERROR__:';
    let status = 'done';
    let response = row.ai_response;
    if (response == null) {
      status = 'running';
      response = null;
    } else if (typeof response === 'string' && response.startsWith(errTag)) {
      status = 'error';
      response = response.slice(errTag.length);
    }
    res.json({ code: 0, data: { logId: row.id, status, response, strength: row.strength, model: row.model, durationMs: row.duration_ms }, message: 'ok' });
  } catch (e) { next(e); }
});

// 图片理解：OCR 由 App 端完成，这里调多模态（本地模型非多模态时降级为文本推理，需说明）
router.post('/understand-image', upload.single('image'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ code: 400, data: null, message: '缺少图片文件' });
    const ocrText = (req.body && req.body.ocrText) || '';
    // 本地 Qwen2.5/MiniCPM 文本模型不具备视觉能力（不确定 MiniCPM-V 变体是否支持，需你实测），
    // 因此约定：App 端 ML Kit OCR 提取文本后传 ocrText，服务端做分区理解。
    const result = await autoUnderstand(ocrText);
    res.json({ code: 0, data: result, message: 'ok' });
  } catch (e) { next(e); }
});

// 反馈
router.post('/feedback', async (req, res, next) => {
  try {
    const { questionId, analysisLogId, feedbackType, comment } = req.body || {};
    if (!feedbackType) return res.status(400).json({ code: 400, data: null, message: '缺少 feedbackType' });
    // 归属校验：不能向他人（或不存在）的错题/分析日志写入反馈
    if (questionId != null) {
      const o = await query('SELECT 1 FROM questions WHERE id=$1 AND user_id=$2', [questionId, req.userId]);
      if (!o.rows.length) return res.status(403).json({ code: 403, data: null, message: '错题不存在或不属于当前用户' });
    }
    if (analysisLogId != null) {
      const o = await query('SELECT 1 FROM question_analysis_logs WHERE id=$1 AND user_id=$2', [analysisLogId, req.userId]);
      if (!o.rows.length) return res.status(403).json({ code: 403, data: null, message: '分析记录不存在或不属于当前用户' });
    }
    await query(
      'INSERT INTO user_feedback (user_id, question_id, analysis_log_id, feedback_type, comment) VALUES ($1,$2,$3,$4,$5)',
      [req.userId, questionId || null, analysisLogId || null, feedbackType, comment || '']);
    await recordFeedbackSignal(req.userId, feedbackType, comment);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

// 分析历史
router.get('/analysis-logs', async (req, res, next) => {
  try {
    const r = await query(
      'SELECT id, question_id, model, strength, duration_ms, created_at FROM question_analysis_logs WHERE user_id=$1 ORDER BY created_at DESC LIMIT 100',
      [req.userId]);
    res.json({ code: 0, data: r.rows, message: 'ok' });
  } catch (e) { next(e); }
});

router.get('/analysis-logs/:id', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM question_analysis_logs WHERE id=$1 AND user_id=$2', [req.params.id, req.userId]);
    if (!r.rows.length) return res.status(404).json({ code: 404, data: null, message: '不存在' });
    res.json({ code: 0, data: r.rows[0], message: 'ok' });
  } catch (e) { next(e); }
});

// profile
router.get('/profile', async (req, res, next) => {
  try {
    const r = await query('SELECT * FROM user_ai_profile WHERE user_id=$1', [req.userId]);
    res.json({ code: 0, data: r.rows[0] || null, message: 'ok' });
  } catch (e) { next(e); }
});

router.put('/profile', async (req, res, next) => {
  try {
    const { preferredStrength, preferredExplanationStyle, learningGoal } = req.body || {};
    await query(
      `UPDATE user_ai_profile SET preferred_strength=COALESCE($1,preferred_strength),
        preferred_explanation_style=COALESCE($2,preferred_explanation_style),
        learning_goal=COALESCE($3,learning_goal), updated_at=now() WHERE user_id=$4`,
      [preferredStrength, preferredExplanationStyle, learningGoal, req.userId]);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

// 触发画像刷新（从历史统计更新薄弱点）
router.post('/profile/refresh', async (req, res, next) => {
  try {
    await updateProfileFromStats(req.userId);
    res.json({ code: 0, data: null, message: 'ok' });
  } catch (e) { next(e); }
});

// 切换本地模型：App 模型管理页调用（写入 .env 并异步重启 llama-server）
router.post('/local-model/switch', async (req, res, next) => {
  try {
    const { fileName } = req.body || {};
    if (!fileName || !/^[A-Za-z0-9._-]+$/.test(fileName)) {
      return res.status(400).json({ code: 400, data: null, message: 'fileName 非法（仅允许字母数字._-）' });
    }
    const { exec } = require('child_process');
    const os = require('os');
    const path = require('path');
    const fs = require('fs');
    // 在约定目录中查找模型（共享存储 / 项目目录 / 私有 downloads）
    const candidates = [
      path.join(os.homedir(), 'storage/downloads', fileName),
      path.join(os.homedir(), 'cuoti/models', fileName),
      path.join(os.homedir(), 'downloads', fileName)
    ];
    const modelPath = candidates.find(p => fs.existsSync(p));
    if (!modelPath) return res.status(404).json({ code: 404, data: null, message: '模型文件未找到: ' + fileName });
    // 写 server/.env（MODEL_PATH 用 ~ 相对路径，llama-server.sh 会展开）；锁内执行
    const envFile = path.join(__dirname, '../.env');
    const changed = await withEnvLock(() => {
      let env = fs.readFileSync(envFile, 'utf8');
      const rel = modelPath.startsWith(os.homedir()) ? '~' + modelPath.slice(os.homedir().length) : modelPath;
      const before = env;
      env = env.replace(/^MODEL_PATH=.*/m, 'MODEL_PATH=' + rel);
      const mname = fileName.replace(/\.gguf$/i, '').toLowerCase().replace(/\./g, '');
      env = env.replace(/^MODEL_NAME=.*/m, 'MODEL_NAME=' + mname);
      if (env === before) return false; // replace 未生效 = .env 缺少配置行，不能假装成功
      fs.writeFileSync(envFile, env);
      return true;
    });
    if (!changed) {
      return res.status(500).json({ code: 500, data: null, message: '.env 缺少 MODEL_PATH/MODEL_NAME 配置行，无法切换模型' });
    }
    // 异步重启 llama-server（pkg 版，参数由 llama-server.sh 统一管理）；
    // bash 路径不硬编码：Termux 用 $PREFIX，其他平台退回 PATH 查找
    const bashPath = process.env.PREFIX ? path.join(process.env.PREFIX, 'bin', 'bash') : 'bash';
    exec(`bash ~/cuoti/termux/llama-server.sh restart ${JSON.stringify(modelPath)} > ~/cuoti/logs/model-switch.log 2>&1 &`,
      { shell: bashPath });
    res.json({ code: 0, data: { modelPath: rel, modelName: mname }, message: '已切换，llama-server 重启中（约数秒）' });
  } catch (e) { next(e); }
});

module.exports = router;
