// services/templateRenderer.js —— 提示词模板渲染（{{变量}} 替换）
const VARIABLES = ['subject','chapter','knowledgePoints','originalQuestion','myAnswer','correctAnswer',
  'analysis','errorType','mastery','questionType','courseType','extra'];

function renderTemplate(template, vars) {
  let out = template;
  for (const key of VARIABLES) {
    const val = vars[key] == null ? '' : String(vars[key]);
    out = out.split('{{' + key + '}}').join(val);
  }
  // 未提供的变量替换为空串，避免泄漏 {{}} 占位
  out = out.replace(/\{\{[a-zA-Z_]+\}\}/g, '');
  return out;
}

// 根据用户偏好自适应追加风格指令（AI 自进化第 5 步）
function adaptToProfile(template, profile) {
  if (!profile) return template;
  const styleMap = {
    step_by_step: '输出请分步骤讲解，每步一行。',
    concise: '输出请简洁，不要重复题目。',
    detailed: '输出请详尽，包含原理推导。',
    exam_oriented: '输出请面向应试，突出得分点与易错点。'
  };
  const style = styleMap[profile.preferred_explanation_style];
  return style ? template + '\n\n【输出风格要求】' + style : template;
}

module.exports = { renderTemplate, adaptToProfile, VARIABLES };
