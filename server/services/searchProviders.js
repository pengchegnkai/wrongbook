// services/searchProviders.js —— 搜索源适配与可信度评级
// 可信度等级（约定）：A=官方教育机构/教材出版社；B=知名教育平台；C=其他（默认）
// 域名白名单仅为初始约定，用户可自行修改。未验证各域名可达性，需你实测。
const AUTHORITY_RULES = [
  { pattern: /\.gov\.cn/, level: 'A', label: '政府/考试机构' },
  { pattern: /pep\.com\.cn/, level: 'A', label: '人民教育出版社' },
  { pattern: /(xkw|21cnjy|zxxk|cooco|jiye)\./, level: 'B', label: '教育平台' },
  { pattern: /(zhihu|baidu|baike)\./, level: 'C', label: '社区/百科' }
];

function rateAuthority(url) {
  for (const rule of AUTHORITY_RULES) {
    if (rule.pattern.test(url)) return rule.level;
  }
  return 'C';
}

// 多源聚合入口：目前仅 DuckDuckGo（未配置其他 key）。扩展点：在此追加其他 provider。
const { searchWeb } = require('./webSearch');

async function aggregateSearch(keyword) {
  const results = await searchWeb(keyword);
  return results.map(r => ({ ...r, authority: rateAuthority(r.url) }));
}

module.exports = { aggregateSearch, rateAuthority, AUTHORITY_RULES };
