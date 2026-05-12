import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/match_attendance_status.dart';
import '../../core/enums/match_check_in_status.dart';
import '../../core/enums/match_status.dart';
import '../../core/enums/team_member_availability.dart';
import '../../core/enums/team_membership_role.dart';
import '../../core/enums/team_membership_status.dart';
import '../../core/enums/tournament_registration_status.dart';
import '../../core/lineup/formation_library.dart';
import '../../core/lineup/lineup_types.dart';
import '../../data/models/guest_player_model.dart';
import '../../data/models/guest_team_model.dart';
import '../../data/models/match_attendance_model.dart';
import '../../data/models/match_check_in_model.dart';
import '../../data/models/match_lineup_snapshot_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_side_model.dart';
import '../../data/models/match_side_player_model.dart';
import '../../data/models/match_substitution_model.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_membership_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/tournament_model.dart';
import '../../data/models/tournament_registration_model.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/guest_team.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_attendance.dart';
import '../../domain/entities/match_check_in.dart';
import '../../domain/entities/match_lineup_entry.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/entities/match_side.dart';
import '../../domain/entities/match_side_player.dart';
import '../../domain/entities/match_substitution.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/entities/tournament.dart';
import '../../domain/entities/tournament_registration.dart';
import 'team_roster_policy.dart';
import 'tournament_permission_service.dart';

part 'matchday_service_base.dart';
part 'matchday_check_in.dart';
part 'matchday_lineup.dart';
part 'matchday_substitution.dart';

enum MatchdayCheckInOutcome { checkedIn, verified }

class MatchdayCheckInResult {
  final MatchdayCheckInOutcome outcome;
  final MatchCheckIn checkIn;
  final int attendanceCount;

  const MatchdayCheckInResult({
    required this.outcome,
    required this.checkIn,
    required this.attendanceCount,
  });
}

class MatchdayLineupValidationResult {
  final Match match;
  final MatchCheckIn checkIn;
  final int? requiredStarterCount;
  final int eligibleParticipants;
  final List<MatchLineupEntry> starters;
  final List<MatchLineupEntry> bench;

  const MatchdayLineupValidationResult({
    required this.match,
    required this.checkIn,
    required this.requiredStarterCount,
    required this.eligibleParticipants,
    required this.starters,
    required this.bench,
  });
}

enum MatchdayLineupLockOutcome { locked, alreadyLocked }

class MatchdayLineupLockResult {
  final MatchdayLineupLockOutcome outcome;
  final MatchLineupSnapshot snapshot;
  final MatchdayLineupValidationResult validation;

  const MatchdayLineupLockResult({
    required this.outcome,
    required this.snapshot,
    required this.validation,
  });
}

class MatchdaySubstitutionResult {
  final MatchSubstitution substitution;
  final MatchAttendance outgoingAttendance;
  final MatchAttendance incomingAttendance;

  const MatchdaySubstitutionResult({
    required this.substitution,
    required this.outgoingAttendance,
    required this.incomingAttendance,
  });
}

class MatchdayService {
  final _MatchdayCheckInService _checkIn;
  final _MatchdayLineupService _lineup;
  final _MatchdaySubstitutionService _substitution;

  MatchdayService({
    FirebaseFirestore? firestore,
    TournamentPermissionService? tournamentPermissionService,
    TeamRosterPolicy? teamRosterPolicy,
    Uuid? uuid,
  }) : _checkIn = _MatchdayCheckInService(
         firestore: firestore,
         tournamentPermissionService: tournamentPermissionService,
         teamRosterPolicy: teamRosterPolicy,
         uuid: uuid,
       ),
       _lineup = _MatchdayLineupService(
         firestore: firestore,
         tournamentPermissionService: tournamentPermissionService,
         teamRosterPolicy: teamRosterPolicy,
         uuid: uuid,
       ),
       _substitution = _MatchdaySubstitutionService(
         firestore: firestore,
         tournamentPermissionService: tournamentPermissionService,
         teamRosterPolicy: teamRosterPolicy,
         uuid: uuid,
       );

  Future<MatchdayCheckInResult> checkInRegisteredTeam({
    required String matchId,
    required String teamId,
    required String actorId,
    Map<String, MatchAttendanceStatus> membershipStatuses = const {},
    String? notes,
    DateTime? now,
  }) =>
      _checkIn.checkInRegisteredTeam(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        membershipStatuses: membershipStatuses,
        notes: notes,
        now: now,
      );

  Future<MatchdayCheckInResult> checkInGuestTeam({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required Map<String, MatchAttendanceStatus> guestPlayerStatuses,
    String? notes,
    DateTime? now,
  }) =>
      _checkIn.checkInGuestTeam(
        matchId: matchId,
        guestTeamId: guestTeamId,
        actorId: actorId,
        guestPlayerStatuses: guestPlayerStatuses,
        notes: notes,
        now: now,
      );

