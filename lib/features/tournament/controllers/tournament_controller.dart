import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../../app/routes/app_routes.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../domain/entities/tournament.dart';
import '../../../core/auth/auth_service.dart';

/// كونترولر الدورة — يدير دورة حياة البطولة الكاملة
class TournamentController extends GetxController {
  final AuthService _authService;
  final TournamentRepositoryImpl _repo;
  final TeamRepositoryImpl _teamRepo;

  TournamentController({
    AuthService? authService,
    TournamentRepositoryImpl? tournamentRepository,
    TeamRepositoryImpl? teamRepository,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _repo = tournamentRepository ?? TournamentRepositoryImpl(),
       _teamRepo = teamRepository ?? TeamRepositoryImpl();

  // ── State ──
  final RxList<Tournament> discoverableTournaments = <Tournament>[].obs;
  final RxList<Tournament> myOrganizedTournaments = <Tournament>[].obs;
  final RxList<Tournament> myParticipatingTournaments = <Tournament>[].obs;
  final RxList<Tournament> followedTournaments = <Tournament>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMyTournaments = false.obs;
  final RxBool isLoadingDiscoverableTournaments = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString createTournamentErrorMessage = ''.obs;
  final RxString myTournamentsErrorMessage = ''.obs;
  final RxString followedTournamentsErrorMessage = ''.obs;

  /// Backward-compatible alias for older callers. Prefer discoverableTournaments.
  RxList<Tournament> get liveTournaments => discoverableTournaments;

  List<Tournament> get myTournaments {
    final byId = <String, Tournament>{};
    for (final tournament in myOrganizedTournaments) {
      byId[tournament.id] = tournament;
    }
    for (final tournament in myParticipatingTournaments) {
      byId.putIfAbsent(tournament.id, () => tournament);
    }
    final list = byId.values.toList(growable: false);
    list.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return list;
  }

  List<Tournament> get followedOnlyTournaments {
    final myIds = myTournaments.map((tournament) => tournament.id).toSet();
    final list = followedTournaments
        .where((tournament) => !myIds.contains(tournament.id))
        .toList(growable: false);
    list.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return list;
  }

  // ── Create Form ──
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final maxTeamsController = TextEditingController(text: '8');
  final formKey = GlobalKey<FormState>();

  final Rx<TournamentFormat> selectedFormat =
      TournamentFormat.groupsThenKnockout.obs;
  final Rx<TournamentTeamSize> selectedTeamSize =
      TournamentTeamSize.fiveVsFive.obs;
  final Rx<TournamentVisibility> selectedVisibility =
      TournamentVisibility.public.obs;
  final RxnString selectedLogoUrl = RxnString();
  final RxBool isFantasyEnabled = false.obs;
  Worker? _authWorker;

  @override
  void onInit() {
    super.onInit();
    _authWorker = ever(_authService.currentPlayer, (player) {
      if (player == null) {
        resetSessionState();
      } else {
        loadMyTournaments();
      }
    });
    if (_authService.currentPlayer.value != null) {
      loadMyTournaments();
    }
  }

  void resetSessionState() {
    myOrganizedTournaments.clear();
    myParticipatingTournaments.clear();
    followedTournaments.clear();
    discoverableTournaments.clear();
    isLoading.value = false;
    isLoadingMyTournaments.value = false;
    isLoadingDiscoverableTournaments.value = false;
    errorMessage.value = '';
    createTournamentErrorMessage.value = '';
    myTournamentsErrorMessage.value = '';
    followedTournamentsErrorMessage.value = '';
    _clearForm();
  }

  /// تحميل البطولات العامة القابلة للاستكشاف
  Future<void> loadDiscoverableTournaments() async {
    try {
      isLoadingDiscoverableTournaments.value = true;
      errorMessage.value = '';
      discoverableTournaments.assignAll(
        await _repo.getDiscoverableTournaments(),
      );
    } catch (e) {
      AppLogger.error('TournamentController.loadDiscoverableTournaments', e);
      final reason = e is AppException
          ? e.message
          : 'تعذر إتمام العملية حالياً. حاول مرة أخرى.';
      errorMessage.value = 'تعذر تحميل البطولات المفتوحة. $reason';
    } finally {
      isLoadingDiscoverableTournaments.value = false;
    }
  }

  Future<void> loadLiveTournaments() => loadDiscoverableTournaments();

  /// تحميل دوراتي (كمنظم)
  Future<void> loadMyTournaments() async {
    final uid = _authService.currentUserId;
    if (uid == null || _authService.currentPlayer.value == null) return;
    if (isLoadingMyTournaments.value) return;

    isLoadingMyTournaments.value = true;
    myTournamentsErrorMessage.value = '';
    followedTournamentsErrorMessage.value = '';
    var organizedLoadFailed = false;
    var participatingLoadFailed = false;

    try {
      final organized = await _repo.getOrganizerTournaments(uid);
      myOrganizedTournaments.assignAll(organized);
    } catch (e) {
      organizedLoadFailed = true;
      AppLogger.error('TournamentController.loadOrganizedTournaments', e);
    }

    try {
      final teams = await _teamRepo.getPlayerTeams(uid);
      final participating = <String, Tournament>{};
      final tournamentsByTeam = await Future.wait(
        teams.map((team) => _repo.getPlayerTournaments(team.id)),
      );
      for (final tournaments in tournamentsByTeam) {
        for (final tournament in tournaments) {
          participating[tournament.id] = tournament;
        }
      }
      final sortedParticipating = participating.values.toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      myParticipatingTournaments.assignAll(sortedParticipating);
    } catch (e) {
      participatingLoadFailed = true;
      AppLogger.error('TournamentController.loadParticipatingTournaments', e);
    }

    if (organizedLoadFailed && participatingLoadFailed) {
      myTournamentsErrorMessage.value = 'تعذر تحميل بطولاتك حالياً.';
    } else if (organizedLoadFailed) {
      myTournamentsErrorMessage.value =
          'تعذر تحديث البطولات التي تنظمها حالياً.';
    } else if (participatingLoadFailed) {
      myTournamentsErrorMessage.value = myOrganizedTournaments.isEmpty
          ? 'تعذر تحديث بطولات فرقك حالياً.'
          : 'ظهرت بطولاتك المنظمة، لكن تعذر تحديث بطولات فرقك.';
    }

    try {
      followedTournaments.assignAll(await _repo.getFollowedTournaments(uid));
    } catch (e) {
      AppLogger.error('TournamentController.loadFollowedTournaments', e);
      followedTournaments.clear();
      followedTournamentsErrorMessage.value =
          'تعذر تحميل البطولات التي تتابعها حالياً.';
    } finally {
      isLoadingMyTournaments.value = false;
    }
  }

  /// إنشاء دورة جديدة
  Future<void> createTournament() async {
    if (isLoading.value || formKey.currentState?.validate() != true) return;
    final uid = _authService.currentUserId;
    if (uid == null) {
      createTournamentErrorMessage.value = 'سجّل الدخول أولاً لإنشاء بطولة.';
      return;
    }

    isLoading.value = true;
    createTournamentErrorMessage.value = '';
    final tournament = Tournament(
      id: const Uuid().v4(),
      organizerId: uid,
      name: nameController.text.trim(),
      logoUrl: selectedLogoUrl.value,
      description: descriptionController.text.trim().isEmpty
          ? null
          : descriptionController.text.trim(),
      location: locationController.text.trim().isEmpty
          ? null
          : locationController.text.trim(),
      format: selectedFormat.value,
      teamSize: selectedTeamSize.value,
      maxTeams: int.tryParse(maxTeamsController.text) ?? 8,
      visibility: selectedVisibility.value,
      discoverable: selectedVisibility.value == TournamentVisibility.public,
      status: TournamentStatus.registration,
      isFantasyEnabled: false,
      createdAt: DateTime.now(),
    );

    try {
      await _repo.createTournament(tournament);
    } catch (e) {
      AppLogger.error('TournamentController.createTournament', e);
      final reason = e is AppException
          ? e.message
          : 'تعذر إتمام العملية حالياً. حاول مرة أخرى.';
      createTournamentErrorMessage.value = 'فشل إنشاء البطولة. $reason';
      isLoading.value = false;
      return;
    }

    try {
      _putTournamentFirst(myOrganizedTournaments, tournament);
      if (tournament.isDiscoverable) {
        _putTournamentFirst(discoverableTournaments, tournament);
      }
    } catch (e) {
      AppLogger.error('TournamentController.syncCreatedTournament', e);
      await loadMyTournaments();
      if (tournament.isDiscoverable) {
        await loadDiscoverableTournaments();
      }
    }

    _clearForm();
    var dashboardOpened = true;
    try {
      final openedFromCreateIntent =
          Get.currentRoute == AppRoutes.createTournament;
      if (Get.isBottomSheetOpen == true) {
        Get.back();
      }
      final dashboardRoute = AppRoutes.organizerDashboardForTournament(
        tournament.id,
      );
      if (openedFromCreateIntent) {
        Get.offNamed(dashboardRoute);
      } else {
        Get.toNamed(dashboardRoute);
      }
    } catch (e) {
      dashboardOpened = false;
      AppLogger.error('TournamentController.openCreatedTournament', e);
    }
    isLoading.value = false;
    Get.snackbar(
      dashboardOpened ? 'تم ✅' : 'تم الحفظ ✅',
      dashboardOpened
          ? 'تم إنشاء الدورة بنجاح!'
          : 'تم إنشاء الدورة، ويمكنك فتحها من بطولاتك.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _putTournamentFirst(RxList<Tournament> target, Tournament tournament) {
    target.removeWhere((item) => item.id == tournament.id);
    target.insert(0, tournament);
  }

  void _clearForm() {
    nameController.clear();
    descriptionController.clear();
    locationController.clear();
    maxTeamsController.text = '8';
    selectedFormat.value = TournamentFormat.groupsThenKnockout;
    selectedTeamSize.value = TournamentTeamSize.fiveVsFive;
    selectedVisibility.value = TournamentVisibility.public;
    selectedLogoUrl.value = null;
    isFantasyEnabled.value = false;
  }

  void selectLogo(String? logoUrl) {
    selectedLogoUrl.value = logoUrl;
  }

  // ── Validators ──
  String? validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'أدخل اسم الدورة';
    if (v.trim().length < 3) return 'الاسم قصير جداً';
    if (v.trim().length > 50) return 'الاسم طويل جداً';
    return null;
  }

  String? validateMaxTeams(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 2) return 'عدد الفرق يجب أن يكون 2 على الأقل';
    if (n > 64) return 'الحد الأقصى 64 فريق';
    return null;
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    nameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    maxTeamsController.dispose();
    super.onClose();
  }
}
