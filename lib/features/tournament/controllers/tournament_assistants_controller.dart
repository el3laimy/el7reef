import 'package:get/get.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_assistant.dart';
import '../../../core/enums/tournament_enums.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/tournament_repository_impl.dart';

class TournamentAssistantsController extends GetxController {
  final TournamentRepositoryImpl _repo = TournamentRepositoryImpl();
  final Rx<Tournament?> currentTournament = Rx<Tournament?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  String? get tournamentId => Get.parameters['tournamentId'];

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
      }
    } catch (e) {
      AppLogger.error('TournamentAssistantsController.loadTournament', e);
      errorMessage.value = 'تعذر تحميل بيانات الدورة';
      Get.snackbar('خطأ', 'تعذر تحميل بيانات الدورة');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addAssistant(String userId, TournamentAssistantRole role) async {
    if (currentTournament.value == null) return;
    try {
      isLoading.value = true;
      final tournament = currentTournament.value!;
      
      // التأكد من أن المستخدم ليس موجود بالفعل
      if (tournament.assistants.any((a) => a.userId == userId)) {
        Get.snackbar('مرفوض', 'اللاعب موجود بالفعل كمساعد', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      DateTime? expiresAt;
      if (role == TournamentAssistantRole.emergency) {
        // ميزة البديل الطارئ تنتهي بعد 72 ساعة
        expiresAt = DateTime.now().add(const Duration(hours: 72));
      }

      final newAssistant = TournamentAssistant(
        userId: userId,
        role: role,
        assignedAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      final updatedList = List<TournamentAssistant>.from(tournament.assistants)..add(newAssistant);
      final updatedTournament = tournament.copyWith(assistants: updatedList);

      await _repo.updateTournament(updatedTournament);
      currentTournament.value = updatedTournament;

      Get.back();
      Get.snackbar('تم', 'تم تعيين المساعد بنجاح!', snackPosition: SnackPosition.BOTTOM);
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
      
      final updatedList = tournament.assistants.where((a) => a.userId != userId).toList();
      final updatedTournament = tournament.copyWith(assistants: updatedList);

      await _repo.updateTournament(updatedTournament);
      currentTournament.value = updatedTournament;
      
      Get.snackbar('تم', 'تم الحذف بنجاح', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('TournamentAssistantsController.removeAssistant', e);
      Get.snackbar('خطأ', 'حصلت مشكلة أثناء إزالة المساعد');
    } finally {
      isLoading.value = false;
    }
  }
}
