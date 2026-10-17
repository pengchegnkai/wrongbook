/// widgets/ocr_result_editor.dart —— OCR 结果编辑器（原文+识别文本对照校对）
import 'package:flutter/material.dart';

class OcrResultEditor extends StatelessWidget {
  final String recognizedText;
  final ValueChanged<String> onChanged;
  final bool lowConfidence;

  const OcrResultEditor({
    super.key,
    required this.recognizedText,
    required this.onChanged,
    this.lowConfidence = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (lowConfidence)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('⚠ 置信度低，请人工核对', style: TextStyle(color: Colors.orange, fontSize: 12)),
        ),
      TextFormField(
        initialValue: recognizedText,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '识别文本（可编辑）',
          alignLabelWithHint: true,
        ),
        onChanged: onChanged,
      ),
    ]);
  }
}
