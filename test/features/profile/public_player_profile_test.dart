import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/player_trust_level.dart';
import 'package:el7reef/core/enums/user_role.dart';
import 'package:el7reef/core/services/feature_flag_service.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/data/repositories/match_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/profile/controllers/public_player_profile_controller.dart';
import 'package:el7reef/features/profile/models/public_player_profile_data.dart';
import 'package:el7reef/features/profile/services/public_player_profile_resolver.dart';
import 'package:el7reef/features/profile/views/public_player_profile_screen.dart';

void main() {
  group('PublicPlayerProfileResolver', () {
    test('aggregates goals and MVPs for registered player', () async {
      final fixture = _ResolverFixture();
      await fixture.playerRepository.createPlayer(_player(id: 'player-1'));
      await fixture.seedEvent(
        id: 'goal-1',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
      );
      await fixture.seedEvent(
        id: 'goal-2',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
      );
      await fixture.seedEvent(
        id: 'mvp-1',
        eventType: MatchEventType.mvp,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
      );

      final profile = await fixture.resolver.resolve(
        kind: 'player',
        id: 'player-1',
      );

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Registered Ali');
      expect(profile.badgeLabel, 'لاعب');
      expect(profile.totalGoals, 2);
      expect(profile.totalMvps, 1);
    });

    test(
      'keeps guest goals and MVPs after the player claims the profile',
      () async {
        final fixture = _ResolverFixture();
        await fixture.playerRepository.createPlayer(_player(id: 'player-1'));
        await fixture.guestPlayerRepository.createGuestPlayer(
          _guestPlayer(
            id: 'guest-before-claim',
            displayName: 'Guest Ali',
            linkedPlayerId: 'player-1',
          ),
        );
        await fixture.seedEvent(
          id: 'registered-goal',
          eventType: MatchEventType.goal,
          actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
        );
        await fixture.seedEvent(
          id: 'guest-goal-before-claim',
          eventType: MatchEventType.goal,
          actor: _actor(
            ParticipantRefKind.guestPlayer,
            'guest-before-claim',
            'Guest Ali',
          ),
        );
        await fixture.seedEvent(
          id: 'guest-mvp-before-claim',
          eventType: MatchEventType.mvp,
          actor: _actor(
            ParticipantRefKind.guestPlayer,
            'guest-before-claim',
            'Guest Ali',
          ),
        );

        final profile = await fixture.resolver.resolve(
          kind: 'player',
          id: 'player-1',
        );

        expect(profile, isNotNull);
        expect(profile!.displayName, 'Registered Ali');
        expect(profile.totalGoals, 2);
        expect(profile.totalMvps, 1);
      },
    );

    test(
      'does not query private guest links for another player profile',
      () async {
        final fixture = _ResolverFixture(currentUserId: 'viewer-2');
        await fixture.playerRepository.createPlayer(_player(id: 'player-1'));
        await fixture.guestPlayerRepository.createGuestPlayer(
          _guestPlayer(
            id: 'guest-private-link',
            displayName: 'Guest Ali',
            linkedPlayerId: 'player-1',
          ),
        );
        await fixture.seedEvent(
          id: 'guest-private-goal',
          eventType: MatchEventType.goal,
          actor: _actor(
            ParticipantRefKind.guestPlayer,
            'guest-private-link',
            'Guest Ali',
          ),
        );

        final profile = await fixture.resolver.resolve(
          kind: 'player',
          id: 'player-1',
        );

        expect(profile, isNotNull);
        expect(profile!.totalGoals, 0);
        expect(profile.totalMvps, 0);
      },
    );

    test('aggregates goals and MVPs for guest player', () async {
      final fixture = _ResolverFixture();
      await fixture.guestPlayerRepository.createGuestPlayer(
        _guestPlayer(id: 'guest-1', displayName: 'Guest Ali'),
      );
      await fixture.seedEvent(
        id: 'guest-goal',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.guestPlayer, 'guest-1', 'Guest Ali'),
      );
      await fixture.seedEvent(
        id: 'guest-mvp',
        eventType: MatchEventType.mvp,
        actor: _actor(ParticipantRefKind.guestPlayer, 'guest-1', 'Guest Ali'),
      );

      final profile = await fixture.resolver.resolve(
        kind: 'guestPlayer',
        id: 'guest-1',
      );

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Guest Ali');
      expect(profile.badgeLabel, 'ضيف');
      expect(profile.totalGoals, 1);
      expect(profile.totalMvps, 1);
      expect(profile.showClaimPlaceholder, isTrue);
    });

    test('ignores voided events', () async {
      final fixture = _ResolverFixture();
      await fixture.playerRepository.createPlayer(_player(id: 'player-1'));
      await fixture.seedEvent(
        id: 'active-goal',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
      );
      await fixture.seedEvent(
        id: 'voided-goal',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
        status: MatchEventStatus.voided,
      );

      final profile = await fixture.resolver.resolve(
        kind: 'player',
        id: 'player-1',
      );

      expect(profile, isNotNull);
      expect(profile!.totalGoals, 1);
      expect(profile.totalMvps, 0);
    });

    test('ignores active events until their match result is settled', () async {
      final fixture = _ResolverFixture();
      await fixture.playerRepository.createPlayer(_player(id: 'player-1'));
      await fixture.seedEvent(
        id: 'settled-goal',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
      );
      await fixture.seedEvent(
        id: 'pending-goal',
        eventType: MatchEventType.goal,
        actor: _actor(ParticipantRefKind.player, 'player-1', 'Ali'),
        matchStatus: MatchStatus.pendingReview,
      );

      final profile = await fixture.resolver.resolve(
        kind: 'player',
        id: 'player-1',
      );

      expect(profile, isNotNull);
      expect(profile!.totalGoals, 1);
    });

    test('invalid kind or id returns safe null state', () async {
      final fixture = _ResolverFixture();

      expect(
        await fixture.resolver.resolve(kind: 'matchSidePlayer', id: 'msp-1'),
        isNull,
      );
      expect(await fixture.resolver.resolve(kind: 'player', id: '   '), isNull);
    });

    test(
      'falls back to event actor displayName when source document is missing',
      () async {
        final fixture = _ResolverFixture();
        await fixture.seedEvent(
          id: 'player-fallback-goal',
          eventType: MatchEventType.goal,
          actor: _actor(
            ParticipantRefKind.player,
            'missing-player',
            'Event Player Name',
          ),
        );
        await fixture.seedEvent(
          id: 'guest-fallback-mvp',
          eventType: MatchEventType.mvp,
          actor: _actor(
            ParticipantRefKind.guestPlayer,
            'missing-guest',
            'Event Guest Name',
            linkedPlayerId: 'linked-player-1',
          ),
        );

        final playerProfile = await fixture.resolver.resolve(
          kind: 'player',
          id: 'missing-player',
        );
        final guestProfile = await fixture.resolver.resolve(
          kind: 'guestPlayer',
          id: 'missing-guest',
        );

        expect(playerProfile, isNotNull);
        expect(playerProfile!.displayName, 'Event Player Name');
        expect(playerProfile.totalGoals, 1);
        expect(guestProfile, isNotNull);
        expect(guestProfile!.displayName, 'Event Guest Name');
        expect(guestProfile.linkedPlayerId, 'linked-player-1');
        expect(guestProfile.totalMvps, 1);
      },
    );

    test('returns null when no source document and no events exist', () async {
      final fixture = _ResolverFixture();

      expect(
        await fixture.resolver.resolve(kind: 'player', id: 'missing-player'),
        isNull,
      );
      expect(
        await fixture.resolver.resolve(
          kind: 'guestPlayer',
          id: 'missing-guest',
        ),
        isNull,
      );
    });
  });

  testWidgets('screen shows Arabic labels and guest claim placeholder', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
    );

    expect(find.text('بروفايل اللاعب'), findsOneWidget);
    expect(find.text('ضيف هداف'), findsOneWidget);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('أهداف'), findsOneWidget);
    expect(find.text('نجومية المباراة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsOneWidget);
    expect(find.text('استلم البروفايل'), findsNothing);
  });

  testWidgets('earned milestone CTA opens the picker then the share composer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'هداف الحارة',
        totalGoals: 5,
        totalMvps: 3,
      ),
      routeKind: 'player',
      routeId: 'player-1',
      catalogV2Enabled: true,
    );

    expect(find.text('إنجاز يستحق يتشاف'), findsOneWidget);
    expect(find.text('شارك إنجازك'), findsOneWidget);

    await tester.tap(find.text('شارك إنجازك'));
    await tester.pumpAndSettle();

    expect(find.text('اختار الإنجاز'), findsOneWidget);
    expect(find.text('5 هدف'), findsOneWidget);
    expect(find.text('3 مرات MVP'), findsOneWidget);

    await tester.tap(find.text('5 هدف'));
    await tester.pumpAndSettle();

    expect(find.text('جهّز لحظة الفخر'), findsOneWidget);
  });

  testWidgets('verified milestone CTA stays hidden below every threshold', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.player,
        id: 'player-2',
        displayName: 'لاعب صاعد',
        totalGoals: 4,
        totalMvps: 2,
      ),
      routeKind: 'player',
      routeId: 'player-2',
      catalogV2Enabled: true,
    );

    expect(find.text('إنجاز يستحق يتشاف'), findsNothing);
    expect(find.text('شارك إنجازك'), findsNothing);
  });

  testWidgets('earned milestone CTA stays hidden while catalog V2 is off', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.player,
        id: 'player-3',
        displayName: 'هداف مؤكد',
        totalGoals: 20,
        totalMvps: 10,
      ),
      routeKind: 'player',
      routeId: 'player-3',
    );

    expect(find.text('إنجاز يستحق يتشاف'), findsNothing);
    expect(find.text('شارك إنجازك'), findsNothing);
  });

  testWidgets('guest profile with valid matching token shows claim CTA', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(),
    );

    expect(find.text('استلم البروفايل'), findsOneWidget);
    expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsNothing);
    expect(find.textContaining('CLAIM-CODE-1'), findsNothing);
  });

  testWidgets('claim CTA routes to guest claim screen and preserves code', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(),
      includeClaimRoute: true,
    );

    await tester.tap(find.text('استلم البروفايل'));
    await tester.pumpAndSettle();

    expect(find.text('claim-route:guest-1:CLAIM-CODE-1'), findsOneWidget);
  });

  testWidgets('wrong target token shows safe warning and no claim CTA', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(targetId: 'guest-2'),
    );

    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.text('رابط الدعوة لا يطابق هذا البروفايل.'), findsOneWidget);
  });

  testWidgets('missing code does not show claim CTA', (tester) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(code: ''),
    );

    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.textContaining('رابط الدعوة غير مكتمل'), findsOneWidget);
  });

  testWidgets('type mismatch does not show claim CTA', (tester) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(type: 'guestTeam'),
    );

    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.text('رابط الدعوة لا يخص بروفايل لاعب ضيف.'), findsOneWidget);
  });

  testWidgets('expired token does not show claim CTA', (tester) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(
        expiresAt: DateTime(2020).millisecondsSinceEpoch.toString(),
      ),
    );

    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.textContaining('انتهت صلاحية رابط الدعوة'), findsOneWidget);
  });

  testWidgets('inactive status does not show claim CTA', (tester) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف هداف',
        totalGoals: 3,
        totalMvps: 2,
      ),
      queryParameters: _validClaimQuery(status: 'claimed'),
    );

    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.textContaining('رابط الدعوة لم يعد نشطًا'), findsOneWidget);
  });

  testWidgets('claimed or linked guest profile does not show claim CTA', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف مربوط',
        totalGoals: 1,
        totalMvps: 0,
        linkedPlayerId: 'player-1',
        isClaimed: true,
      ),
      queryParameters: _validClaimQuery(),
    );

    expect(find.text('ضيف مربوط'), findsOneWidget);
    expect(find.text('هذا الضيف مربوط ببروفايل لاعب مسجل.'), findsOneWidget);
    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsNothing);
  });

  testWidgets('registered player profile never shows guest claim CTA', (
    tester,
  ) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'لاعب مسجل',
        totalGoals: 4,
        totalMvps: 1,
      ),
      routeKind: 'player',
      routeId: 'player-1',
      queryParameters: _validClaimQuery(targetId: 'player-1'),
    );

    expect(find.text('لاعب مسجل'), findsOneWidget);
    expect(find.text('استلم البروفايل'), findsNothing);
    expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsNothing);
  });

  testWidgets('screen shows linked guest info panel', (tester) async {
    await _pumpProfileRoute(
      tester,
      const PublicPlayerProfileData(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'ضيف مربوط',
        totalGoals: 1,
        totalMvps: 0,
        linkedPlayerId: 'player-1',
        isClaimed: true,
      ),
    );

    expect(find.text('ضيف مربوط'), findsOneWidget);
    expect(find.text('هذا الضيف مربوط ببروفايل لاعب مسجل.'), findsOneWidget);
    expect(find.textContaining('ده أنت؟ اطلب رابط الدعوة'), findsNothing);
  });
}

