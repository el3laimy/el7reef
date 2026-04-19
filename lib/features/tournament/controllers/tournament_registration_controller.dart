import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/tournament_registration_status.dart';
import '../../../core/services/tournament_registration_service.dart';
import '../../../domain/entities/guest_team.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_registration.dart';
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../domain/repositories/tournament_registration_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';

class TournamentRegistrationController extends GetxController {
  final AuthSession _authSession;
  final TournamentRepository _tournamentRepository;
  final TournamentRegistrationRepository _registrationRepository;
  final TeamRepository _teamRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TournamentRegistrationService _registrationService;

  TournamentRegistrationController({
    required AuthSession authSession,
    required TournamentRepository tournamentRepository,
    required TournamentRegistrationRepository registrationRepository,
    required TeamRepository teamRepository,
    required GuestTeamRepository guestTeamRepository,
    required TournamentRegistrationService registrationService,
  }) : _authSession = authSession,
       _tournamentRepository = tournamentRepository,
       _registrationRepository = registrationRepository,
       _teamRepository = teamRepository,
       _guestTeamRepository = guestTeamRepository,
       _registrationService = registrationService;

  final searchController = TextEditingController();

  final tournament = Rxn<Tournament>();
  final registrations = <TournamentRegistration>[].obs;
  final myTeams = <Team>[].obs;
  final searchResults = <Team>[].obs;
  final teamLookups = <String, Team>{}.obs;
  final guestTeamLookups = <String, GuestTeam>{}.obs;

  final isLoading = true.obs;
  final isSearching = false.obs;
  final errorMessage = ''.obs;
  final activeParticipantId = RxnString();

  String? get tournamentId => Get.parameters['id'];
  String? get currentUserId => _authSession.currentUserId;
  bool get isAuthenticated =>
      currentUserId != null && currentUserId!.trim().isNotEmpty;
  bool get isOrganizer => tournament.value?.organizerId == currentUserId;

  List<TournamentRegistration> get pendingRegistrations =>
      registrations
          .where(
            (registration) =>
                registration.status == TournamentRegistrationStatus.pending,
          )
          .toList(growable: false)
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

