// services/ocrService.js —— OCR 深度纠错流水线
// 图像增强(sharp, 可选) → Tesseract(--psm 6) → 本地 LLM 语义纠错与结构化(可选, 3s 超时降级)
//
// 降级链设计（845/Termux 环境每一步都可能失败，任何一步失败都降级到上一级结果）：
//   sharp 在 Termux 上预编译二进制大概率不可用 → require 失败则跳过预处理
//   LLM 纠错默认 3s 超时（OCR_LLM_TIMEOUT_MS 可调）→ 超时/解析失败则用规则切分结果
const { execFile } = require('child_process');
const fs = require('fs');
const LLAMA_BASE = () => process.env.LLAMA_BASE_URL || 'http://127.0.0.1:8080';
const MODEL_NAME = () => process.env.MODEL_NAME || 'local';
// 用户要求 3s 内完成，超时降级。845 上 1B 模型 3s 内通常只产出少量文本，
// 若希望纠错真正生效，可在 server/.env 调大：OCR_LLM_TIMEOUT_MS=15000
const LLM_TIMEOUT_MS = () => parseInt(process.env.OCR_LLM_TIMEOUT_MS || '3000', 10);

// ---- sharp 可选加载（Termux 上装不上是常态，不作为错误） ----
let sharp = null;
try {
  sharp = require('sharp');
} catch (_) {
  sharp = null;
}
function sharpAvailable() { return sharp !== null; }

/// 图像预处理：EXIF 自动旋转 + 灰度 + 对比度归一化 + 锐化 + 放大到合理宽度
/// 成功返回增强后的新文件路径；失败/未安装 sharp 返回 null（调用方用原图）
async function preprocessImage(srcPath) {
  if (!sharp) return null;
  const dstPath = `${srcPath}_enhanced.jpg`;
  try {
    await sharp(srcPath)
      .rotate()                          // 按 EXIF 自动校正方向
      .resize({ width: 1600, withoutEnlargement: true }) // 限制尺寸，845 上 tesseract 提速明显
      .grayscale()                       // 灰度化
      .normalize()                       // 拉伸对比度（应对拍照阴影/偏色）
      .sharpen({ sigma: 1.2 })           // 锐化（应对轻微失焦）
      .jpeg({ quality: 90 })
      .toFile(dstPath);
    return dstPath;
  } catch (e) {
    try { fs.unlinkSync(dstPath); } catch (_) {}
    return null;
  }
}

/// 执行 tesseract CLI；成功返回识别文本，失败（未安装/语言包缺失/超时/崩溃）返回 null
/// psm 6 = 视作统一文本块，长段落识别率更好；Termux 上必须禁 OpenMP（OMP Error #13）
function runTesseract(filePath, lang) {
  return new Promise((resolve) => {
    execFile(
      'tesseract',
      [filePath, 'stdout', '-l', lang, '--psm', '6'],
      {
        timeout: 120000,
        maxBuffer: 4 * 1024 * 1024,
        env: { ...process.env, KMP_AFFINITY: 'disabled', OMP_NUM_THREADS: '1' },
      },
      (err, stdout) => {
        if (err) return resolve(null);
        resolve(String(stdout || '').trim());
      }
    );
  });
}

/// 文本中 CJK 字符占比（判断纯英文图，chi_sim 会干扰英文符号）
function cjkRatio(text) {
  if (!text) return 0;
  let cjk = 0, total = 0;
  for (const ch of text) {
    if (/\s/.test(ch)) continue;
    total++;
    if (/[\u4e00-\u9fff]/.test(ch)) cjk++;
  }
  return total === 0 ? 0 : cjk / total;
}

// ---- 规则切分（无 LLM 时的兜底；也是 LLM 结构化失败后的兜底） ----
/// 新题起点：行首题号（数字后必须跟标点，避免 "3x+5" 误判）
const Q_NUM_RE = /^[（(](\d{1,3})[）)]|^(\d{1,3})[.、．)]/;
/// 作答起点：行首 解:/答:/答案:/分析: 等
const ANSWER_RE = /^(解|答|答案|解题思路|分析|解答|Solution|Answer)\s*[:：]/;

