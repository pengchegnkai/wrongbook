/// pages/scan_page.dart —— 拍照/选图录入错题（入口）
/// 客户端不做任何本地识别：选图后直接进 OCR 校对页（服务端 Tesseract 识别）。
/// 不引入裁剪插件（image_cropper 等原生插件会带来生命周期风险，暂不接入）。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/ui_states.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _picker = ImagePicker();
  File? _image;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 90);
      if (x == null) {
        setState(() => _busy = false);
        return;
      }
      final f = File(x.path);
      if (!await f.exists()) {
        throw Exception('图片文件不存在，请重试');
      }
      setState(() {
        _image = f;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().startsWith('Exception:') ? e.toString().substring(10) : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('录入错题')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _busy
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在打开相机/相册…'),
                      ],
                    ),
                  )
                : _image == null
                    ? EmptyStateView(
                        icon: Icons.camera_alt,
                        title: '拍照或选图录入错题',
                        message: '拍一张清晰的题目照片（含你的作答），\n识别与校对在下一步完成',
                        actionLabel: '拍照',
                        onAction: () => _pick(ImageSource.camera),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_image!, fit: BoxFit.contain),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => context.push('/ocr-review', extra: {'imagePath': _image!.path}),
                            icon: const Icon(Icons.text_fields),
                            label: const Text('开始 OCR 识别并校对'),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('重新拍照'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('从相册另选'),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
