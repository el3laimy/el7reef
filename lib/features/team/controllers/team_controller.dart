import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/auth/auth_service.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../domain/entities/team.dart';

/// كونترولر الفريق — إنشاء فرق وإدارتها
class TeamController extends GetxController {
  final AuthService _authService;
  final TeamRepositoryImpl _teamRepo;

  TeamController({AuthService? authService, TeamRepositoryImpl? teamRepository})
    : _authService = authService ?? Get.find<AuthService>(),
      _teamRepo = teamRepository ?? TeamRepositoryImpl();

  final RxList<Team> myTeams = <Team>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  Worker? _authWorker;

  // ── Form ──
  final teamNameController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    _authWorker = ever(_authService.currentPlayer, (player) {
      if (player == null) {
        resetSessionState();
      } else {
        loadMyTeams();
      }
    });
    loadMyTeams();
  }

  void resetSessionState() {
    myTeams.clear();
    isLoading.value = false;
    errorMessage.value = '';
    teamNameController.clear();
  }

  /// تحميل فرقي
  Future<void> loadMyTeams() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;
    try {
      isLoading.value = true;
      myTeams.value = await _teamRepo.getPlayerTeams(userId);
    } catch (e) {
      errorMessage.value = 'فشل تحميل الفرق';
    } finally {
      isLoading.value = false;
    }
  }

  /// إنشاء فريق جديد
  Future<void> createTeam() async {
    if (!formKey.currentState!.validate()) return;
    final userId = _authService.currentUserId;
    if (userId == null) return;

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final team = Team(
        id: const Uuid().v4(),
        name: teamNameController.text.trim(),
        ownerId: userId,
        playerIds: [userId],
        createdAt: DateTime.now(),
      );

      await _teamRepo.createTeam(team);
      myTeams.add(team);
      teamNameController.clear();
      Get.back();
      Get.snackbar(
        'تم ✅',
        'تم إنشاء الفريق "${team.name}" بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      errorMessage.value = 'فشل إنشاء الفريق';
    } finally {
      isLoading.value = false;
    }
  }

  String? validateTeamName(String? value) {
    if (value == null || value.trim().isEmpty) return 'اسم الفريق مطلوب';
    if (value.trim().length < 3) return 'الاسم لازم يكون 3 حروف على الأقل';
    return null;
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    teamNameController.dispose();
    super.onClose();
  }
}
