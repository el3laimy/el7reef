import 'package:get/get.dart';

import '../../../core/auth/auth_service_session.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/services/matchday_service.dart';
import '../../../core/services/tournament_permission_service.dart';
import '../../../data/repositories/guest_player_repository_impl.dart';
import '../../../data/repositories/guest_team_repository_impl.dart';
import '../../../data/repositories/match_attendance_repository_impl.dart';
import '../../../data/repositories/match_check_in_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/match_substitution_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_membership_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/tournament_registration_repository_impl.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../controllers/matchday_controller.dart';

class MatchdayBinding extends Bindings {
  @override
  void dependencies() {
    final matchId = Get.parameters['id'];
    if (matchId == null || matchId.isEmpty) {
      throw StateError('matchId is required for matchday flows');
    }

    if (!Get.isRegistered<MatchRepositoryImpl>()) {
      Get.lazyPut<MatchRepositoryImpl>(() => MatchRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentRepositoryImpl>()) {
      Get.lazyPut<TournamentRepositoryImpl>(() => TournamentRepositoryImpl());
    }
    if (!Get.isRegistered<TournamentRegistrationRepositoryImpl>()) {
      Get.lazyPut<TournamentRegistrationRepositoryImpl>(
        () => TournamentRegistrationRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TeamRepositoryImpl>()) {
      Get.lazyPut<TeamRepositoryImpl>(() => TeamRepositoryImpl());
    }
    if (!Get.isRegistered<GuestTeamRepositoryImpl>()) {
      Get.lazyPut<GuestTeamRepositoryImpl>(() => GuestTeamRepositoryImpl());
    }
    if (!Get.isRegistered<TeamMembershipRepositoryImpl>()) {
      Get.lazyPut<TeamMembershipRepositoryImpl>(
        () => TeamMembershipRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<PlayerRepositoryImpl>()) {
      Get.lazyPut<PlayerRepositoryImpl>(() => PlayerRepositoryImpl());
    }
    if (!Get.isRegistered<GuestPlayerRepositoryImpl>()) {
      Get.lazyPut<GuestPlayerRepositoryImpl>(() => GuestPlayerRepositoryImpl());
    }
    if (!Get.isRegistered<MatchCheckInRepositoryImpl>()) {
      Get.lazyPut<MatchCheckInRepositoryImpl>(
        () => MatchCheckInRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<MatchAttendanceRepositoryImpl>()) {
      Get.lazyPut<MatchAttendanceRepositoryImpl>(
        () => MatchAttendanceRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<MatchLineupSnapshotRepositoryImpl>()) {
      Get.lazyPut<MatchLineupSnapshotRepositoryImpl>(
        () => MatchLineupSnapshotRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<MatchSideRepositoryImpl>()) {
      Get.lazyPut<MatchSideRepositoryImpl>(() => MatchSideRepositoryImpl());
    }
    if (!Get.isRegistered<MatchSubstitutionRepositoryImpl>()) {
      Get.lazyPut<MatchSubstitutionRepositoryImpl>(
        () => MatchSubstitutionRepositoryImpl(),
      );
    }
    if (!Get.isRegistered<TournamentPermissionService>()) {
      Get.lazyPut<TournamentPermissionService>(
        () => TournamentPermissionService(),
      );
    }
    if (!Get.isRegistered<MatchdayService>()) {
      Get.lazyPut<MatchdayService>(() => MatchdayService());
    }

    final authSession = Get.isRegistered<AuthSession>()
        ? Get.find<AuthSession>()
        : Get.isRegistered<AuthService>()
        ? AuthServiceSession(Get.find<AuthService>())
        : const _AnonymousAuthSession();

    Get.lazyPut<MatchdayController>(
      () => MatchdayController(
        matchId: matchId,
        authSession: authSession,
        matchdayService: Get.find<MatchdayService>(),
        matchRepository: Get.find<MatchRepositoryImpl>(),
        tournamentRepository: Get.find<TournamentRepositoryImpl>(),
        registrationRepository:
            Get.find<TournamentRegistrationRepositoryImpl>(),
        teamRepository: Get.find<TeamRepositoryImpl>(),
        guestTeamRepository: Get.find<GuestTeamRepositoryImpl>(),
        membershipRepository: Get.find<TeamMembershipRepositoryImpl>(),
        playerRepository: Get.find<PlayerRepositoryImpl>(),
        guestPlayerRepository: Get.find<GuestPlayerRepositoryImpl>(),
        checkInRepository: Get.find<MatchCheckInRepositoryImpl>(),
        attendanceRepository: Get.find<MatchAttendanceRepositoryImpl>(),
        snapshotRepository: Get.find<MatchLineupSnapshotRepositoryImpl>(),
        matchSideRepository: Get.find<MatchSideRepositoryImpl>(),
        substitutionRepository: Get.find<MatchSubstitutionRepositoryImpl>(),
        tournamentPermissionService: Get.find<TournamentPermissionService>(),
      ),
    );
  }
}

class _AnonymousAuthSession implements AuthSession {
  const _AnonymousAuthSession();

  @override
  get currentPlayer => null;

  @override
  String? get currentUserId => null;
}
