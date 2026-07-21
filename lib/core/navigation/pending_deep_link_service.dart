import 'package:get/get.dart';

/// Keeps one growth-critical route while the user completes authentication.
///
/// Used for claim/invite links so a guest player can sign in and continue the
/// same flow instead of landing on Home and losing context.
class PendingDeepLinkService extends GetxService {
  String? _pendingRoute;

  bool get hasPendingRoute => _pendingRoute != null;

  void store(String? route) {
    final normalized = route?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    _pendingRoute = normalized;
  }

  String? take() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  void clear() {
    _pendingRoute = null;
  }
}
