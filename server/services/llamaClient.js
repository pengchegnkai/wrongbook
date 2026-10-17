// services/llamaClient.js —— llama.cpp llama-server 客户端（OpenAI 兼容接口）
// 适配 pkg 版 llama-server（pkg install llama-cpp llama-cpp-backend-vulkan）
// /v1/chat/completions 已验证可用；模型名从 .env MODEL_NAME 读取
const BASE = () => process.env.LLAMA_BASE_URL || 'http://127.0.0.1:8080';
const MODEL_NAME = () => process.env.MODEL_NAME || 'local';

// strength: { maxTokens, sampleCount } 由 strengthResolver 传入
async function chat({ prompt, strength, systemPrompt }) {
  const body = {
    model: MODEL_NAME(),
    messages: [
      ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
      { role: 'user', content: prompt }
    ],
    max_tokens: strength.maxTokens,
    temperature: 0.7,
    stream: false
  };
  // 采样 strength.sampleCount 次取最优
  // 策略：按【答案】段长度择优。答案为空的样本（token 耗尽只剩思考）不参与比较，
  // 否则"取最长文本"会偏向只输出思考、没有答案的劣质结果。
  let best = null;
  for (let i = 0; i < (strength.sampleCount || 1); i++) {
    const r = await fetch(`${BASE()}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(300000)
    });
    if (!r.ok) {
      // llama-server 的 4xx/5xx 响应体带具体原因（如 prompt 超长、参数错误），
      // 记日志并透传给上层，避免只报一个状态码无法定位
      let detail = '';
      try {
        detail = (await r.text()).slice(0, 500);
      } catch (_) { /* 读不到响应体就只报状态码 */ }
      console.error(`[llamaClient] /v1/chat/completions 返回 ${r.status}: ${detail}`);
      throw new Error(`llama-server 返回 ${r.status}${detail ? '：' + detail : ''}`);
    }
    const data = await r.json();
    const choice = data.choices?.[0]?.message || {};
    // 推理模型（如 MiniCPM5）把思考放在 reasoning_content，最终答案在 content
    const reasoning = (choice.reasoning_content || '').trim();
    const answer = (choice.content || '').trim();
    if (!reasoning && !answer) continue; // 空样本
    const text = answer
      ? (reasoning ? '【思考】' + reasoning + '\n\n【答案】' + answer : answer)
      : '【思考】' + reasoning; // 仅思考（截断）：参与返回但不参与择优得分
    const score = answer.length;
    if (!best || score > best.score) {
      best = {
        text,
        score,
        model: data.model || MODEL_NAME(),
        totalTokens: data.usage?.total_tokens
      };
    }
  }
  if (!best) throw new Error('模型未生成有效内容（token 预算内未产出答案，可尝试更高思考强度）');
  return best;
}

async function isAvailable() {
  try {
    const r = await fetch(`${BASE()}/health`, { signal: AbortSignal.timeout(2000) });
    return r.ok;
  } catch (_) { return false; }
}

module.exports = { chat, isAvailable, MODEL_NAME };
