import '../../domain/entities/claim_code.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/entities/player.dart';
import '../enums/claim_code_status.dart';
import '../enums/claim_target_type.dart';
import '../enums/guest_claim_status.dart';

class GuestClaimTokenPolicy {
  const GuestClaimTokenPolicy._();

  static void assertTargetType(ClaimCode claim, ClaimTargetType expectedType) {
    if (claim.targetType == expectedType) return;
    if (expectedType == ClaimTargetType.guestPlayer) {
      throw Exception('رابط الاستلام هذا لا يخص لاعبًا ضيفًا.');
    }
    throw Exception('رابط الاستلام هذا لا يخص فريقًا ضيفًا.');
  }

  static bool shouldMarkExpired(ClaimCode claim, DateTime now) =>
      claim.status == ClaimCodeStatus.active && claim.isExpiredAt(now);

  static void assertNotExpired(
    ClaimCode claim,
    DateTime now, {
    required ClaimTargetType targetType,
  }) {
    if (!shouldMarkExpired(claim, now)) return;
    if (targetType == ClaimTargetType.guestTeam) {
      throw Exception('انتهت صلاحية رابط استلام الفريق.');
    }
    throw Exception('انتهت صلاحية رابط الاستلام.');
  }

  static void assertUsableStatus(
    ClaimCode claim, {
    required ClaimTargetType targetType,
    bool allowClaimed = false,
  }) {
    final isUsable =
        claim.status == ClaimCodeStatus.active ||
        (allowClaimed && claim.status == ClaimCodeStatus.claimed);
    if (isUsable) return;
    if (targetType == ClaimTargetType.guestTeam) {
      throw Exception('رابط الاستلام هذا غير صالح الآن.');
    }
    throw Exception('رابط الاستلام هذا غير صالح الآن.');
  }
}

class GuestClaimMergePolicy {
  const GuestClaimMergePolicy._();

  static List<String> mergeUniqueStrings(
    Iterable<String> existing,
    Iterable<String> incoming,
  ) => <String>{...existing, ...incoming}.toList(growable: false);

  static bool hasSameStrings(Iterable<String> left, Iterable<String> right) {
    final leftSet = left.toSet();
    final rightSet = right.toSet();
    return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
  }

  static Player mergePlayerIdentity({
    required Player player,
    required Iterable<String> linkedTeamIds,
    required DateTime now,
  }) {
    return player.copyWith(
      teamIds: linkedTeamIds.toSet().toList(growable: false),
      lastActiveAt: now,
    );
  }

  static GuestPlayer linkGuestPlayer({
    required GuestPlayer guestPlayer,
    required String playerId,
    required DateTime now,
  }) {
    return guestPlayer.copyWith(
      claimStatus: GuestClaimStatus.claimed,
      linkedPlayerId: playerId,
      updatedAt: now,
    );
  }

  static GuestTeam linkGuestTeam({
    required GuestTeam guestTeam,
    required String teamId,
    required DateTime now,
  }) {
    return guestTeam.copyWith(
      claimStatus: GuestClaimStatus.claimed,
      linkedTeamId: teamId,
      updatedAt: now,
    );
  }
}
