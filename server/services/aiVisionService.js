// services/aiVisionService.js —— 多模态视觉理解引擎（模式 B）
// 图片转 Base64 → OpenAI 多模态格式 → llama-server（MiniCPM-V 等多模态模型）
// 精准理解手写体/公式/复杂排版；CPU 推理较慢（30-120s），前端已做等待提示。
const fs = require('fs');

const LLAMA_BASE = () => process.env.LLAMA_BASE_URL || 'http://127.0.0.1:8080';
const MODEL_NAME = () => process.env.MODEL_NAME || 'local';
// 视觉模式给足时间：纯 CPU 跑多模态，大图 prompt eval 可达数十秒
const VISION_TIMEOUT_MS = () => parseInt(process.env.VISION_TIMEOUT_MS || '180000', 10);

// 与模式 A 统一的精炼 Prompt（1B 小模型上下文有限，指令必须短而明确）
const UNIFIED_PROMPT =
  '提取图中的题目和作答，输出JSON：{"subject":"学科","question":"排版整齐的原题","myAnswer":"学生的作答"}。不要输出多余解释。';

/// 从模型输出中提取 JSON（小模型常带前缀/围栏/尾随文本）
function extractJson(text) {
  if (!text) return null;
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    const obj = JSON.parse(text.slice(start, end + 1));
    if (typeof obj.question === 'string' && obj.question.trim()) return obj;
    return null;
  } catch (_) {
    return null;
  }
}

/// 解析图片（视觉模式）。
/// 成功：{ ok: true, subject, question, myAnswer, model }
/// 失败：{ ok: false, code: 'no_multimodal'|'timeout'|'error', message }
async function parseImage(filePath, mimetype) {
  let base64;
  try {
    base64 = fs.readFileSync(filePath).toString('base64');
  } catch (e) {
    return { ok: false, code: 'error', message: '读取图片失败' };
  }

  const messages = [
    {
      role: 'user',
      content: [
        { type: 'image_url', image_url: { url: `data:${mimetype || 'image/jpeg'};base64,${base64}` } },
        { type: 'text', text: UNIFIED_PROMPT },
      ],
    },
  ];

  try {
    const r = await fetch(`${LLAMA_BASE()}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: MODEL_NAME(),
        messages,
        max_tokens: 700,
        temperature: 0.1,
        stream: false,
      }),
      signal: AbortSignal.timeout(VISION_TIMEOUT_MS()),
    });

    if (!r.ok) {
      let detail = '';
      try { detail = (await r.text()).slice(0, 200); } catch (_) {}
      // llama-server 加载的是纯文本模型（未带 --mmproj）时，
      // 图片输入会 4xx 拒绝——明确告知用户引擎能力边界
      const noMultimodal = r.status === 400 || r.status === 500;
      return {
        ok: false,
        code: noMultimodal ? 'no_multimodal' : 'error',
        message: noMultimodal
          ? '当前模型不支持看图（视觉引擎不可用）。请切回"极速识别"，或在 Termux 部署 MiniCPM-V 多模态模型（llama-server 需加 --mmproj 参数）'
          : `模型返回 ${r.status}${detail ? '：' + detail : ''}`,
      };
    }

    const data = await r.json();
    const choice = data.choices?.[0]?.message || {};
    // 推理型多模态模型可能把正文放 reasoning_content，合并后取 JSON
    const content = ((choice.content || '') + '\n' + (choice.reasoning_content || '')).trim();
    const obj = extractJson(content);
    if (!obj) {
      return { ok: false, code: 'error', message: '视觉模型未返回有效结构，请重试或改用极速模式' };
    }
    return {
      ok: true,
      subject: typeof obj.subject === 'string' ? obj.subject.trim() : '',
      question: obj.question.trim(),
      myAnswer: typeof obj.myAnswer === 'string' ? obj.myAnswer.trim() : '',
      model: data.model || MODEL_NAME(),
    };
  } catch (e) {
    const isTimeout = e && (e.name === 'TimeoutError' || e.name === 'AbortError');
    return {
      ok: false,
      code: isTimeout ? 'timeout' : 'error',
      message: isTimeout
        ? '视觉解析超时（纯 CPU 跑多模态较慢）。可改用极速识别，或在 .env 调大 VISION_TIMEOUT_MS'
        : `视觉引擎异常：${e && e.message ? e.message : e}`,
    };
  }
}

module.exports = { parseImage, UNIFIED_PROMPT };
