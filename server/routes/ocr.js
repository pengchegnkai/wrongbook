// routes/ocr.js —— 服务端 OCR（深度纠错流水线入口）
// POST /api/ocr/recognize  (multipart/form-data, 字段名 image, jpg/png, <=10MB)
// 流水线：sharp 图像增强(可选) → tesseract --psm 6 → LLM 纠错(可选,3s 超时降级)
// 返回 { code:0, data:{ rawText, lang, questions:[{question,myAnswer,subject?}], enhanced, corrected } }
// 服务不可用：{ code:1, ... }；未识别到文字：{ code:2, ... }
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { processImage, sharpAvailable } = require('../services/ocrService');

const router = express.Router();

// 临时目录：server/tmp（处理完即删；已加入 .gitignore）
const TMP_DIR = path.join(__dirname, '..', 'tmp');
fs.mkdirSync(TMP_DIR, { recursive: true });

// 兜底清扫：启动时 + 每小时删除超过 2 小时的残留临时文件
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

router.get('/status', (req, res) => {
  res.json({ code: 0, data: { sharp: sharpAvailable() }, message: 'ok' });
});

router.post('/recognize', upload.single('image'), async (req, res, next) => {
  let tmp;
  try {
    if (!req.file) {
      return res.status(400).json({ code: 400, data: null, message: '请上传图片（form 字段名：image）' });
    }
    tmp = req.file.path;
    const result = await processImage(tmp);
    if (result.error === 'unavailable') {
      return res.json({
        code: 1,
        data: null,
        message: 'OCR 服务不可用。请在 Termux 中执行：pkg install tesseract 并确认中文语言包（见 README）',
      });
    }
    if (result.error === 'empty') {
      return res.json({
        code: 2,
        data: null,
        message: '未识别到文字：图片可能空白、模糊或过曝，请重拍清晰的图片',
      });
    }
    res.json({
      code: 0,
      data: {
        rawText: result.rawText,
        lang: result.lang,
        questions: result.questions,
        enhanced: result.enhanced,
        corrected: result.corrected,
      },
      message: 'ok',
    });
  } catch (e) {
    next(e);
  } finally {
    // 处理完删除临时文件（增强图已在 service 内删除）
    if (tmp) fs.unlink(tmp, () => {});
  }
});

module.exports = router;
