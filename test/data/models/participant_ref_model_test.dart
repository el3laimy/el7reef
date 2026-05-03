import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/models/participant_ref_model.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';

void main() {
  group('ParticipantRefModel', () {
    test('round-trips registered player refs', () {
      const ref = ParticipantRef(
        kind: ParticipantRefKind.player,
        id: 'player-1',
        displayName: 'Registered Hero',
        linkedPlayerId: null,
      );

      final model = ParticipantRefModel.fromEntity(ref);
      final json = model.toJson();
      final parsed = ParticipantRefModel.fromJson(json).toEntity();

      expect(json['kind'], 'player');
      expect(json['id'], 'player-1');
      expect(json['displayName'], 'Registered Hero');
      expect(json['linkedPlayerId'], isNull);
      expect(parsed.kind, ParticipantRefKind.player);
      expect(parsed.id, ref.id);
      expect(parsed.displayName, ref.displayName);
      expect(parsed.linkedPlayerId, isNull);
    });

    test('round-trips guest player refs with claim linkage', () {
      const ref = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-player-1',
        displayName: 'Guest Hero',
        linkedPlayerId: 'player-9',
      );

      final model = ParticipantRefModel.fromEntity(ref);
      final json = model.toJson();
      final parsed = ParticipantRefModel.fromJson(json).toEntity();

      expect(json['kind'], 'guestPlayer');
      expect(json['id'], 'guest-player-1');
      expect(json['displayName'], 'Guest Hero');
      expect(json['linkedPlayerId'], 'player-9');
      expect(parsed.kind, ParticipantRefKind.guestPlayer);
      expect(parsed.id, ref.id);
      expect(parsed.displayName, ref.displayName);
      expect(parsed.linkedPlayerId, ref.linkedPlayerId);
    });

    test('defaults unknown kind safely to registered player', () {
      final parsed = ParticipantRefModel.fromJson(const {
        'kind': 'unknown',
        'id': 'player-1',
        'displayName': 'Known Player',
      }).toEntity();

      expect(parsed.kind, ParticipantRefKind.player);
      expect(parsed.id, 'player-1');
      expect(parsed.displayName, 'Known Player');
    });
  });
}
