// services/similarity.js —— 轻量文本相似度（关键词重合 + 字符 bigram 余弦）
// 不使用 pgvector（Termux 编译风险高，已确认选轻量方案）

function tokenize(text) {
  // 中文字符 bigram + 英文/数字词
  const tokens = new Set();
  const s = String(text || '').toLowerCase();
  for (const m of s.matchAll(/[a-z0-9]+/g)) tokens.add(m[0]);
  for (let i = 0; i < s.length - 1; i++) {
    if (/[\u4e00-\u9fff]/.test(s[i]) && /[\u4e00-\u9fff]/.test(s[i + 1])) {
      tokens.add(s.slice(i, i + 2));
    }
  }
  return tokens;
}

function cosineTokens(a, b) {
  const A = tokenize(a), B = tokenize(b);
  if (!A.size || !B.size) return 0;
  let dot = 0;
  for (const t of A) if (B.has(t)) dot++;
  return dot / Math.sqrt(A.size * B.size);
}

function extractKeywords(text, topN = 8) {
  const s = String(text || '');
  const freq = new Map();
  for (let i = 0; i < s.length - 1; i++) {
    const g = s.slice(i, i + 2);
    if (/^[\u4e00-\u9fff]{2}$/.test(g)) freq.set(g, (freq.get(g) || 0) + 1);
  }
  return [...freq.entries()].sort((a, b) => b[1] - a[1]).slice(0, topN).map(e => e[0]);
}

module.exports = { tokenize, cosineTokens, extractKeywords };
