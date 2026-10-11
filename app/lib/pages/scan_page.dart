/// pages/scan_page.dart —— 拍照/选图录入错题（入口）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _picker = ImagePicker();
  File? _image;
  String _ocrText = '';
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final x = await _picker.pickImage(source: source, imageQuality: 90);
    if (x == null) return;
    setState(() { _image = File(x.path); _busy = true; });
    // OCR 由 ocr_review 页完成；此处只带图过去
    if (mounted) {
      setState(() => _busy = false);
      context.push('/ocr-review', extra: {'imagePath': x.path});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录入错题')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image != null) Image.file(_image!, height: 200)
            else const Icon(Icons.camera_alt, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            FilledButton.icon(icon: const Icon(Icons.camera_alt), label: const Text('拍照'), onPressed: _busy ? null : () => _pick(ImageSource.camera)),
            const SizedBox(height: 12),
            OutlinedButton.icon(icon: const Icon(Icons.photo), label: const Text('从相册选择'), onPressed: _busy ? null : () => _pick(ImageSource.gallery)),
            const SizedBox(height: 12),
            TextButton.icon(icon: const Icon(Icons.psychology), label: const Text('AI 自动理解（拍照→分区草稿）'),
              onPressed: () => context.go('/ai-understand')),
            if (_ocrText.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_ocrText)),
          ],
        ),
      ),
    );
  }
}

String encodeJson(Object? o) => jsonEncode(o);