  List<TournamentRegistration> get approvedRegistrations =>
      registrations
          .where(
            (registration) =>
                registration.status == TournamentRegistrationStatus.approved,
          )
          .toList(growable: false)
        ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));

  List<TournamentRegistration> get rejectedRegistrations =>
      registrations
          .where(
            (registration) =>
                registration.status == TournamentRegistrationStatus.rejected,
          )
          .toList(growable: false)
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

  @override
  void onInit() {
    super.onInit();
    loadScreen();
  }

  Future<void> loadScreen() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      errorMessage.value = 'لم يتم تحديد البطولة المطلوبة.';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    searchResults.clear();

    try {
      final loadedTournament = await _tournamentRepository.getTournament(id);
      if (loadedTournament == null) {
        errorMessage.value = 'تعذر العثور على البطولة المطلوبة.';
        tournament.value = null;
        registrations.clear();
        myTeams.clear();
        return;
      }

      tournament.value = loadedTournament;
      final loadedRegistrations = await _registrationRepository
          .getTournamentRegistrations(id);
      registrations.assignAll(loadedRegistrations);
      await _primeParticipantLookups(loadedRegistrations);
      await _loadMyTeams();
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchRegisteredTeams() async {
    final query = searchController.text.trim();
    if (query.length < 2) {
      searchResults.clear();
      return;
    }

    isSearching.value = true;
    try {
      final results = await _teamRepository.searchTeams(query);
      results.sort((left, right) => left.name.compareTo(right.name));
      searchResults.assignAll(results);
    } catch (error) {
      Get.snackbar('خطأ', _normalizeError(error));
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> registerTeam(Team team) async {
    final id = tournamentId;
    final actorId = currentUserId;
    if (id == null || id.isEmpty) {
      Get.snackbar('خطأ', 'لم يتم تحديد البطولة المطلوبة.');
      return;
    }
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar(
        'تسجيل الدخول مطلوب',
        'سجّل الدخول أولًا حتى تتمكن من التسجيل.',
      );
      return;
    }

    activeParticipantId.value = team.id;
    try {
      final result = await _registrationService.registerTeam(
        tournamentId: id,
        teamId: team.id,
        actorId: actorId,
      );
      await loadScreen();
      Get.snackbar('تم', switch (result.outcome) {
        TournamentRegistrationOutcome.approved =>
          'تم تسجيل "${team.name}" في البطولة.',
        TournamentRegistrationOutcome.alreadyApproved =>
          '"${team.name}" مسجل بالفعل في البطولة.',
        _ => 'تم تحديث تسجيل "${team.name}".',
      });
    } catch (error) {
      Get.snackbar('خطأ', _normalizeError(error));
    } finally {
      activeParticipantId.value = null;
    }
  }

  TournamentRegistration? registrationForTeam(String teamId) {
    for (final registration in registrations) {
      if (registration.teamId == teamId) {
        return registration;
      }
    }
    return null;
  }

  Team? teamForRegistration(TournamentRegistration registration) {
    final teamId = registration.teamId;
    if (teamId == null || teamId.isEmpty) {
      return null;
    }
    return teamLookups[teamId];
  }

  GuestTeam? guestTeamForRegistration(TournamentRegistration registration) {
    final guestTeamId = registration.guestTeamId;
    if (guestTeamId == null || guestTeamId.isEmpty) {
      return null;
    }
    return guestTeamLookups[guestTeamId];
  }

  String participantLabel(TournamentRegistration registration) {
    if (registration.teamId != null) {
      return teamForRegistration(registration)?.name ??
          'فريق مسجل (${registration.teamId})';
    }
    return guestTeamForRegistration(registration)?.name ??
        'فريق ضيف (${registration.guestTeamId})';
  }

  String registrationStatusLabel(TournamentRegistration? registration) {
    final status = registration?.status;
    if (status == null) {
      return 'غير مسجل';
    }
    switch (status) {
      case TournamentRegistrationStatus.approved:
        return 'معتمد';
      case TournamentRegistrationStatus.pending:
        return 'بانتظار الاعتماد';
      case TournamentRegistrationStatus.rejected:
        return 'مرفوض';
      case TournamentRegistrationStatus.cancelled:
        return 'ملغي';
    }
  }

  bool isBusyFor(String participantId) =>
      activeParticipantId.value == participantId;

  Future<void> _loadMyTeams() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      myTeams.clear();
      return;
    }

    final loadedTeams = await _teamRepository.getPlayerTeams(userId);
    loadedTeams.sort((left, right) => left.name.compareTo(right.name));
    myTeams.assignAll(loadedTeams);

    for (final team in loadedTeams) {
      teamLookups[team.id] = team;
    }
  }

  Future<void> _primeParticipantLookups(
    List<TournamentRegistration> loadedRegistrations,
  ) async {
    final teamIds = loadedRegistrations
        .map((registration) => registration.teamId)
        .whereType<String>()
        .where((teamId) => teamId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final guestTeamIds = loadedRegistrations
        .map((registration) => registration.guestTeamId)
        .whereType<String>()
        .where((guestTeamId) => guestTeamId.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final loadedTeamsFuture = _teamRepository.getTeamsByIds(teamIds);
    final loadedGuestTeamsFuture = _guestTeamRepository.getGuestTeamsByIds(
      guestTeamIds,
    );
    final results = await Future.wait<dynamic>([
      loadedTeamsFuture,
      loadedGuestTeamsFuture,
    ]);

    final loadedTeams = (results[0] as List<Team>).asMap().map(
      (_, team) => MapEntry(team.id, team),
    );
    final loadedGuestTeams = (results[1] as List<GuestTeam>).asMap().map(
      (_, guestTeam) => MapEntry(guestTeam.id, guestTeam),
    );

    teamLookups.assignAll(loadedTeams);
    guestTeamLookups.assignAll(loadedGuestTeams);
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
