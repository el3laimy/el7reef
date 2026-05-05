import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/enums/player_trust_level.dart';
import 'package:el7reef/core/enums/user_role.dart';
import 'package:el7reef/core/services/match_event_service.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/data/repositories/match_event_repository_impl.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
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
    Get.testMode = true;
    addTearDown(Get.reset);
    Get.put(
      PublicPlayerProfileController(
        kind: 'guestPlayer',
        id: 'guest-1',
        resolver: _FakeResolver(
          const PublicPlayerProfileData(
            kind: ParticipantRefKind.guestPlayer,
            id: 'guest-1',
            displayName: 'ضيف هداف',
            totalGoals: 3,
            totalMvps: 2,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: PublicPlayerProfileScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('بروفايل اللاعب'), findsOneWidget);
    expect(find.text('ضيف هداف'), findsOneWidget);
    expect(find.text('ضيف'), findsOneWidget);
    expect(find.text('أهداف'), findsOneWidget);
    expect(find.text('نجومية المباراة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('ده أنت؟ اطلب ربط البروفايل'), findsOneWidget);
  });

  testWidgets('screen shows linked guest info panel', (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    Get.put(
      PublicPlayerProfileController(
        kind: 'guestPlayer',
        id: 'guest-1',
        resolver: _FakeResolver(
          const PublicPlayerProfileData(
            kind: ParticipantRefKind.guestPlayer,
            id: 'guest-1',
            displayName: 'ضيف مربوط',
            totalGoals: 1,
            totalMvps: 0,
            linkedPlayerId: 'player-1',
            isClaimed: true,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const GetMaterialApp(home: PublicPlayerProfileScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ضيف مربوط'), findsOneWidget);
    expect(find.text('هذا الضيف مربوط ببروفايل لاعب مسجل.'), findsOneWidget);
    expect(find.textContaining('ده أنت؟ اطلب ربط البروفايل'), findsNothing);
  });
}

class _ResolverFixture {
  _ResolverFixture() : firestore = FakeFirebaseFirestore() {
    matchEventRepository = MatchEventRepositoryImpl(firestore: firestore);
    playerRepository = PlayerRepositoryImpl(firestore: firestore);
    guestPlayerRepository = GuestPlayerRepositoryImpl(firestore: firestore);
    resolver = PublicPlayerProfileResolver(
      playerRepository: playerRepository,
      guestPlayerRepository: guestPlayerRepository,
      matchEventService: MatchEventService(repository: matchEventRepository),
    );
  }

  final FakeFirebaseFirestore firestore;
  late final MatchEventRepositoryImpl matchEventRepository;
  late final PlayerRepositoryImpl playerRepository;
  late final GuestPlayerRepositoryImpl guestPlayerRepository;
  late final PublicPlayerProfileResolver resolver;

  Future<void> seedEvent({
    required String id,
    required MatchEventType eventType,
    required ParticipantRef actor,
    MatchEventStatus status = MatchEventStatus.active,
  }) {
    return matchEventRepository.createEvent(
      MatchEvent(
        id: id,
        matchId: 'match-$id',
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

GuestPlayer _guestPlayer({required String id, required String displayName}) {
  return GuestPlayer(
    id: id,
    displayName: displayName,
    normalizedName: displayName.toLowerCase(),
    createdBy: 'organizer-1',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    claimStatus: GuestClaimStatus.guest,
  );
}
