import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../domain/entities/tournament.dart';

class TournamentDetailController extends GetxController {
  final TournamentRepositoryImpl _repository = TournamentRepositoryImpl();

  final Rx<Tournament?> tournament = Rx<Tournament?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  String? get tournamentId => Get.parameters['id'];

  @override
  void onInit() {
    super.onInit();
    loadTournament();
  }

  Future<void> loadTournament() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      errorMessage.value = 'لم يتم تحديد الدورة';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      tournament.value = await _repository.getTournament(id);
      if (tournament.value == null) {
        errorMessage.value = 'تعذر العثور على الدورة';
      }
    } catch (error) {
      AppLogger.error('TournamentDetailController.loadTournament', error);
      errorMessage.value = 'تعذر تحميل بيانات الدورة';
    } finally {
      isLoading.value = false;
    }
  }
}
