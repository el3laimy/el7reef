import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/models/match_event_model.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';

void main() {
  group('MatchEventModel', () {
    test('round-trips goal events with embedded participant ref', () {
      final createdAt = DateTime(2026, 5, 3, 18, 15);
      final event = MatchEvent(
        id: 'event-1',
        matchId: 'match-1',
        tournamentId: 'tournament-1',
        eventType: MatchEventType.goal,
        sideKey: 'A',
        actor: const ParticipantRef(
          kind: ParticipantRefKind.matchSidePlayer,
          id: 'msp-1',
          displayName: 'Side Hero',
        ),
        minute: 12,
        createdBy: 'organizer-1',
        createdAt: createdAt,
      );

      final model = MatchEventModel.fromEntity(event);
      final json = model.toJson();
      final parsed = MatchEventModel.fromJson(json, event.id).toEntity();

      expect(json['matchId'], 'match-1');
      expect(json['tournamentId'], 'tournament-1');
      expect(json['eventType'], 'goal');
      expect(json['sideKey'], 'A');
      expect(json['actor']['kind'], 'matchSidePlayer');
      expect(json['minute'], 12);
      expect(json['createdAt'], createdAt.millisecondsSinceEpoch);
      expect(json['status'], 'active');

      expect(parsed.id, event.id);
      expect(parsed.eventType, MatchEventType.goal);
      expect(parsed.actor.kind, ParticipantRefKind.matchSidePlayer);
      expect(parsed.actor.displayName, 'Side Hero');
      expect(parsed.createdAt, createdAt);
      expect(parsed.status, MatchEventStatus.active);
    });

    test('parses mvp and voided status strings', () {
      final parsed = MatchEventModel.fromJson({
        'matchId': 'match-1',
        'eventType': 'mvp',
        'sideKey': 'B',
        'actor': {
          'kind': 'player',
          'id': 'player-1',
          'displayName': 'MVP Player',
        },
        'createdBy': 'organizer-1',
        'createdAt': DateTime(2026, 5, 3).millisecondsSinceEpoch,
        'status': 'voided',
      }, 'event-2').toEntity();

      expect(parsed.eventType, MatchEventType.mvp);
      expect(parsed.status, MatchEventStatus.voided);
      expect(parsed.sideKey, 'B');
      expect(parsed.minute, isNull);
    });
  });
}
