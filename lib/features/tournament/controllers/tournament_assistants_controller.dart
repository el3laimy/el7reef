import 'package:get/get.dart';
import '../../../data/repositories/tournament_assistant_permission_repository_impl.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_assistant_permission.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/tournament_repository_impl.dart';

class TournamentAssistantsController extends GetxController {
  final TournamentRepositoryImpl _repo;
  final TournamentAssistantPermissionRepositoryImpl _assistantRepo;

  TournamentAssistantsController({
    TournamentRepositoryImpl? tournamentRepository,
    TournamentAssistantPermissionRepositoryImpl? assistantRepository,
  })  : _repo = tournamentRepository ?? TournamentRepositoryImpl(),
        _assistantRepo =
            assistantRepository ?? TournamentAssistantPermissionRepositoryImpl();

  final Rx<Tournament?> currentTournament = Rx<Tournament?>(null);
  final RxList<TournamentAssistantPermission> assistants =
      <TournamentAssistantPermission>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  String? get tournamentId =>
      Get.parameters['tournamentId'] ?? Get.parameters['id'];

  @override
  void onInit() {
    super.onInit();
    final id = tournamentId;
    if (id != null && id.isNotEmpty) {
      loadTournament(id);
    } else {
      errorMessage.value = 'لم يتم تحديد الدورة';
    }
  }

  Future<void> loadTournament(String tournamentId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      currentTournament.value = await _repo.getTournament(tournamentId);
      if (currentTournament.value == null) {
        errorMessage.value = 'تعذر العثور على الدورة';
        assistants.clear();
      } else {
        assistants.value =
            await _assistantRepo.listTournamentAssistants(tournamentId);
      }
    } catch (e) {
      AppLogger.error('TournamentAssistantsController.loadTournament', e);
      errorMessage.value = 'تعذر تحميل بيانات الدورة';
      Get.snackbar('خطأ', 'تعذر تحميل بيانات الدورة');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addAssistant(
    String userId,
    TournamentAssistantPermissionPreset preset,
  ) async {
    if (currentTournament.value == null) return;
    final tournament = currentTournament.value!;
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      Get.snackbar('خطأ', 'أدخل معرف المستخدم أولًا.');
      return;
    }
    if (normalizedUserId == tournament.organizerId) {
      Get.snackbar('مرفوض', 'المنظم لا يحتاج إضافته كمساعد.');
      return;
    }
    try {
      isLoading.value = true;

      final existing = await _assistantRepo.getAssistantPermission(
        tournament.id,
        normalizedUserId,
      );
      if (existing != null) {
        Get.snackbar(
          'مرفوض',
          existing.isActive
              ? 'اللاعب موجود بالفعل كمساعد'
              : 'هذا المساعد تم إلغاؤه سابقًا. أعد تفعيله من نسخة الإدارة المتقدمة لاحقًا.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final now = DateTime.now();
      final permission = _permissionForPreset(
        tournamentId: tournament.id,
        userId: normalizedUserId,
        addedBy: tournament.organizerId,
        preset: preset,
        now: now,
      );
      await _assistantRepo.createAssistantPermission(permission);
      assistants.value = await _assistantRepo.listTournamentAssistants(
        tournament.id,
      );

      Get.back();
      Get.snackbar(
        'تم',
        'تم تعيين المساعد بنجاح!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'حصلت مشكلة أثناء إضافة المساعد');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeAssistant(String userId) async {
    if (currentTournament.value == null) return;
    try {
      isLoading.value = true;
      final tournament = currentTournament.value!;
      await _assistantRepo.revokeAssistant(
        tournamentId: tournament.id,
        userId: userId,
        revokedAt: DateTime.now(),
      );
      assistants.value = await _assistantRepo.listTournamentAssistants(
        tournament.id,
      );

      Get.snackbar('تم', 'تم الحذف بنجاح', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('TournamentAssistantsController.removeAssistant', e);
      Get.snackbar('خطأ', 'حصلت مشكلة أثناء إزالة المساعد');
    } finally {
      isLoading.value = false;
    }
  }

  TournamentAssistantPermission _permissionForPreset({
    required String tournamentId,
    required String userId,
    required String addedBy,
    required TournamentAssistantPermissionPreset preset,
    required DateTime now,
  }) {
    return switch (preset) {
      TournamentAssistantPermissionPreset.resultsAssistant =>
        TournamentAssistantPermission.resultsAssistant(
          tournamentId: tournamentId,
          userId: userId,
          addedBy: addedBy,
          createdAt: now,
        ),
      TournamentAssistantPermissionPreset.matchdayAssistant =>
        TournamentAssistantPermission.matchdayAssistant(
          tournamentId: tournamentId,
          userId: userId,
          addedBy: addedBy,
          createdAt: now,
        ),
      TournamentAssistantPermissionPreset.scoreApprover =>
        TournamentAssistantPermission.scoreApprover(
          tournamentId: tournamentId,
          userId: userId,
          addedBy: addedBy,
          createdAt: now,
        ),
      TournamentAssistantPermissionPreset.customLimited =>
        TournamentAssistantPermission.customLimited(
          tournamentId: tournamentId,
          userId: userId,
          addedBy: addedBy,
          permissions: {
            for (final key in TournamentAssistantPermissionKey.values)
              key: key == TournamentAssistantPermissionKey.canViewMatchday,
          },
          createdAt: now,
        ),
    };
  }
}
