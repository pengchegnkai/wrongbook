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
  // 采样 strength.sampleCount 次取最长/最优（简单策略：取长度最长者作为"最优"）
  let best = null;
  for (let i = 0; i < (strength.sampleCount || 1); i++) {
    const r = await fetch(`${BASE()}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(300000)
    });
    if (!r.ok) throw new Error(`llama-server 返回 ${r.status}`);
    const data = await r.json();
    const choice = data.choices?.[0]?.message || {};
    // 推理模型（如 MiniCPM5）把思考放在 reasoning_content，最终答案在 content；
    // 两者都可能有值，也可能只有思考（token 不足截断时）。合并输出：
    const parts = [];
    if (choice.reasoning_content) parts.push('【思考】' + choice.reasoning_content.trim());
    if (choice.content && choice.content.trim()) parts.push('【答案】' + choice.content.trim());
    const text = parts.join('\n\n') || (choice.content || '');
    if (!best || text.length > best.text.length) {
      best = {
        text,
        model: data.model || MODEL_NAME(),
        totalTokens: data.usage?.total_tokens,
        firstTokenMs: null
      };
    }
  }
  return best;
}

async function isAvailable() {
  try {
    const r = await fetch(`${BASE()}/health`, { signal: AbortSignal.timeout(2000) });
    return r.ok;
  } catch (_) { return false; }
}

module.exports = { chat, isAvailable, MODEL_NAME };
