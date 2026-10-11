// services/verifyQuestion.js —— 错题联网核验
// 流程：提取关键词 → 搜索 → 抓取页面片段 → 相似度评分 → 返回候选来源
const { aggregateSearch } = require('./searchProviders');
const { pageParser } = require('./pageParser');
const { cosineTokens, extractKeywords } = require('./similarity');
const { query } = require('../db');

async function verifyQuestion(question) {
  const kwSource = question.original_question || '';
  const keywords = extractKeywords(kwSource, 10);
  const queryStr = keywords.slice(0, 6).join(' ');

  const results = await aggregateSearch(queryStr);

  const scored = [];
  for (const r of results.slice(0, 5)) {
    let pageText = r.snippet || '';
    try {
      const html = await pageParser.fetchPage(r.url);
      pageText = pageParser.extractMainText(html);
    } catch (_) { /* 抓取失败就用搜索摘要 */ }
    const score = cosineTokens(kwSource, pageText);
    scored.push({
      provider: r.provider,
      url: r.url,
      title: r.title,
      author: r.author || '',
      authority: r.authority,
      snippet: pageText.slice(0, 300),
      similarityScore: Number(score.toFixed(4))
    });
  }

  // 记录搜索计划（供排查与展示）
  await query('UPDATE questions SET search_plan=$2, search_keywords=$3 WHERE id=$1 AND user_id IS NOT NULL',
    [question.id, `关键词: ${queryStr}；候选 ${results.length} 条`, keywords]);

  scored.sort((a, b) => b.similarityScore - a.similarityScore);
  return { sources: scored, bestSimilarity: scored[0] ? scored[0].similarityScore : 0 };
}

module.exports = { verifyQuestion };
