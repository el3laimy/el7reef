import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../auth/auth_service.dart';
import '../utils/app_logger.dart';
import 'app_link_route_parser.dart';
import 'pending_deep_link_service.dart';

class AppLinkService extends GetxService {
  static final AppLinks _appLinks = AppLinks();

  final PendingDeepLinkService _pendingDeepLinkService;
  final Future<Uri?> Function() _getInitialLink;
  final Stream<Uri> _uriLinkStream;
  final bool Function() _canNavigate;
  final void Function(String route) _navigate;
  StreamSubscription<Uri>? _subscription;

  AppLinkService({
    PendingDeepLinkService? pendingDeepLinkService,
    Future<Uri?> Function()? getInitialLink,
    Stream<Uri>? uriLinkStream,
    bool Function()? canNavigate,
    void Function(String route)? navigate,
  }) : _pendingDeepLinkService =
           pendingDeepLinkService ?? _resolvePendingDeepLinkService(),
       _getInitialLink = getInitialLink ?? _appLinks.getInitialLink,
       _uriLinkStream = uriLinkStream ?? _appLinks.uriLinkStream,
       _canNavigate = canNavigate ?? _canNavigateWithGetX,
       _navigate = navigate ?? _navigateWithGetX;

  Future<AppLinkService> init() {
    _subscription ??= _uriLinkStream.listen(
      handleUri,
      onError: (Object error) {
        AppLogger.warning('AppLinkService.uriLinkStream', error);
      },
    );

    unawaited(_loadInitialLink());
    return Future<AppLinkService>.value(this);
  }

  Future<void> _loadInitialLink() async {
    try {
      final initialUri = await _getInitialLink();
      if (initialUri != null) {
        handleUri(initialUri);
      }
    } catch (error, stackTrace) {
      AppLogger.error('AppLinkService.getInitialLink', error, stackTrace);
    }
  }

  String? handleUri(Uri uri) {
    final route = AppLinkRouteParser.routeFor(uri);
    if (route == null) return null;

    _pendingDeepLinkService.store(route);
    if (_canNavigate()) {
      final pendingRoute = _pendingDeepLinkService.take();
      if (pendingRoute != null) {
        _navigate(pendingRoute);
      }
    }
    return route;
  }

  @override
  void onClose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    _subscription = null;
    super.onClose();
  }

  static PendingDeepLinkService _resolvePendingDeepLinkService() {
    if (Get.isRegistered<PendingDeepLinkService>()) {
      return Get.find<PendingDeepLinkService>();
    }
    return Get.put(PendingDeepLinkService(), permanent: true);
  }

  static bool _canNavigateWithGetX() {
    final navigatorState = Get.key.currentState;
    if (navigatorState == null || !navigatorState.mounted) return false;
    if (Get.currentRoute.isEmpty || Get.currentRoute == AppRoutes.splash) {
      return false;
    }
    if (!Get.isRegistered<AuthService>()) return false;

    final status = Get.find<AuthService>().profileStatus.value;
    return status == AuthProfileStatus.ready ||
        status == AuthProfileStatus.unauthenticated;
  }

  static void _navigateWithGetX(String route) {
    Get.offAllNamed(route);
  }
}
