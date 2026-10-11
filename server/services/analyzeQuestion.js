// services/analyzeQuestion.js —— 调用本地模型分析错题
const { chat } = require('./llamaClient');
const { isAvailable } = require('./llamaClient');

async function analyzeQuestion({ prompt, strength }) {
  if (!(await isAvailable())) {
    throw new Error('本地模型服务（llama-server :8080）未运行，请先在 TUI 或 start-all.sh 启动');
  }
  return chat({ prompt, strength });
}

module.exports = { analyzeQuestion };
