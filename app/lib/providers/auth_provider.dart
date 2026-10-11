/// providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';
import '../models/user.dart';

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<User?>>((ref) {
  return CurrentUserNotifier();
});

class CurrentUserNotifier extends StateNotifier<AsyncValue<User?>> {
  CurrentUserNotifier() : super(const AsyncValue.loading()) {
    _restore();
  }

  Future<void> _restore() async {
    if (await TokenStorage.hasTokens()) {
      try {
        state = AsyncValue.data(await AuthService.me());
      } catch (e) {
        state = AsyncValue.data(null);
      }
    } else {
      state = AsyncValue.data(null);
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.login(username, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String username, String password, String nickname) async {
    state = const AsyncValue.loading();
    try {
      final user = await AuthService.register(username, password, nickname);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AsyncValue.data(null);
  }
}
