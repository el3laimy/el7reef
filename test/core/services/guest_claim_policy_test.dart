import 'package:el7reef/core/enums/guest_claim_status.dart';
import 'package:el7reef/core/services/guest_claim_policy.dart';
import 'package:el7reef/domain/entities/guest_player.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge policy keeps unique team ids and refreshes player activity', () {
    final now = DateTime(2026, 7, 13, 12);
    final player = Player(
      id: 'player-1',
      name: 'لاعب',
      teamIds: const ['team-a'],
      createdAt: now.subtract(const Duration(days: 10)),
      lastActiveAt: now.subtract(const Duration(days: 1)),
    );

    final merged = GuestClaimMergePolicy.mergePlayerIdentity(
      player: player,
      linkedTeamIds: const ['team-a', 'team-b', 'team-b'],
      now: now,
    );

    expect(merged.teamIds, ['team-a', 'team-b']);
    expect(merged.lastActiveAt, now);
  });

  test('merge policy preserves guest identity while linking the account', () {
    final now = DateTime(2026, 7, 13, 12);
    final guest = GuestPlayer(
      id: 'guest-1',
      displayName: 'ضيف',
      normalizedName: 'ضيف',
      createdBy: 'organizer-1',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 1)),
    );

    final claimed = GuestClaimMergePolicy.linkGuestPlayer(
      guestPlayer: guest,
      playerId: 'player-1',
      now: now,
    );

    expect(claimed.id, 'guest-1');
    expect(claimed.claimStatus, GuestClaimStatus.claimed);
    expect(claimed.linkedPlayerId, 'player-1');
    expect(claimed.updatedAt, now);
  });
}
