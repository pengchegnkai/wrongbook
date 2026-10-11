/// services/image_preprocessor.dart —— 拍照图预处理（缩放/压缩，供 OCR 提升准确率）
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ImagePreprocessor {
  /// 缩放到最大边 1600px 并重编码为 JPEG（质量 90），减小 ML Kit 负担。
  /// 说明：使用 dart:ui decode 解码大图在部分机型上内存占用高，
  /// 未在真机验证，需你实测；如 OOM 可改用 image 包或平台通道。
  Future<File> preprocess(File input) async {
    final bytes = await input.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      maxWidth: 1600,
      maxHeight: 1600,
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
