import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/enums/fantasy_league_phase.dart';
import 'package:el7reef/features/fantasy/services/fantasy_lifecycle_service.dart';
import 'package:el7reef/features/fantasy/services/fantasy_market_service.dart';
import 'package:el7reef/features/fantasy/services/fantasy_transfer_policy_service.dart';
import 'package:el7reef/data/repositories/fantasy_lifecycle_repository_impl.dart';
import 'package:el7reef/data/repositories/fantasy_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/data/repositories/tournament_repository_impl.dart';
import 'package:el7reef/domain/entities/fantasy_league_lifecycle.dart';
import 'package:el7reef/domain/entities/fantasy_slot.dart';
import 'package:el7reef/domain/entities/fantasy_team.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/entities/player_fantasy_value.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/fantasy_team_controller.dart';
import 'package:el7reef/features/fantasy/presentation/controllers/transfer_market_controller.dart';
import 'package:el7reef/features/fantasy/presentation/models/fantasy_market_player.dart';
import 'package:el7reef/features/fantasy/presentation/models/fantasy_squad_member.dart';
import 'package:el7reef/features/fantasy/presentation/screens/fantasy_team_screen.dart';
import 'package:el7reef/features/fantasy/presentation/screens/transfer_market_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('fantasy team screen explains live round state clearly',
      (tester) async {
    final deps = _buildDeps();
    final controller = _TestFantasyTeamController(deps)
      ..team.value = _buildTeam(
        currentGameweekPoints: 18,
        totalPoints: 74,
        freeTransfers: 1,
      )
      ..lifecycle.value = FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 3,
        phase: FantasyLeaguePhase.live,
        isLocked: true,
        updatedAt: DateTime(2026, 4, 18, 20),
      );

    controller.starters.assignAll([
      _buildMember(
        playerId: 'starter-1',
        name: 'Ahmed',
        position: 'MID',
        isStartingXI: true,
        role: FantasyPlayerRole.captain,
        pointsEarned: 24,
      ),
    ]);
    controller.bench.assignAll([
      _buildMember(
        playerId: 'bench-1',
        name: 'Bench One',
        position: 'DEF',
        isStartingXI: false,
        benchPriority: 1,
        pointsEarned: 6,
      ),
    ]);

    Get.put<FantasyTeamController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(home: FantasyTeamScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('فريقك مباشر الآن'), findsWidgets);
    expect(
      find.textContaining('قابلة للتغير حتى اعتماد نتائج matchday'),
      findsWidgets,
    );
    expect(find.text('الانتقالات مغلقة'), findsOneWidget);
  });

  testWidgets('transfer market screen previews hit and role state clearly',
      (tester) async {
    final deps = _buildDeps();
    final controller = _TestTransferMarketController(deps)
      ..team.value = _buildTeam(
        freeTransfers: 0,
        freeTransfersGameweek: 4,
        budget: 9.5,
      )
      ..lifecycle.value = FantasyLeagueLifecycle(
        leagueId: 'global',
        currentGameweek: 4,
        phase: FantasyLeaguePhase.transferWindow,
        isLocked: false,
        updatedAt: DateTime(2026, 4, 18, 20),
      );

    controller.transferDecision.value = const FantasyTransferPolicyService()
        .evaluateTransfer(
      team: controller.team.value!,
      lifecycle: controller.lifecycle.value!,
    );
    controller.squad.assignAll([
      _buildMember(
        playerId: 'starter-2',
        name: 'Captain Mid',
        position: 'MID',
        isStartingXI: true,
        role: FantasyPlayerRole.captain,
      ),
    ]);

    Get.put<TransferMarketController>(controller);

    await tester.pumpWidget(
      const GetMaterialApp(home: TransferMarketScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('السوق مفتوح الآن'), findsOneWidget);
    expect(find.text('الصفقة التالية بخصم'), findsOneWidget);
    expect(find.textContaining('ستكلّفك 4 نقاط'), findsOneWidget);
    expect(find.textContaining('رصيدك 0 تبديل مجاني'), findsOneWidget);
    expect(
      find.textContaining('وضوح التكلفة هنا يعتمد على حالة الجولة الحالية'),
      findsOneWidget,
    );
  });
}