function splitQuestions(rawText) {
  const lines = String(rawText || '')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const questions = [];
  let cur = null;
  let hasAnyNum = false;

  const flush = () => {
    if (!cur) return;
    const question = cur.lines.join(' ').replace(/\s+/g, ' ').trim();
    const myAnswer = cur.answerLines.join(' ').replace(/\s+/g, ' ').trim();
    if (question || myAnswer) questions.push({ question, myAnswer });
    cur = null;
  };

  for (const line of lines) {
    if (Q_NUM_RE.test(line)) {
      hasAnyNum = true;
      flush();
      cur = { lines: [line], answerLines: [], inAnswer: false };
      continue;
    }
    if (!cur) cur = { lines: [], answerLines: [], inAnswer: false };
    const am = line.match(ANSWER_RE);
    if (am) {
      cur.inAnswer = true;
      cur.answerLines.push(line.slice(am[0].length).trim());
    } else if (cur.inAnswer) {
      cur.answerLines.push(line);
    } else {
      cur.lines.push(line);
    }
  }
  flush();

  // 没识别到题号：整体作为一道题
  if (!hasAnyNum && lines.length > 0) {
    questions.length = 0;
    const idx = lines.findIndex((l) => ANSWER_RE.test(l));
    if (idx >= 0) {
      const marker = lines[idx].match(ANSWER_RE)[0];
      const question = lines.slice(0, idx).join(' ').replace(/\s+/g, ' ').trim();
      const myAnswer = (lines[idx].slice(marker.length).trim() + ' ' + lines.slice(idx + 1).join(' '))
        .replace(/\s+/g, ' ').trim();
      questions.push({ question, myAnswer });
    } else {
      questions.push({ question: lines.join(' ').replace(/\s+/g, ' ').trim(), myAnswer: '' });
    }
  }
  return questions;
}

// ---- LLM 语义纠错与结构化 ----
/// 给 1B 小模型的指令必须极短极明确（上下文有限，长指令反而降低遵循度）。
/// 只要求修 OCR 错字 + 抽字段 + 公式转 LaTeX，不要求解题。
function buildCorrectPrompt(rawText) {
  // 截断输入：1B 模型上下文有限，取前 1200 字符足够覆盖一道题
  const t = String(rawText).slice(0, 1200);
  return [
    '任务：下面是扫描识别文本，含OCR错字。',
    '规则：1.修错字(l/1,O/0,形近字) 2.公式转LaTeX($...$) 3.不改题意 4.只输出JSON。',
    '格式：{"question":"原题","myAnswer":"学生作答","subject":"学科"}',
    '文本：',
    t,
  ].join('\n');
}

/// 从模型输出中提取 JSON（小模型常带前缀/围栏/尾随文本）
function extractJson(text) {
  if (!text) return null;
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    const obj = JSON.parse(text.slice(start, end + 1));
    if (typeof obj.question === 'string') return obj;
    return null;
  } catch (_) {
    return null;
  }
}

/// 调本地 llama-server 纠错。超时（默认 3s）或解析失败返回 null（降级）。
async function llmCorrect(rawText) {
  const body = {
    model: MODEL_NAME(),
    messages: [{ role: 'user', content: buildCorrectPrompt(rawText) }],
    max_tokens: 700,
    temperature: 0.1,   // 纠错任务要确定性，低温度
    stream: false,
  };
  try {
    const r = await fetch(`${LLAMA_BASE()}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(LLM_TIMEOUT_MS()),
    });
    if (!r.ok) return null;
    const data = await r.json();
    const content = data.choices?.[0]?.message?.content || '';
    const obj = extractJson(content);
    if (!obj || !obj.question.trim()) return null;
    return {
      question: obj.question.trim(),
      myAnswer: typeof obj.myAnswer === 'string' ? obj.myAnswer.trim() : '',
      subject: typeof obj.subject === 'string' ? obj.subject.trim() : '',
    };
  } catch (_) {
    return null; // 超时/连接失败 → 降级
  }
}

/// 流水线入口：预处理 → 双语言识别 → LLM 纠错 → 规则切分
/// 返回 { rawText, lang, questions, enhanced, corrected }
async function processImage(srcPath) {
  // 1) 图像增强（可选）
  const enhancedPath = await preprocessImage(srcPath);
  const targetPath = enhancedPath || srcPath;

  // 2) Tesseract 识别：首选 chi_sim+eng，失败降级 eng；英文占比高时用 eng 重识
  let text = await runTesseract(targetPath, 'chi_sim+eng');
  let lang = 'chi_sim+eng';
  if (text === null) {
    text = await runTesseract(targetPath, 'eng');
    lang = 'eng';
    if (text === null) return { error: 'unavailable' };
  } else if (cjkRatio(text) < 0.05) {
    const engText = await runTesseract(targetPath, 'eng');
    if (engText !== null) { text = engText; lang = 'eng'; }
  }
  if (enhancedPath) fs.unlink(enhancedPath, () => {}); // 增强图用完即删
  if (!text) return { error: 'empty' };

  // 3) 规则切分（兜底结果，先算好）
  let questions = splitQuestions(text);

  // 4) LLM 纠错（可选，3s 超时降级）：单题或整体时效果最好；
  //    多题长文本 3s 内纠不完，直接用规则切分结果
  let corrected = false;
  if (questions.length <= 1 && questions.length > 0) {
    const fixed = await llmCorrect(text);
    if (fixed) {
      questions = [{ question: fixed.question, myAnswer: fixed.myAnswer }];
      corrected = true;
      // LLM 判断的学科带回传（写入错题草稿供校对）
      if (fixed.subject) questions[0].subject = fixed.subject;
    }
  }

  return { rawText: text, lang, questions, enhanced: !!enhancedPath, corrected };
}

module.exports = { processImage, splitQuestions, cjkRatio, sharpAvailable, runTesseract };
