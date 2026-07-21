import '../../domain/entities/guest_team.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_registration.dart';
import '../enums/tournament_registration_mode.dart';
import '../enums/tournament_registration_status.dart';
import '../enums/tournament_enums.dart';

class TournamentRegistrationPolicy {
  const TournamentRegistrationPolicy();

  TournamentRegistrationStatus registeredTeamTargetStatus({
    required TournamentRegistrationMode mode,
    required bool isOrganizer,
  }) {
    return switch (mode) {
      TournamentRegistrationMode.quick || TournamentRegistrationMode.hybrid =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.verified when isOrganizer =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.verified =>
        TournamentRegistrationStatus.pending,
    };
  }

  TournamentRegistrationStatus guestTeamTargetStatus({
    required TournamentRegistrationMode mode,
    required bool isOrganizer,
  }) {
    return switch (mode) {
      TournamentRegistrationMode.quick when isOrganizer =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.quick => TournamentRegistrationStatus.pending,
      TournamentRegistrationMode.hybrid => TournamentRegistrationStatus.pending,
      TournamentRegistrationMode.verified when isOrganizer =>
        TournamentRegistrationStatus.approved,
      TournamentRegistrationMode.verified =>
        TournamentRegistrationStatus.pending,
    };
  }

  void assertRegistrationOpen(
    Tournament tournament, {
    required DateTime currentTime,
    String errorMessage = 'التسجيل في هذه الدورة مغلق حاليًا.',
  }) {
    final deadline = tournament.registrationDeadline;
    if (tournament.status != TournamentStatus.registration ||
        (deadline != null && currentTime.isAfter(deadline))) {
      throw Exception(errorMessage);
    }
  }

  void assertGuestTeamEligible({
    required GuestTeam guestTeam,
    required TournamentRegistrationMode mode,
    required bool isOrganizer,
  }) {
    if (mode == TournamentRegistrationMode.quick && !isOrganizer) {
      throw Exception('الوضع السريع لإضافة الفرق الضيفة مخصص للمنظم فقط.');
    }
    if (mode != TournamentRegistrationMode.verified) return;

    final hasContactName = guestTeam.contactName?.trim().isNotEmpty ?? false;
    final hasContactPhone = guestTeam.contactPhone?.trim().isNotEmpty ?? false;
    if (!hasContactName || !hasContactPhone) {
      throw Exception(
        'الوضع الموثق يتطلب اسم مسؤول التواصل ورقم هاتف صالح للفريق الضيف.',
      );
    }
  }

  void assertCapacityAvailable({
    required Tournament tournament,
    required List<TournamentRegistration> registrations,
    required String registrationId,
    required TournamentRegistrationStatus nextStatus,
  }) {
    if (!_statusConsumesCapacity(nextStatus)) return;

    final activeRegistrations = registrations
        .where((registration) => _statusConsumesCapacity(registration.status))
        .toList(growable: false);
    final pendingReservations = activeRegistrations
        .where(
          (registration) =>
              registration.status == TournamentRegistrationStatus.pending,
        )
        .length;
    final approvedRegistrations = activeRegistrations
        .where(
          (registration) =>
              registration.status == TournamentRegistrationStatus.approved,
        )
        .length;

    var approvedReservedSlots = approvedRegistrations;
    final canonicalApprovedSlots = tournament.activeParticipantCount;
    if (canonicalApprovedSlots != null &&
        canonicalApprovedSlots > approvedReservedSlots) {
      approvedReservedSlots = canonicalApprovedSlots;
    } else if (canonicalApprovedSlots == null &&
        tournament.registeredTeamIds.length > approvedReservedSlots) {
      approvedReservedSlots = tournament.registeredTeamIds.length;
    }

    final reservedSlots = approvedReservedSlots + pendingReservations;
    final currentRegistrationAlreadyReservesSlot = registrations.any(
      (registration) =>
          registration.id == registrationId &&
          _statusConsumesCapacity(registration.status),
    );
    if (!currentRegistrationAlreadyReservesSlot &&
        reservedSlots >= tournament.maxTeams) {
      throw Exception('اكتملت سعة التسجيل لهذه الدورة.');
    }
  }

  bool _statusConsumesCapacity(TournamentRegistrationStatus status) =>
      status == TournamentRegistrationStatus.approved ||
      status == TournamentRegistrationStatus.pending;
}
