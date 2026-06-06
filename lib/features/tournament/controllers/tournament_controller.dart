import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/utils/app_logger.dart';
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
    loadMyTournaments();
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
    _clearForm();
  }

  /// تحميل البطولات العامة القابلة للاستكشاف
  Future<void> loadDiscoverableTournaments() async {
    try {
      isLoadingDiscoverableTournaments.value = true;
      discoverableTournaments.value = await _repo.getDiscoverableTournaments();
    } catch (e) {
      AppLogger.error('TournamentController.loadDiscoverableTournaments', e);
      errorMessage.value = 'فشل تحميل البطولات العامة';
    } finally {
      isLoadingDiscoverableTournaments.value = false;
    }
  }

  Future<void> loadLiveTournaments() => loadDiscoverableTournaments();

  /// تحميل دوراتي (كمنظم)
  Future<void> loadMyTournaments() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    try {
      isLoadingMyTournaments.value = true;
      final organized = await _repo.getOrganizerTournaments(uid);
      final followed = await _repo.getFollowedTournaments(uid);
      final teams = await _teamRepo.getPlayerTeams(uid);
      final participating = <String, Tournament>{};
      for (final team in teams) {
        final tournaments = await _repo.getPlayerTournaments(team.id);
        for (final tournament in tournaments) {
          participating[tournament.id] = tournament;
        }
      }
      myOrganizedTournaments.value = organized;
      myParticipatingTournaments.value = participating.values.toList(
        growable: false,
      )..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      followedTournaments.value = followed;
    } catch (e) {
      AppLogger.error('TournamentController.loadMyTournaments', e);
    } finally {
      isLoadingMyTournaments.value = false;
    }
  }

  /// إنشاء دورة جديدة
  Future<void> createTournament() async {
    if (!formKey.currentState!.validate()) return;
    final uid = _authService.currentUserId;
    if (uid == null) return;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final tournament = Tournament(
        id: const Uuid().v4(),
        organizerId: uid,
        name: nameController.text.trim(),
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
        isFantasyEnabled:
            FeatureFlags.fantasyUiEnabled && isFantasyEnabled.value,
        createdAt: DateTime.now(),
      );

      await _repo.createTournament(tournament);
      myOrganizedTournaments.insert(0, tournament);
      if (tournament.isDiscoverable) {
        discoverableTournaments.insert(0, tournament);
      }

      _clearForm();
      Get.back();
      Get.snackbar(
        'تم ✅',
        'تم إنشاء الدورة بنجاح!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      errorMessage.value = 'فشل إنشاء الدورة: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _clearForm() {
    nameController.clear();
    descriptionController.clear();
    locationController.clear();
    maxTeamsController.text = '8';
    selectedFormat.value = TournamentFormat.groupsThenKnockout;
    selectedTeamSize.value = TournamentTeamSize.fiveVsFive;
    selectedVisibility.value = TournamentVisibility.public;
    isFantasyEnabled.value = false;
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
