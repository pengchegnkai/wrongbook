// services/strengthResolver.js —— 思考强度映射
const STRENGTHS = [
  { id: 'fast',    name: '快速', maxTokens: 256,  sampleCount: 1, cot: false,   description: '不启用长 CoT，单次采样' },
  { id: 'standard',name: '标准', maxTokens: 512,  sampleCount: 1, cot: 'basic', description: '基础 CoT，单次采样' },
  { id: 'deep',    name: '深度', maxTokens: 1024, sampleCount: 1, cot: 'long',  description: '长 CoT，单次采样' },
  { id: 'ultra',   name: '极致', maxTokens: 2048, sampleCount: 3, cot: 'long',  description: '长 CoT，3 次采样取最优' }
];

function resolveStrength(id) {
  return STRENGTHS.find(s => s.id === id) || STRENGTHS[1]; // 默认 standard
}

module.exports = { STRENGTHS, resolveStrength };
