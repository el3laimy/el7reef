import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_pages.dart';
import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/domain/entities/player.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('repair-required profile routes from splash to profile repair', (
    tester,
  ) async {
    Get.put<AuthService>(
      _FakeAuthService(
        profileStatus: AuthProfileStatus.repairRequired,
        currentPlayer: _player(),
        profileErrorMessage: 'تم تسجيل الدخول، لكن لا يمكن تجهيز بيانات حسابك.',
      ),
    );

    await tester.pumpWidget(
      GetMaterialApp(initialRoute: AppRoutes.splash, getPages: AppPages.routes),
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.profileRepair);
    expect(find.text('حسابك محتاج محاولة تانية'), findsOneWidget);
    expect(
      find.text('تم تسجيل الدخول، لكن لا يمكن تجهيز بيانات حسابك.'),
      findsOneWidget,
    );
  });
}

class _FakeAuthService extends GetxService implements AuthService {
  final Rx<Player?> _currentPlayer;
  final RxBool _isLoading = false.obs;
  final Rx<AuthProfileStatus> _profileStatus;
  final RxString _profileErrorMessage;

  _FakeAuthService({
    required AuthProfileStatus profileStatus,
    required Player? currentPlayer,
    required String profileErrorMessage,
  }) : _currentPlayer = Rx<Player?>(currentPlayer),
       _profileStatus = profileStatus.obs,
       _profileErrorMessage = profileErrorMessage.obs;

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
  Future<Player?> signInWithGoogle() async => _currentPlayer.value;

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {
    _currentPlayer.value = null;
    _profileStatus.value = AuthProfileStatus.unauthenticated;
  }
}

Player _player() {
  final now = DateTime(2026, 7, 3);
  return Player(
    id: 'player-1',
    name: 'لاعب',
    createdAt: now,
    lastActiveAt: now,
  );
}
