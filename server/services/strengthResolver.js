// services/strengthResolver.js —— 思考强度映射
// 注意：MiniCPM5 是推理模型（先输出 reasoning_content 思考，再输出 content 正文），
// 实测简单问题思考就要消耗 100+ token。maxTokens 过小会在思考阶段截断，
// 正文为空。各档位已按推理模型特性放宽：
const STRENGTHS = [
  { id: 'fast',    name: '快速', maxTokens: 384,  sampleCount: 1, cot: false,   description: '短思考，单次采样' },
  { id: 'standard',name: '标准', maxTokens: 768,  sampleCount: 1, cot: 'basic', description: '基础 CoT，单次采样' },
  { id: 'deep',    name: '深度', maxTokens: 1536, sampleCount: 1, cot: 'long',  description: '长 CoT，单次采样' },
  { id: 'ultra',   name: '极致', maxTokens: 3072, sampleCount: 3, cot: 'long',  description: '长 CoT，3 次采样取最优' }
];

function resolveStrength(id) {
  return STRENGTHS.find(s => s.id === id) || STRENGTHS[1]; // 默认 standard
}

module.exports = { STRENGTHS, resolveStrength };
