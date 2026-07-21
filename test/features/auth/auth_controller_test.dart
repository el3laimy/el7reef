import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/navigation/pending_deep_link_service.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/auth/controllers/auth_controller.dart';
import 'package:el7reef/features/auth/views/login_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('Google sign-in cancellation leaves no visible error', () async {
    final pendingDeepLinkService = Get.put(PendingDeepLinkService());
    pendingDeepLinkService.store(AppRoutes.createTournament);
    Get.put<AuthService>(_FakeAuthService(signInResult: null));
    final controller = AuthController();
    controller.setCommunityPolicyAccepted(true);

    await controller.signInWithGoogle();

    expect(controller.errorMessage.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
    expect(pendingDeepLinkService.take(), AppRoutes.createTournament);
  });

  test('empty sign-in error is ignored like a cancellation', () async {
    final pendingDeepLinkService = Get.put(PendingDeepLinkService());
    pendingDeepLinkService.store(AppRoutes.createTeam);
    Get.put<AuthService>(_FakeAuthService(signInError: ''));
    final controller = AuthController();
    controller.setCommunityPolicyAccepted(true);

    await controller.signInWithGoogle();

    expect(controller.errorMessage.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
    expect(pendingDeepLinkService.take(), AppRoutes.createTeam);
  });

  testWidgets('Google sign-in explains the community policy gate before auth', (
    tester,
  ) async {
    final authService = _FakeAuthService(signInResult: null);
    Get.put<AuthService>(authService);
    Get.put(PendingDeepLinkService());
    Get.put(AuthController());

    await tester.pumpWidget(const GetMaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final signInButton = find.widgetWithText(
      ElevatedButton,
      'سجّل دخولك بـ Google',
    );
    expect(tester.widget<ElevatedButton>(signInButton).onPressed, isNotNull);

    await tester.tap(signInButton);
    await tester.pumpAndSettle();
    expect(
      find.text(AuthController.communityPolicyRequiredMessage),
      findsOneWidget,
    );
    expect(authService.signInCalls, 0);

    await tester.tap(find.text('أوافق على قواعد المجتمع وسياسة الخصوصية'));
    await tester.pumpAndSettle();
    expect(
      find.text(AuthController.communityPolicyRequiredMessage),
      findsNothing,
    );

    await tester.tap(signInButton);
    await tester.pumpAndSettle();
    expect(authService.signInCalls, 1);
  });
}

class _FakeAuthService extends GetxService implements AuthService {
  final Player? signInResult;
  final Object? signInError;
  final Rx<Player?> _currentPlayer;
  final RxBool _isLoading = false.obs;
  final Rx<AuthProfileStatus> _profileStatus =
      AuthProfileStatus.unauthenticated.obs;
  final RxString _profileErrorMessage = ''.obs;
  int signInCalls = 0;

  _FakeAuthService({this.signInResult, this.signInError})
    : _currentPlayer = Rx<Player?>(signInResult);

  @override
  Rx<Player?> get currentPlayer => _currentPlayer;

  @override
  String? get currentUserId => _currentPlayer.value?.id;

  @override
  bool get isLoggedIn => _currentPlayer.value != null;

  @override
  RxBool get isLoading => _isLoading;

  @override
  Rx<AuthProfileStatus> get profileStatus => _profileStatus;

  @override
  RxString get profileErrorMessage => _profileErrorMessage;

  @override
  Future<AuthService> init() async => this;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<Player?> signInWithGoogle() async {
    signInCalls += 1;
    final error = signInError;
    if (error != null) throw error;
    return signInResult;
  }

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {
    _currentPlayer.value = null;
    _profileStatus.value = AuthProfileStatus.unauthenticated;
  }
}
