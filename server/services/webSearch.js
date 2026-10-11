// services/webSearch.js —— 网络搜索适配器
// 说明：未配置任何搜索 API key（用户未提供）。默认实现使用 DuckDuckGo HTML 端点做只读搜索，
// 该端点非官方 API，可能失效或被限流；如失败请改用你自选的搜索 API 并在此适配。
// 未验证，需你实测。来源标注要求：所有搜索结果仅作候选，采纳后由用户确认。
const { pageParser } = require('./pageParser');

async function searchWeb(keyword) {
  const url = 'https://html.duckduckgo.com/html/?q=' + encodeURIComponent(keyword.slice(0, 100));
  const r = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; cuoti-bot/1.0)' },
    signal: AbortSignal.timeout(15000)
  });
  if (!r.ok) throw new Error('搜索请求失败 HTTP ' + r.status);
  const html = await r.text();
  return parseDdgResults(html, keyword);
}

function parseDdgResults(html, keyword) {
  // DuckDuckGo HTML 版结果块：class="result__a" 链接 + "result__snippet" 摘要
  const results = [];
  const linkRx = /<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/g;
  const snipRx = /class="[^"]*result__snippet[^"]*"[^>]*>([\s\S]*?)<\/a>/g;
  const snippets = [];
  let m;
  while ((m = snipRx.exec(html)) !== null) snippets.push(pageParser.stripTags(m[1]));
  let i = 0;
  while ((m = linkRx.exec(html)) !== null && results.length < 10) {
    let href = m[1];
    const uddg = href.match(/uddg=([^&]+)/);
    if (uddg) href = decodeURIComponent(uddg[1]);
    results.push({
      provider: 'duckduckgo',
      url: href,
      title: pageParser.stripTags(m[2]),
      snippet: snippets[i] || '',
      author: '',
      authority: 'C', // 默认 C 级，由用户/规则升级
      searchKeywords: [keyword]
    });
    i++;
  }
  if (!results.length) throw new Error('未能解析搜索结果（页面结构可能已变化，需适配）');
  return results;
}

module.exports = { searchWeb };
