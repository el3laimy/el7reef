import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/navigation/pending_deep_link_service.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/auth/views/profile_repair_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('ready profile repair resumes pending guest claim route', (
    tester,
  ) async {
    Get.put<AuthService>(
      _FakeAuthService(
        profileStatus: AuthProfileStatus.ready,
        currentPlayer: _player(),
      ),
    );
    final pendingDeepLinkService = Get.put(PendingDeepLinkService());
    final claimRoute = AppRoutes.guestPlayerClaimById(
      'guest-1',
      queryParameters: {'code': 'claim-code-1'},
    );
    pendingDeepLinkService.store(claimRoute);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.profileRepair,
        getPages: [
          GetPage(
            name: AppRoutes.profileRepair,
            page: () => const ProfileRepairScreen(),
          ),
          GetPage(
            name: AppRoutes.guestPlayerClaim,
            page: () => const Text('guest claim reached'),
          ),
          GetPage(name: AppRoutes.home, page: () => const Text('home')),
          GetPage(name: AppRoutes.login, page: () => const Text('login')),
        ],
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('guest claim reached'), findsOneWidget);
    expect(pendingDeepLinkService.hasPendingRoute, isFalse);
  });

  testWidgets('ready profile repair resumes pending guest team claim route', (
    tester,
  ) async {
    Get.put<AuthService>(
      _FakeAuthService(
        profileStatus: AuthProfileStatus.ready,
        currentPlayer: _player(),
      ),
    );
    final pendingDeepLinkService = Get.put(PendingDeepLinkService());
    final claimRoute = AppRoutes.guestTeamClaimById(
      'guest-team-1',
      queryParameters: {'code': 'team-claim-code-1', 'requiresApproval': '1'},
    );
    pendingDeepLinkService.store(claimRoute);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.profileRepair,
        getPages: [
          GetPage(
            name: AppRoutes.profileRepair,
            page: () => const ProfileRepairScreen(),
          ),
          GetPage(
            name: AppRoutes.guestTeamClaim,
            page: () => const Text('guest team claim reached'),
          ),
          GetPage(name: AppRoutes.home, page: () => const Text('home')),
          GetPage(name: AppRoutes.login, page: () => const Text('login')),
        ],
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('guest team claim reached'), findsOneWidget);
    expect(pendingDeepLinkService.hasPendingRoute, isFalse);
  });
}

class _FakeAuthService extends GetxService implements AuthService {
  final Rx<Player?> _currentPlayer;
  final RxBool _isLoading = false.obs;
  final Rx<AuthProfileStatus> _profileStatus;
  final RxString _profileErrorMessage = ''.obs;

  _FakeAuthService({
    required AuthProfileStatus profileStatus,
    required Player? currentPlayer,
  }) : _currentPlayer = Rx<Player?>(currentPlayer),
       _profileStatus = profileStatus.obs;

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
