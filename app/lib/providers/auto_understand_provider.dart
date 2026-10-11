/// providers/auto_understand_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_understand_service.dart';
import '../models/auto_understand_result.dart';

class AutoUnderstandState {
  final bool running;
  final AutoUnderstandResult? result;
  final String? error;
  const AutoUnderstandState({this.running = false, this.result, this.error});
}

class AutoUnderstandNotifier extends StateNotifier<AutoUnderstandState> {
  final AutoUnderstandService _svc = AutoUnderstandService();

  AutoUnderstandNotifier() : super(const AutoUnderstandState());

  Future<void> understand(String ocrText) async {
    state = const AutoUnderstandState(running: true);
    try {
      final result = await _svc.understand(ocrText);
      state = AutoUnderstandState(result: result);
    } catch (e) {
      state = AutoUnderstandState(error: e.toString());
    }
  }

  void reset() => state = const AutoUnderstandState();
}

final autoUnderstandProvider = StateNotifierProvider<AutoUnderstandNotifier, AutoUnderstandState>(
    (ref) => AutoUnderstandNotifier());
