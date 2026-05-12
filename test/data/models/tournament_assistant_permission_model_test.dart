import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/data/models/tournament_assistant_permission_model.dart';
import 'package:el7reef/domain/entities/tournament_assistant_permission.dart';

void main() {
  group('TournamentAssistantPermissionModel', () {
    final createdAt = DateTime(2026, 5, 8, 18);

    test('serializes and deserializes all V1 presets', () {
      final assistants = [
        TournamentAssistantPermission.resultsAssistant(
          tournamentId: 'tournament-1',
          userId: 'assistant-results',
          addedBy: 'organizer-1',
          createdAt: createdAt,
        ),
        TournamentAssistantPermission.matchdayAssistant(
          tournamentId: 'tournament-1',
          userId: 'assistant-matchday',
          addedBy: 'organizer-1',
          createdAt: createdAt,
        ),
        TournamentAssistantPermission.scoreApprover(
          tournamentId: 'tournament-1',
          userId: 'assistant-approver',
          addedBy: 'organizer-1',
          createdAt: createdAt,
        ),
        TournamentAssistantPermission.customLimited(
          tournamentId: 'tournament-1',
          userId: 'assistant-custom',
          addedBy: 'organizer-1',
          permissions: const {
            TournamentAssistantPermissionKey.canViewMatchday: true,
            TournamentAssistantPermissionKey.canApproveScore: true,
          },
          createdAt: createdAt,
        ),
      ];

      for (final assistant in assistants) {
        final model = TournamentAssistantPermissionModel.fromEntity(assistant);
        final json = model.toJson();
        final parsed = TournamentAssistantPermissionModel.fromJson(
          json,
          assistant.userId,
        ).toEntity();

        expect(json['preset'], assistant.preset.name);
        expect(json['status'], 'active');
        expect(json['createdAt'], createdAt.millisecondsSinceEpoch);
        expect(
          (json['permissions'] as Map<String, bool>).keys,
          containsAll(
            TournamentAssistantPermissionKey.values.map((entry) => entry.name),
          ),
        );
        expect(parsed.userId, assistant.userId);
        expect(parsed.preset, assistant.preset);
        expect(parsed.createdAt, createdAt);
      }
    });

    test('hasPermission respects active status', () {
      final assistant = TournamentAssistantPermission.resultsAssistant(
        tournamentId: 'tournament-1',
        userId: 'assistant-1',
        addedBy: 'organizer-1',
        createdAt: createdAt,
      );
      final revoked = assistant.copyWith(
        status: TournamentAssistantPermissionStatus.revoked,
        revokedAt: createdAt.add(const Duration(hours: 1)),
      );

      expect(
        assistant.hasPermission(
          TournamentAssistantPermissionKey.canSubmitScore,
        ),
        isTrue,
      );
      expect(
        assistant.hasPermission(
          TournamentAssistantPermissionKey.canApproveScore,
        ),
        isFalse,
      );
      expect(revoked.isActive, isFalse);
      expect(
        revoked.hasPermission(TournamentAssistantPermissionKey.canSubmitScore),
        isFalse,
      );
    });

    test('structural permission keys cannot appear through model output', () {
      final assistant = TournamentAssistantPermission.customLimited(
        tournamentId: 'tournament-1',
        userId: 'assistant-1',
        addedBy: 'organizer-1',
        permissions: const {
          TournamentAssistantPermissionKey.canViewMatchday: true,
        },
        createdAt: createdAt,
      );
      final json = TournamentAssistantPermissionModel.fromEntity(
        assistant,
      ).toJson();
      final permissions = json['permissions'] as Map<String, bool>;
      final parsed = TournamentAssistantPermissionModel.fromJson({
        ...json,
        'permissions': {
          ...permissions,
          'canGenerateFixtures': true,
          'canManageParticipants': true,
        },
      }, assistant.userId).toEntity();

      expect(permissions.keys, isNot(contains('canGenerateFixtures')));
      expect(permissions.keys, isNot(contains('canManageParticipants')));
      expect(
        parsed.permissions.length,
        TournamentAssistantPermissionKey.values.length,
      );
      expect(
        parsed.permissions.containsKey(
          TournamentAssistantPermissionKey.canViewMatchday,
        ),
        isTrue,
      );
    });
  });
}