Future<void> _pumpProfileRoute(
  WidgetTester tester,
  PublicPlayerProfileData data, {
  String routeKind = 'guestPlayer',
  String routeId = 'guest-1',
  Map<String, String?> queryParameters = const {},
  bool includeClaimRoute = false,
  bool catalogV2Enabled = false,
}) async {
  Get.testMode = true;
  Get.reset();
  addTearDown(Get.reset);

  final route = _withQuery(
    AppRoutes.playerProfileByKindAndId(kind: routeKind, id: routeId),
    queryParameters,
  );
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: route,
      getPages: [
        GetPage(
          name: AppRoutes.playerProfile,
          page: () => const PublicPlayerProfileScreen(),
          binding: BindingsBuilder(() {
            Get.put(
              FeatureFlagService(
                overrides: {
                  FeatureFlagKey.prideShareCatalogV2Enabled: catalogV2Enabled,
                },
              ),
            );
            Get.put(
              PublicPlayerProfileController(
                kind: Get.parameters['kind'] ?? routeKind,
                id: Get.parameters['id'] ?? routeId,
                resolver: _FakeResolver(data),
              ),
            );
          }),
        ),
        if (includeClaimRoute)
          GetPage(
            name: AppRoutes.guestPlayerClaim,
            page: () => Scaffold(
              body: Text(
                'claim-route:${Get.parameters['guestPlayerId']}:${Get.parameters['code']}',
              ),
            ),
          ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, String?> _validClaimQuery({
  String code = 'CLAIM-CODE-1',
  String type = 'guestPlayer',
  String targetId = 'guest-1',
  String status = 'active',
  String? expiresAt,
}) {
  return {
    'code': code,
    'type': type,
    'targetId': targetId,
    'scope': 'team',
    'teamId': 'team-1',
    'tournamentId': 'tournament-1',
    'requiresApproval': '0',
    'expiresAt':
        expiresAt ??
        DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch
            .toString(),
    'status': status,
  };
}

String _withQuery(String path, Map<String, String?> queryParameters) {
  final filtered = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value != null && value.isNotEmpty) {
      filtered[entry.key] = value;
    }
  }
  if (filtered.isEmpty) return path;
  return Uri(path: path, queryParameters: filtered).toString();
}

class _ResolverFixture {
  _ResolverFixture({this.currentUserId = 'player-1'})
    : firestore = FakeFirebaseFirestore() {
    matchEventRepository = MatchEventRepositoryImpl(firestore: firestore);
    matchRepository = MatchRepositoryImpl(firestore: firestore);
    playerRepository = PlayerRepositoryImpl(firestore: firestore);
    guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
    resolver = PublicPlayerProfileResolver(
      playerRepository: playerRepository,
      guestPlayerRepository: guestPlayerRepository,
      matchEventService: MatchEventService(
        repository: matchEventRepository,
        firestore: firestore,
      ),
      matchRepository: matchRepository,
      currentUserId: () => currentUserId,
    );
  }

  final String currentUserId;
  final FakeFirebaseFirestore firestore;
  late final MatchEventRepositoryImpl matchEventRepository;
  late final MatchRepositoryImpl matchRepository;
  late final PlayerRepositoryImpl playerRepository;
  late final GuestPlayerRepositoryImpl guestPlayerRepository;
  late final PublicPlayerProfileResolver resolver;

  Future<void> seedEvent({
    required String id,
    required MatchEventType eventType,
    required ParticipantRef actor,
    MatchEventStatus status = MatchEventStatus.active,
    MatchStatus matchStatus = MatchStatus.settled,
  }) async {
    final matchId = 'match-$id';
    await matchRepository.createMatch(
      Match(
        id: matchId,
        organizerId: 'organizer-1',
        status: matchStatus,
        scoreTeamA: 1,
        scoreTeamB: 0,
        tournamentId: 'tournament-1',
        createdAt: DateTime.utc(2026, 7, 14),
      ),
    );
    await matchEventRepository.createEvent(
      MatchEvent(
        id: id,
        matchId: matchId,
        tournamentId: 'tournament-1',
        eventType: eventType,
        sideKey: 'A',
        actor: actor,
        createdBy: 'organizer-1',
        createdAt: DateTime(2026, 1, id.hashCode.abs() % 20 + 1),
        status: status,
      ),
    );
  }
}

class _FakeResolver extends PublicPlayerProfileResolver {
  final PublicPlayerProfileData? data;

  _FakeResolver(this.data)
    : super(
        playerRepository: PlayerRepositoryImpl(
          firestore: FakeFirebaseFirestore(),
        ),
        guestPlayerRepository: GuestPlayerRepositoryImpl(
          firestore: FakeFirebaseFirestore(),
        ),
        matchEventService: MatchEventService(
          repository: MatchEventRepositoryImpl(
            firestore: FakeFirebaseFirestore(),
          ),
          firestore: FakeFirebaseFirestore(),
        ),
        matchRepository: MatchRepositoryImpl(
          firestore: FakeFirebaseFirestore(),
        ),
      );

  @override
  Future<PublicPlayerProfileData?> resolve({
    required String kind,
    required String id,
  }) async {
    return data;
  }
}

ParticipantRef _actor(
  ParticipantRefKind kind,
  String id,
  String displayName, {
  String? linkedPlayerId,
}) {
  return ParticipantRef(
    kind: kind,
    id: id,
    displayName: displayName,
    linkedPlayerId: linkedPlayerId,
  );
}

Player _player({required String id}) {
  return Player(
    id: id,
    name: 'Registered Ali',
    trustLevel: PlayerTrustLevel.newPlayer,
    role: UserRole.player,
    createdAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
  );
}

GuestPlayer _guestPlayer({
  required String id,
  required String displayName,
  String? linkedPlayerId,
}) {
  return GuestPlayer(
    id: id,
    displayName: displayName,
    normalizedName: displayName.toLowerCase(),
    createdBy: 'organizer-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    claimStatus: linkedPlayerId == null
        ? GuestClaimStatus.guest
        : GuestClaimStatus.claimed,
    linkedPlayerId: linkedPlayerId,
  );
}
