/// pages/qr_scan_page.dart —— 摄像头扫码（mobile_scanner）
/// 识别二维码内容后 pop 返回给调用方（服务器配置页）。
/// 相册识别 + 手动输入作为降级入口。
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _manualCtrl = TextEditingController();
  MobileScannerController? _scanner;
  bool _handled = false; // 防止同一帧多次回调重复 pop
  bool _torchOn = false;

  @override
  void dispose() {
    _scanner?.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描服务器二维码'), actions: [
        IconButton(
          icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          tooltip: '手电筒',
          onPressed: () async {
            final s = _scanner ??= MobileScannerController();
            await s.toggleTorch();
            if (mounted) setState(() => _torchOn = !_torchOn);
          },
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: MobileScanner(
            controller: _scanner ??= MobileScannerController(),
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('相机不可用：$error\n\n可用下方手动输入替代',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  decoration: const InputDecoration(
                    labelText: '或手动输入地址',
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final v = _manualCtrl.text.trim();
                  if (v.isNotEmpty) Navigator.of(context).pop(v);
                },
                child: const Text('确定'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
