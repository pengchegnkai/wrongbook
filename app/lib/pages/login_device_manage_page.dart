/// pages/login_device_manage_page.dart —— 登录设备管理：查看与远程注销
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class LoginDeviceManagePage extends ConsumerStatefulWidget {
  const LoginDeviceManagePage({super.key});

  @override
  ConsumerState<LoginDeviceManagePage> createState() => _LoginDeviceManagePageState();
}

class _LoginDeviceManagePageState extends ConsumerState<LoginDeviceManagePage> {
  List<dynamic> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AuthService.devices();
      setState(() => _devices = d);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录设备')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? const Center(child: Text('暂无其他登录设备'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _devices.length,
                  itemBuilder: (_, i) {
                    final d = _devices[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: Text(d.deviceInfo ?? '未知设备', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('IP: ${d.ip ?? '-'} · 登录于 ${d.createdAt ?? '-'}', style: const TextStyle(fontSize: 11)),
                        trailing: TextButton(onPressed: () async {
                          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                            title: const Text('强制下线'),
                            content: const Text('确定让该设备退出登录？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('下线')),
                            ],
                          ));
                          if (ok == true) {
                            await AuthService.logoutDevice(d.id);
                            _load();
                          }
                        }, child: const Text('下线')),
                      ),
                    );
                  },
                ),
    );
  }
}
