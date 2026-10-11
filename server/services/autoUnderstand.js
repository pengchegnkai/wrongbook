// services/autoUnderstand.js —— 自动理解原题与作答
// 输入：App 端 OCR 得到的文本。本地模型（Qwen2.5/MiniCPM 文本版）不具备视觉能力，
// 视觉部分由 App 端 ML Kit OCR + 版面规则完成，本服务用 LLM 做分区与结构化。
const { chat } = require('./llamaClient');
const { resolveStrength } = require('./strengthResolver');

const SYSTEM_PROMPT = `你是试卷/作业文本解析器。输入为 OCR 提取的文本，请输出严格 JSON：
{
  "detectedParts": [ { "type": "question"|"answer"|"analysis"|"unknown", "content": "...", "confidence": 0.0 } ],
  "subject": "学科（不确定填 unknown）",
  "questionType": "题型（不确定填 unknown）",
  "knowledgePoints": ["..."],
  "uncertain": true或false
}
规则：不要输出 JSON 以外的任何文字。置信度低于 0.6 的分区 confidence 填低值；无法区分原题与作答时 uncertain 填 true。`;

async function autoUnderstand(ocrText) {
  if (!ocrText || !ocrText.trim()) {
    return { detectedParts: [], subject: 'unknown', questionType: 'unknown', knowledgePoints: [], uncertain: true, needsConfirm: true };
  }
  const result = await chat({
    prompt: SYSTEM_PROMPT + '\n\nOCR 文本：\n' + ocrText,
    strength: resolveStrength('fast')
  });
  let parsed;
  try {
    // 提取第一个 {...} 块
    const m = result.text.match(/\{[\s\S]*\}/);
    parsed = JSON.parse(m ? m[0] : '{}');
  } catch (_) {
    parsed = { detectedParts: [{ type: 'unknown', content: ocrText, confidence: 0.3 }], subject: 'unknown', questionType: 'unknown', knowledgePoints: [], uncertain: true };
  }
  // 低置信度标记需人工确认
  parsed.needsConfirm = parsed.uncertain === true ||
    (parsed.detectedParts || []).some(p => (p.confidence || 0) < 0.6);
  return parsed;
}

module.exports = { autoUnderstand };
