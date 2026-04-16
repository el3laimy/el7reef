import '../../core/enums/team_membership_role.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_membership.dart';

class TeamRosterPolicy {
  const TeamRosterPolicy();

  bool canManageRoster({
    required Team team,
    required String actorId,
  }) {
    return team.ownerId == actorId || team.viceCaptainIds.contains(actorId);
  }

  String? validateRegisteredMembership({
    required Team team,
    required List<TeamMembership> existingMemberships,
    required String playerId,
    required TeamMembershipRole role,
  }) {
    final activeMatch = existingMemberships.where((membership) =>
        membership.playerId == playerId && membership.isActive);
    if (activeMatch.isNotEmpty) {
      return 'اللاعب موجود بالفعل داخل قائمة الفريق.';
    }

    if (role == TeamMembershipRole.owner && playerId != team.ownerId) {
      return 'لا يمكن تعيين دور المالك إلا لمالك الفريق الحالي.';
    }

    if (role == TeamMembershipRole.viceCaptain && playerId == team.ownerId) {
      return 'مالك الفريق لا يحتاج لدور نائب القائد.';
    }

    return null;
  }

  String? validateGuestMembership({
    required List<TeamMembership> existingMemberships,
    required String guestPlayerId,
    required TeamMembershipRole role,
  }) {
    final activeMatch = existingMemberships.where((membership) =>
        membership.guestPlayerId == guestPlayerId && membership.isActive);
    if (activeMatch.isNotEmpty) {
      return 'اللاعب الضيف موجود بالفعل داخل قائمة الفريق.';
    }

    if (role != TeamMembershipRole.player) {
      return 'اللاعب الضيف لا يمكن منحه دوراً إدارياً قبل إتمام الـ claim.';
    }

    return null;
  }

  String? validateReplacement({
    required TeamMembership guestMembership,
    required List<TeamMembership> existingMemberships,
    required String playerId,
  }) {
    if (!guestMembership.isGuest) {
      return 'العضوية المحددة ليست عضوية لاعب ضيف.';
    }

    final activePlayerMatch = existingMemberships.where((membership) =>
        membership.playerId == playerId && membership.isActive);
    if (activePlayerMatch.isNotEmpty) {
      return 'اللاعب المسجل موجود بالفعل داخل قائمة الفريق.';
    }

    return null;
  }

  String? validateRemoval({
    required Team team,
    required TeamMembership membership,
  }) {
    if (membership.playerId == team.ownerId ||
        membership.role == TeamMembershipRole.owner) {
      return 'لا يمكن إزالة مالك الفريق من خلال إدارة القائمة.';
    }

    return null;
  }

  String? validateRoleChange({
    required Team team,
    required TeamMembership membership,
    required TeamMembershipRole newRole,
  }) {
    if (membership.role == newRole) {
      return null;
    }

    if (membership.playerId == team.ownerId ||
        membership.role == TeamMembershipRole.owner) {
      return 'لا يمكن تغيير دور مالك الفريق.';
    }

    if (newRole == TeamMembershipRole.owner) {
      return 'نقل ملكية الفريق له تدفق منفصل ولا يتم من شاشة القائمة.';
    }

    if (membership.isGuest && newRole != TeamMembershipRole.player) {
      return 'اللاعب الضيف لا يمكن منحه دوراً إدارياً قبل إتمام الـ claim.';
    }

    return null;
  }
}
