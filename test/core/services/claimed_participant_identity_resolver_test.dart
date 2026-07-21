import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/services/claimed_participant_identity_resolver.dart';
import 'package:el7reef/data/repositories/guest_player_repository_impl.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/controllers/mvp_share_controller.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late GuestPlayerRepositoryImpl guestRepository;
  late ClaimedParticipantIdentityResolver resolver;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    guestRepository = GuestPlayerRepositoryImpl(firestore: firestore);
    resolver = ClaimedParticipantIdentityResolver(
      guestPlayerRepository: guestRepository,
    );
  });

  test('keeps an unclaimed guest identity unchanged', () async {
    const actor = ParticipantRef(
      kind: ParticipantRefKind.guestPlayer,
      id: 'guest-unclaimed',
      displayName: 'ضيف',
    );

    expect(await resolver.resolve(actor), same(actor));
  });

  test('resolves a historical guest through the current claim link', () async {
    final now = DateTime(2026, 7, 13);
    await guestRepository.createGuestPlayer(
      GuestPlayer(
        id: 'guest-claimed',
        displayName: 'نجم الضيوف',
        normalizedName: 'نجم الضيوف',
        createdBy: 'organizer-1',
        linkedPlayerId: 'player-claimed',
        createdAt: now,
        updatedAt: now,
      ),
    );
    const actor = ParticipantRef(
      kind: ParticipantRefKind.guestPlayer,
      id: 'guest-claimed',
      displayName: 'نجم الضيوف',
    );

    final resolved = await resolver.resolve(actor);

    expect(resolved.kind, ParticipantRefKind.player);
    expect(resolved.id, 'player-claimed');
  });

  test(
    'MVP pride payload targets the registered profile after claim',
    () async {
      const actor = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-mvp',
        displayName: 'نجم المباراة',
        linkedPlayerId: 'player-mvp',
      );
      final resolved = await resolver.resolve(actor);
      final event = MatchEvent(
        id: 'mvp-match-1',
        matchId: 'match-1',
        eventType: MatchEventType.mvp,
        sideKey: 'A',
        actor: resolved,
        createdBy: 'organizer-1',
        createdAt: DateTime(2026, 7, 13),
      );
      final match = Match(
        id: 'match-1',
        organizerId: 'organizer-1',
        status: MatchStatus.settled,
        scoreTeamA: 2,
        scoreTeamB: 1,
        tournamentId: 'tournament-1',
        createdAt: DateTime(2026, 7, 13),
      );

      final data = const MvpShareController().buildFromEvent(
        match: match,
        event: event,
      )!;

      expect(data.isGuest, isFalse);
      expect(data.sharePayload?.entityType, ShareEntityType.player);
      expect(data.sharePayload?.entityId, 'player-mvp');
    },
  );
}
