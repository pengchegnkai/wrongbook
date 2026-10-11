/// models/user.dart
class User {
  final int id;
  final String username;
  final String? nickname;
  final String? avatarUrl;
  final String role;
  final String status;

  const User({
    required this.id,
    required this.username,
    this.nickname,
    this.avatarUrl,
    this.role = 'user',
    this.status = 'active',
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        username: j['username'],
        nickname: j['nickname'],
        avatarUrl: j['avatar_url'],
        role: j['role'] ?? 'user',
        status: j['status'] ?? 'active',
      );
}

class LoginDevice {
  final int id;
  final String? deviceInfo;
  final String? ip;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const LoginDevice({required this.id, this.deviceInfo, this.ip, this.expiresAt, this.createdAt});

  factory LoginDevice.fromJson(Map<String, dynamic> j) => LoginDevice(
        id: j['id'],
        deviceInfo: j['device_info'],
        ip: j['ip'],
        expiresAt: j['expires_at'] != null ? DateTime.tryParse(j['expires_at']) : null,
        createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at']) : null,
      );
}
