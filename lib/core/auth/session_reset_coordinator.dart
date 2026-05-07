import 'dart:async';

import 'package:get/get.dart';

typedef SessionResetCallback = FutureOr<void> Function();
typedef SessionStartCallback = FutureOr<void> Function(String userId);

class SessionResetCoordinator extends GetxService {
  final Map<String, SessionResetCallback> _resetCallbacks = {};
  final Map<String, SessionStartCallback> _startCallbacks = {};

  String? _activeUserId;

  String? get activeUserId => _activeUserId;

  void register({
    required String key,
    required SessionResetCallback onReset,
    SessionStartCallback? onSessionStarted,
  }) {
    _resetCallbacks[key] = onReset;
    if (onSessionStarted != null) {
      _startCallbacks[key] = onSessionStarted;
    } else {
      _startCallbacks.remove(key);
    }
  }

  void unregister(String key) {
    _resetCallbacks.remove(key);
    _startCallbacks.remove(key);
  }

  Future<void> handleAuthUidChanged(String? nextUserId) async {
    if (nextUserId == null || nextUserId.isEmpty) {
      _activeUserId = null;
      await clearUserScopedState();
      return;
    }

    final previousUserId = _activeUserId;
    if (previousUserId != null && previousUserId != nextUserId) {
      await clearUserScopedState();
    }
    _activeUserId = nextUserId;
  }

  Future<void> handleSessionStarted(String userId) async {
    if (userId.isEmpty) return;
    _activeUserId = userId;
    for (final callback in List<SessionStartCallback>.of(
      _startCallbacks.values,
    )) {
      await callback(userId);
    }
  }

  Future<void> resetForSignOut() async {
    _activeUserId = null;
    await clearUserScopedState();
  }

  Future<void> clearUserScopedState() async {
    for (final callback in List<SessionResetCallback>.of(
      _resetCallbacks.values,
    )) {
      await callback();
    }
  }
}
