import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_registration_mode.dart';
import 'package:el7reef/core/enums/tournament_registration_status.dart';
import 'package:el7reef/core/services/tournament_registration_policy.dart';
import 'package:el7reef/domain/entities/guest_team.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = TournamentRegistrationPolicy();

  test('registered and guest targets preserve hybrid approval behavior', () {
    expect(
      policy.registeredTeamTargetStatus(
        mode: TournamentRegistrationMode.hybrid,
        isOrganizer: false,
      ),
      TournamentRegistrationStatus.approved,
    );
    expect(
      policy.guestTeamTargetStatus(
        mode: TournamentRegistrationMode.hybrid,
        isOrganizer: false,
      ),
      TournamentRegistrationStatus.pending,
    );
  });

  test('registration validation rejects a passed deadline', () {
    final now = DateTime(2026, 7, 13, 12);
    final tournament = _tournament(
      now: now,
      registrationDeadline: now.subtract(const Duration(minutes: 1)),
    );

    expect(
      () => policy.assertRegistrationOpen(tournament, currentTime: now),
      throwsA(isA<Exception>()),
    );
  });

  test('verified guest registration requires contact identity', () {
    final now = DateTime(2026, 7, 13, 12);
    final guestTeam = GuestTeam(
      id: 'guest-team-1',
      name: 'الضيوف',
      normalizedName: 'الضيوف',
      creatorId: 'organizer-1',
      createdAt: now,
      updatedAt: now,
    );

    expect(
      () => policy.assertGuestTeamEligible(
        guestTeam: guestTeam,
        mode: TournamentRegistrationMode.verified,
        isOrganizer: true,
      ),
      throwsA(isA<Exception>()),
    );
  });
}

Tournament _tournament({
  required DateTime now,
  DateTime? registrationDeadline,
}) {
  return Tournament(
    id: 'tournament-1',
    organizerId: 'organizer-1',
    name: 'دورة',
    format: TournamentFormat.groupsThenKnockout,
    teamSize: TournamentTeamSize.fiveVsFive,
    maxTeams: 8,
    status: TournamentStatus.registration,
    registrationDeadline: registrationDeadline,
    createdAt: now,
  );
}
