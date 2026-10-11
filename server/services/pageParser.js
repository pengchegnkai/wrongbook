// services/pageParser.js —— 网页抓取与正文提取（轻量，不依赖 jsdom）
async function fetchPage(url, timeoutMs = 10000) {
  const r = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (compatible; cuoti-bot/1.0)' },
    signal: AbortSignal.timeout(timeoutMs)
  });
  if (!r.ok) throw new Error('抓取失败 HTTP ' + r.status);
  const contentType = r.headers.get('content-type') || '';
  if (!contentType.includes('text/html') && !contentType.includes('text/plain')) {
    throw new Error('不支持的内容类型: ' + contentType);
  }
  return r.text();
}

function stripTags(html) {
  return String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

// 粗略正文提取：取 <body> 内最长文本块
function extractMainText(html) {
  const body = html.replace(/<script[\s\S]*?<\/script>/gi, '').replace(/<style[\s\S]*?<\/style>/gi, '');
  const blocks = body.match(/<(p|div|section)[^>]*>[\s\S]*?<\/\1>/gi) || [];
  const texts = blocks.map(stripTags).filter(t => t.length > 50);
  return (texts.sort((a, b) => b.length - a.length)[0] || stripTags(body)).slice(0, 5000);
}

const pageParser = { fetchPage, stripTags, extractMainText };
module.exports = { pageParser };
