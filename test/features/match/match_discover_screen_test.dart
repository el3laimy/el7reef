import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/services/match_cancellation_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/match_start_service.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_player_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/match/controllers/match_controller.dart';
import 'package:el7reef/features/match/views/match_discover_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    final firestore = FakeFirebaseFirestore();
    final authService = _FakeAuthService(currentUserId: 'player-1');
    final matchRepository = MatchRepositoryImpl(db: firestore);
    final sidePlayerRepository = MatchSidePlayerRepositoryImpl(
      firestore: firestore,
    );

    Get.put<AuthService>(authService);
    Get.put<MatchController>(
      MatchController(
        authService: authService,
        matchRepository: matchRepository,
        sidePlayerRepository: sidePlayerRepository,
        cancellationService: MatchCancellationService(firestore: firestore),
        settlementService: MatchSettlementService(
          firestore: firestore,
          allowLocalFallback: true,
        ),
        matchStartService: MatchStartService(
          matchRepo: matchRepository,
          snapshotRepo: MatchLineupSnapshotRepositoryImpl(firestore: firestore),
          sidePlayerRepo: sidePlayerRepository,
        ),
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('empty discover matches state opens create match sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(locale: Locale('ar'), home: MatchDiscoverScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('اكتشاف'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('لا توجد مباريات جارية حالياً'), findsOneWidget);
    expect(find.text('أنشئ مباراة مفتوحة'), findsOneWidget);

    await tester.tap(find.text('أنشئ مباراة مفتوحة'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ابدأ مباراة جديدة ⚽'), findsOneWidget);
    expect(find.text('المكان (اختياري)'), findsOneWidget);
  });
}

class _FakeAuthService extends GetxService implements AuthService {
  @override
  final Rx<Player?> currentPlayer = Rx<Player?>(null);

  @override
  final RxBool isLoading = false.obs;

  @override
  final Rx<AuthProfileStatus> profileStatus = AuthProfileStatus.ready.obs;

  @override
  final RxString profileErrorMessage = ''.obs;

  final String? _currentUserId;

  _FakeAuthService({required String? currentUserId})
    : _currentUserId = currentUserId {
    final now = DateTime(2026, 7, 4, 10);
    currentPlayer.value = currentUserId == null
        ? null
        : Player(
            id: currentUserId,
            name: 'Test Player',
            createdAt: now,
            lastActiveAt: now,
          );
  }

  @override
  bool get isLoggedIn => _currentUserId != null;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<AuthService> init() async => this;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<Player?> signInWithGoogle() async => currentPlayer.value;

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