  Future<MatchdayLineupValidationResult> validateRegisteredTeamLineup({
    required String matchId,
    required String teamId,
    required String actorId,
    required List<String> starterMembershipIds,
    List<String> benchMembershipIds = const [],
    bool allowIncompleteFriendlyLineup = false,
  }) =>
      _lineup.validateRegisteredTeamLineup(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        starterMembershipIds: starterMembershipIds,
        benchMembershipIds: benchMembershipIds,
        allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
      );

  Future<MatchdayLineupValidationResult> validateGuestTeamLineup({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required List<String> starterGuestPlayerIds,
    List<String> benchGuestPlayerIds = const [],
    bool allowIncompleteFriendlyLineup = false,
  }) =>
      _lineup.validateGuestTeamLineup(
        matchId: matchId,
        guestTeamId: guestTeamId,
        actorId: actorId,
        starterGuestPlayerIds: starterGuestPlayerIds,
        benchGuestPlayerIds: benchGuestPlayerIds,
        allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
      );

  Future<MatchdayLineupLockResult> lockRegisteredTeamLineup({
    required String matchId,
    required String teamId,
    required String actorId,
    required List<String> starterMembershipIds,
    List<String> benchMembershipIds = const [],
    bool allowIncompleteFriendlyLineup = false,
    String? formationCode,
    String? formationLabel,
    String? notes,
    List<SlotAssignment> slotAssignments = const [],
    DateTime? now,
  }) =>
      _lineup.lockRegisteredTeamLineup(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        starterMembershipIds: starterMembershipIds,
        benchMembershipIds: benchMembershipIds,
        allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
        formationCode: formationCode,
        formationLabel: formationLabel,
        notes: notes,
        slotAssignments: slotAssignments,
        now: now,
      );

  Future<MatchdayLineupLockResult> lockGuestTeamLineup({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required List<String> starterGuestPlayerIds,
    List<String> benchGuestPlayerIds = const [],
    bool allowIncompleteFriendlyLineup = false,
    String? formationCode,
    String? formationLabel,
    String? notes,
    List<SlotAssignment> slotAssignments = const [],
    DateTime? now,
  }) =>
      _lineup.lockGuestTeamLineup(
        matchId: matchId,
        guestTeamId: guestTeamId,
        actorId: actorId,
        starterGuestPlayerIds: starterGuestPlayerIds,
        benchGuestPlayerIds: benchGuestPlayerIds,
        allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
        formationCode: formationCode,
        formationLabel: formationLabel,
        notes: notes,
        slotAssignments: slotAssignments,
        now: now,
      );

  Future<MatchLineupSnapshot> lockMatchSideLineup({
    required String matchId,
    required String matchSideId,
    required String sideKey,
    required String actorId,
    required List<String> starterMatchSidePlayerIds,
    List<String> benchMatchSidePlayerIds = const [],
    String? formationCode,
    String? formationLabel,
    String? notes,
    List<SlotAssignment> slotAssignments = const [],
    DateTime? now,
  }) =>
      _lineup.lockMatchSideLineup(
        matchId: matchId,
        matchSideId: matchSideId,
        sideKey: sideKey,
        actorId: actorId,
        starterMatchSidePlayerIds: starterMatchSidePlayerIds,
        benchMatchSidePlayerIds: benchMatchSidePlayerIds,
        formationCode: formationCode,
        formationLabel: formationLabel,
        notes: notes,
        slotAssignments: slotAssignments,
        now: now,
      );

  Future<void> unlockLineup({
    required String matchId,
    required String snapshotId,
    required String actorId,
  }) =>
      _lineup.unlockLineup(
        matchId: matchId,
        snapshotId: snapshotId,
        actorId: actorId,
      );

  Future<MatchdaySubstitutionResult> recordRegisteredTeamSubstitution({
    required String matchId,
    required String teamId,
    required String actorId,
    required String outgoingAttendanceId,
    required String incomingAttendanceId,
    required int minute,
    String? notes,
    DateTime? now,
  }) =>
      _substitution.recordRegisteredTeamSubstitution(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        outgoingAttendanceId: outgoingAttendanceId,
        incomingAttendanceId: incomingAttendanceId,
        minute: minute,
        notes: notes,
        now: now,
      );

  Future<MatchdaySubstitutionResult> recordGuestTeamSubstitution({
    required String matchId,
    required String guestTeamId,
    required String actorId,
    required String outgoingAttendanceId,
    required String incomingAttendanceId,
    required int minute,
    String? notes,
    DateTime? now,
  }) =>
      _substitution.recordGuestTeamSubstitution(
        matchId: matchId,
        guestTeamId: guestTeamId,
        actorId: actorId,
        outgoingAttendanceId: outgoingAttendanceId,
        incomingAttendanceId: incomingAttendanceId,
        minute: minute,
        notes: notes,
        now: now,
      );
}
