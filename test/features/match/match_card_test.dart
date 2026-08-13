import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/services/feature_flag_service.dart';
import 'package:el7reef/core/services/match_cancellation_service.dart';
import 'package:el7reef/core/services/match_settlement_service.dart';
import 'package:el7reef/core/services/match_start_service.dart';
import 'package:el7reef/data/repositories/match_lineup_snapshot_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/match_side_player_repository_impl.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/match/controllers/match_controller.dart';
import 'package:el7reef/features/match/widgets/match_card.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('does not expose matchday management to public viewers', (
    tester,
  ) async {
    final controller = _controllerFor(currentUserId: 'viewer-1');
    final match = _match(
      isOrganized: true,
      teamAId: 'team-a',
      teamBId: 'team-b',
    );

    await _pumpCard(tester, controller: controller, match: match);

    expect(find.text('إدارة المباراة'), findsNothing);
    expect(find.text('تفاصيل مباراتي'), findsNothing);
    expect(find.text('عرض المباراة'), findsNothing);
  });

  testWidgets('shows matchday management to organizers', (tester) async {
    final controller = _controllerFor(currentUserId: 'organizer-1');

    await _pumpCard(tester, controller: controller, match: _match());

    expect(find.text('إدارة المباراة'), findsOneWidget);
    expect(find.text('تفاصيل مباراتي'), findsNothing);
  });

  testWidgets('shows matchday details to match participants', (tester) async {
    final controller = _controllerFor(currentUserId: 'player-1');
    final match = _match(teamAPlayerIds: const ['player-1']);

    await _pumpCard(tester, controller: controller, match: match);

    expect(find.text('تفاصيل مباراتي'), findsOneWidget);
    expect(find.text('إدارة المباراة'), findsNothing);
  });

  testWidgets('hides the fan voting entrance while Wave 0 flag is off', (
    tester,
  ) async {
    final controller = _controllerFor(currentUserId: 'viewer-1');

    await _pumpCard(
      tester,
      controller: controller,
      match: _match(status: MatchStatus.settled),
    );

    expect(find.text('تصويت رجل المباراة (الجماهير)'), findsNothing);
  });

  testWidgets('shows fan voting only after an explicit flag override', (
    tester,
  ) async {
    Get.put(
      FeatureFlagService(
        overrides: const {FeatureFlagKey.fanVotingEnabled: true},
      ),
    );
    final controller = _controllerFor(currentUserId: 'viewer-1');

    await _pumpCard(
      tester,
      controller: controller,
      match: _match(status: MatchStatus.settled),
    );

    expect(find.text('تصويت رجل المباراة (الجماهير)'), findsOneWidget);
  });
}

MatchController _controllerFor({required String currentUserId}) {
  final firestore = FakeFirebaseFirestore();
  final matchRepository = MatchRepositoryImpl(db: firestore);
  final sidePlayerRepository = MatchSidePlayerRepositoryImpl(
    firestore: firestore,
  );
  return MatchController(
    authService: _FakeAuthService(currentUserId),
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
  );
}

Widget _buildCard({required MatchController controller, required Match match}) {
  return GetMaterialApp(
    locale: const Locale('ar'),
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: MatchCard(match: match, index: 0, controller: controller),
      ),
    ),
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required MatchController controller,
  required Match match,
}) async {
  await tester.pumpWidget(_buildCard(controller: controller, match: match));
  await tester.pumpAndSettle();
}

Match _match({
  bool isOrganized = false,
  String? teamAId,
  String? teamBId,
  List<String> teamAPlayerIds = const [],
  List<String> teamBPlayerIds = const [],
  MatchStatus status = MatchStatus.open,
}) {
  return Match(
    id: 'match-1',
    organizerId: 'organizer-1',
    teamAId: teamAId,
    teamBId: teamBId,
    teamAPlayerIds: teamAPlayerIds,
    teamBPlayerIds: teamBPlayerIds,
    status: status,
    isOrganized: isOrganized,
    createdAt: DateTime(2026, 6, 5),
  );
}

class _FakeAuthService extends GetxService implements AuthService {
  final Rx<Player?> _currentPlayer;
  final RxBool _isLoading = false.obs;
  final Rx<AuthProfileStatus> _profileStatus = AuthProfileStatus.ready.obs;
  final RxString _profileErrorMessage = ''.obs;

  _FakeAuthService(String currentUserId)
    : _currentPlayer = Rx<Player?>(
        Player(
          id: currentUserId,
          name: currentUserId,
          createdAt: DateTime(2026, 6, 5),
          lastActiveAt: DateTime(2026, 6, 5),
        ),
      );

  @override
  Rx<Player?> get currentPlayer => _currentPlayer;

  @override
  String? get currentUserId => _currentPlayer.value?.id;

  @override
  bool get isLoggedIn => currentUserId != null;

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