class _FantasyTestDeps {
  final FantasyRepositoryImpl fantasyRepository;
  final FantasyMarketService marketService;
  final FantasyLifecycleService lifecycleService;
  final TournamentRepositoryImpl tournamentRepository;

  const _FantasyTestDeps({
    required this.fantasyRepository,
    required this.marketService,
    required this.lifecycleService,
    required this.tournamentRepository,
  });
}

_FantasyTestDeps _buildDeps() {
  final firestore = FakeFirebaseFirestore();
  final fantasyRepository = FantasyRepositoryImpl(db: firestore);
  final playerRepository = PlayerRepositoryImpl(firestore: firestore);
  final tournamentRepository = TournamentRepositoryImpl(db: firestore);
  final lifecycleRepository = FantasyLifecycleRepositoryImpl(firestore: firestore);
  final lifecycleService = FantasyLifecycleService(
    lifecycleRepository: lifecycleRepository,
    tournamentRepository: tournamentRepository,
  );
  final marketService = FantasyMarketService(
    fantasyRepository: fantasyRepository,
    playerRepository: playerRepository,
  );

  return _FantasyTestDeps(
    fantasyRepository: fantasyRepository,
    marketService: marketService,
    lifecycleService: lifecycleService,
    tournamentRepository: tournamentRepository,
  );
}

class _TestFantasyTeamController extends FantasyTeamController {
  _TestFantasyTeamController(_FantasyTestDeps deps)
      : super(
          leagueId: 'global',
          fantasyRepository: deps.fantasyRepository,
          marketService: deps.marketService,
          lifecycleService: deps.lifecycleService,
        );

  @override
  Future<void> loadTeam() async {}
}

class _TestTransferMarketController extends TransferMarketController {
  _TestTransferMarketController(_FantasyTestDeps deps)
      : super(
          leagueId: 'global',
          fantasyRepository: deps.fantasyRepository,
          marketService: deps.marketService,
          lifecycleService: deps.lifecycleService,
          tournamentRepository: deps.tournamentRepository,
        );

  @override
  Future<void> loadData() async {}
}

FantasyTeam _buildTeam({
  double budget = 12.0,
  int totalPoints = 0,
  int currentGameweekPoints = 0,
  int freeTransfers = 1,
  int freeTransfersGameweek = 1,
}) {
  final now = DateTime(2026, 4, 18, 20);
  return FantasyTeam(
    id: 'owner-1',
    ownerPlayerId: 'owner-1',
    teamName: 'Blue Falcons',
    leagueIds: const ['global'],
    budget: budget,
    totalPoints: totalPoints,
    currentGameweekPoints: currentGameweekPoints,
    freeTransfers: freeTransfers,
    freeTransfersGameweek: freeTransfersGameweek,
    createdAt: now,
    updatedAt: now,
  );
}

FantasySquadMember _buildMember({
  required String playerId,
  required String name,
  required String position,
  required bool isStartingXI,
  FantasyPlayerRole role = FantasyPlayerRole.none,
  int benchPriority = 0,
  int pointsEarned = 0,
}) {
  final now = DateTime(2026, 4, 18, 20);
  return FantasySquadMember(
    slot: FantasySlot(
      id: 'slot-$playerId',
      fantasyTeamId: 'owner-1',
      playerId: playerId,
      isStartingXI: isStartingXI,
      benchPriority: benchPriority,
      role: role,
      pointsEarned: pointsEarned,
    ),
    marketPlayer: FantasyMarketPlayer(
      player: Player(
        id: playerId,
        name: name,
        position: position,
        createdAt: now,
        lastActiveAt: now,
      ),
      value: PlayerFantasyValue(
        playerId: playerId,
        currentPrice: 6,
        tier: PlayerTier.bronze,
      ),
    ),
  );
}
