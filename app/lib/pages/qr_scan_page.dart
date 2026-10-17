/// pages/qr_scan_page.dart —— 二维码扫描占位
/// 说明：完整二维码扫描需 mobile_scanner 或 zxing 插件（pubspec 未引入，版本号请以 pub.dev 官方页面为准）。
/// 当前实现：手动输入二维码内容，避免引入未验证依赖。
import 'package:flutter/material.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码（占位）')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Text('摄像头扫码插件未集成（TODO：引入 mobile_scanner 后替换此页）。请手动输入二维码中的地址：'),
          const SizedBox(height: 16),
          TextField(controller: _ctrl, decoration: const InputDecoration(labelText: '地址')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ]),
      ),
    );
  }
}
