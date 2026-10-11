// services/promptAdapter.js —— 基础提示词风格适配
// 由 .env 的 PROMPT_TEMPLATE 环境变量切换：general（默认）/ step_by_step / concise / exam_oriented
// 模板内容仍以用户自定义模板为主，本模块只追加基础输出风格指令。

const STYLES = {
  general: '请按以下结构输出（通用格式）：\n1. 错因定位\n2. 正确解法（分步）\n3. 涉及知识点讲解\n4. 同类题建议\n5. 记忆口诀或突破要点',
  step_by_step: '请分步骤讲解，每步一行，编号清晰；最后单独列出"易错点"。',
  concise: '请用最简洁的语言输出：先一句错因，再给正确解法要点（不超过 5 行），不重复题目。',
  exam_oriented: '请面向应试输出：突出得分点、易错点、同类题的通用解法模板；使用"得分点：/易错警示："标注。'
};

function getStyleName() {
  const t = (process.env.PROMPT_TEMPLATE || 'general').trim().toLowerCase();
  return STYLES[t] ? t : 'general';
}

function getBaseInstructions() {
  return STYLES[getStyleName()];
}

module.exports = { getBaseInstructions, getStyleName, STYLES };
