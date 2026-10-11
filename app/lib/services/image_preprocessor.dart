/// services/image_preprocessor.dart —— 拍照图预处理（缩放/压缩，供 OCR 提升准确率）
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ImagePreprocessor {
  /// 缩放到最大边 1600px 并重编码（质量 90），减小 ML Kit 负担。
  /// 新版 Flutter 的 instantiateImageCodec 已移除 maxWidth/maxHeight 参数，
  /// 使用 instantiateImageCodecWithSize + getTargetSize 实现。未在真机验证，需你实测。
  Future<File> preprocess(File input) async {
    final bytes = await input.readAsBytes();
    const maxSide = 1600;
    final codec = await ui.instantiateImageCodecWithSize(
      bytes,
      getTargetSize: (int w, int h) {
        if (w <= maxSide && h <= maxSide) {
          return ui.TargetImageSize(width: w, height: h);
        }
        final double scale = maxSide / (w > h ? w : h);
        return ui.TargetImageSize(
            width: (w * scale).round(), height: (h * scale).round());
      },
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    codec.dispose();

    final dir = input.parent.path;
    final out = File('$dir/preprocessed_${DateTime.now().millisecondsSinceEpoch}.png');
    await out.writeAsBytes(data!.buffer.asUint8List());
    return out;
  }
}
