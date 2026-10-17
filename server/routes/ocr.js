// routes/ocr.js —— 服务端 OCR（Termux Tesseract）
// POST /api/ocr/recognize  (multipart/form-data, 字段名 image, jpg/png, <=10MB)
// 返回 { code: 0, data: { rawText, lang, questions: [{question, myAnswer}] } }
// Tesseract 未安装/识别失败：{ code: 1, data: null, message: 'OCR 服务不可用...' }
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const router = express.Router();

// 临时目录：server/tmp（处理完即删；已加入 .gitignore）
const TMP_DIR = path.join(__dirname, '..', 'tmp');
fs.mkdirSync(TMP_DIR, { recursive: true });

// 兜底清扫：启动时 + 每小时删除超过 2 小时的残留临时文件。
// 覆盖 multer 在 fileFilter/大小限制中断后残留的部分写入文件等所有泄漏路径
function sweepTmp() {
  try {
    const cutoff = Date.now() - 2 * 60 * 60 * 1000;
    for (const name of fs.readdirSync(TMP_DIR)) {
      const p = path.join(TMP_DIR, name);
      try {
        if (fs.statSync(p).mtimeMs < cutoff) fs.unlink(p, () => {});
      } catch (_) { /* 单个文件失败忽略 */ }
    }
  } catch (_) { /* 目录读取失败忽略 */ }
}
sweepTmp();
setInterval(sweepTmp, 60 * 60 * 1000).unref();

const upload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, TMP_DIR),
    filename: (req, file, cb) => cb(null, `ocr_${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${file.mimetype === 'image/png' ? 'png' : 'jpg'}`),
  }),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'image/jpeg' || file.mimetype === 'image/png') return cb(null, true);
    cb(new Error('仅支持 jpg/png 图片'));
  },
});

/// 执行 tesseract CLI；成功返回识别文本，失败（未安装/语言包缺失/超时）返回 null
/// 注意：Termux 上 tesseract 的 OpenMP 默认线程亲和性会崩溃（OMP Error #13），
/// 必须传 KMP_AFFINITY=disabled + OMP_NUM_THREADS=1
function runTesseract(filePath, lang) {
  return new Promise((resolve) => {
    execFile(
      'tesseract',
      [filePath, 'stdout', '-l', lang],
      {
        timeout: 120000,
        maxBuffer: 4 * 1024 * 1024,
        env: { ...process.env, KMP_AFFINITY: 'disabled', OMP_NUM_THREADS: '1' },
      },
      (err, stdout, stderr) => {
        if (err) return resolve(null); // 执行失败（未安装/语言包缺失/超时/崩溃）
        resolve(String(stdout || '').trim()); // 成功：可能为空串（空白/过曝图）
      }
    );
  });
}

/// 按题号切分识别文本：
/// - 新题起点：行首 "1." "2、" "3．" "4)" "(5)" "（6）" 等题号（数字后必须跟标点，避免 "3x+5" 误判）
/// - 作答起点：行首 "解：" "答：" "答案：" "分析："（含英文 Solution/Answer），其后内容归入 myAnswer
/// - 无题号时整体作为一道题
function splitQuestions(rawText) {
  const lines = String(rawText || '')
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  const qNumRe = /^[（(](\d{1,3})[）)]|^(\d{1,3})[.、．)]/;
  const answerRe = /^(解|答|答案|解题思路|分析|解答|Solution|Answer)\s*[:：]/;

  const questions = [];
  let cur = null; // { lines: [], answerLines: [] }
  let hasAnyNum = false;

  const flush = () => {
    if (!cur) return;
    const question = cur.lines.join(' ').replace(/\s+/g, ' ').trim();
    const myAnswer = cur.answerLines.join(' ').replace(/\s+/g, ' ').trim();
    if (question || myAnswer) questions.push({ question, myAnswer });
    cur = null;
  };

  for (const line of lines) {
    if (qNumRe.test(line)) {
      hasAnyNum = true;
      flush();
      cur = { lines: [line], answerLines: [], inAnswer: false };
      continue;
    }
    if (!cur) cur = { lines: [], answerLines: [], inAnswer: false };
    const am = line.match(answerRe);
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

  // 没识别到题号：整体作为一道题，作答段仍按 解:/答: 切分
  if (!hasAnyNum && lines.length > 0) {
    questions.length = 0;
    const idx = lines.findIndex((l) => answerRe.test(l));
    if (idx >= 0) {
      const question = lines.slice(0, idx).join(' ').replace(/\s+/g, ' ').trim();
      const marker = lines[idx].match(answerRe)[0];
      const myAnswer =
        lines[idx].slice(marker.length).trim() + ' ' + lines.slice(idx + 1).join(' ');
      questions.push({ question, myAnswer: myAnswer.replace(/\s+/g, ' ').trim() });
    } else {
      questions.push({ question: lines.join(' ').replace(/\s+/g, ' ').trim(), myAnswer: '' });
    }
  }

  return questions;
}

/// 文本中 CJK 字符占比（用于判断是否纯英文图）
function cjkRatio(text) {
  if (!text) return 0;
  let cjk = 0;
  let total = 0;
  for (const ch of text) {
    if (/\s/.test(ch)) continue;
    total++;
    if (/[\u4e00-\u9fff]/.test(ch)) cjk++;
  }
  return total === 0 ? 0 : cjk / total;
}

router.post('/recognize', upload.single('image'), async (req, res, next) => {
  let tmp;
  try {
    if (!req.file) {
      return res.status(400).json({ code: 400, data: null, message: '请上传图片（form 字段名：image）' });
    }
    tmp = req.file.path;
    // 首选中文+英文；中文语言包不可用时降级纯英文
    let text = await runTesseract(tmp, 'chi_sim+eng');
    let lang = 'chi_sim+eng';
    if (text === null) {
      text = await runTesseract(tmp, 'eng');
      lang = 'eng';
      if (text === null) {
        return res.json({
          code: 1,
          data: null,
          message: 'OCR 服务不可用。请在 Termux 中执行：pkg install tesseract 并确认中文语言包（见 README）',
        });
      }
    } else if (cjkRatio(text) < 0.05) {
      // 启发式：识别结果里几乎没有中文字 → 大概率是纯英文/符号图，
      // 中文语言包会干扰英文符号（如 "+" 被识别为 "2 二"），用纯 eng 重识一次
      const engText = await runTesseract(tmp, 'eng');
      if (engText !== null) {
        text = engText;
        lang = 'eng';
      }
    }
    if (!text) {
      // 识别执行成功但没认出任何文字：图片问题，而非服务问题
      return res.json({
        code: 2,
        data: null,
        message: '未识别到文字：图片可能空白、模糊或过曝，请重拍清晰的图片',
      });
    }
    const questions = splitQuestions(text);
    res.json({ code: 0, data: { rawText: text, lang, questions }, message: 'ok' });
  } catch (e) {
    next(e);
  } finally {
    // 处理完删除临时文件
    if (tmp) fs.unlink(tmp, () => {});
  }
});

module.exports = router;
