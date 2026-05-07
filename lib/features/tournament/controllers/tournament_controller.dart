import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/tournament.dart';
import '../../../services/auth_service.dart';

/// كونترولر الدورة — يدير دورة حياة البطولة الكاملة
class TournamentController extends GetxController {
  final AuthService _authService;
  final TournamentRepositoryImpl _repo;

  TournamentController({
    AuthService? authService,
    TournamentRepositoryImpl? tournamentRepository,
  }) : _authService = authService ?? Get.find<AuthService>(),
       _repo = tournamentRepository ?? TournamentRepositoryImpl();

  // ── State ──
  final RxList<Tournament> liveTournaments = <Tournament>[].obs;
  final RxList<Tournament> myOrganizedTournaments = <Tournament>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

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
    loadLiveTournaments();
    loadMyTournaments();
  }

  void resetSessionState() {
    myOrganizedTournaments.clear();
    isLoading.value = false;
    errorMessage.value = '';
    _clearForm();
  }

  /// تحميل الدورات الجارية
  Future<void> loadLiveTournaments() async {
    try {
      isLoading.value = true;
      liveTournaments.value = await _repo.getLiveTournaments();
    } catch (e) {
      AppLogger.error('TournamentController.loadTournaments', e);
      errorMessage.value = 'فشل تحميل الدورات';
    } finally {
      isLoading.value = false;
    }
  }

  /// تحميل دوراتي (كمنظم)
  Future<void> loadMyTournaments() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    try {
      myOrganizedTournaments.value = await _repo.getOrganizerTournaments(uid);
    } catch (e) {
      AppLogger.error('TournamentController.loadMyTournaments', e);
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
        status: TournamentStatus.registration,
        isFantasyEnabled:
            FeatureFlags.fantasyUiEnabled && isFantasyEnabled.value,
        createdAt: DateTime.now(),
      );

      await _repo.createTournament(tournament);
      myOrganizedTournaments.insert(0, tournament);
      liveTournaments.insert(0, tournament);

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
