import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../core/services/tournament_participant_service.dart';
import '../../../domain/entities/tournament.dart';

class TournamentDetailController extends GetxController {
  final TournamentRepositoryImpl _repository;
  final TournamentParticipantService _participantService;

  TournamentDetailController({
    TournamentRepositoryImpl? repository,
    TournamentParticipantService? participantService,
  }) : _repository = repository ?? TournamentRepositoryImpl(),
       _participantService =
           participantService ?? TournamentParticipantService();

  final Rx<Tournament?> tournament = Rx<Tournament?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString winnerDisplayName = ''.obs;

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
        winnerDisplayName.value = '';
      } else {
        await _loadWinnerDisplayName(tournament.value!);
      }
    } catch (error) {
      AppLogger.error('TournamentDetailController.loadTournament', error);
      errorMessage.value = 'تعذر تحميل بيانات الدورة';
      winnerDisplayName.value = '';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadWinnerDisplayName(Tournament tournament) async {
    final winnerParticipantId = tournament.winnerParticipantId;
    if (winnerParticipantId == null || winnerParticipantId.isEmpty) {
      winnerDisplayName.value = '';
      return;
    }

    try {
      final winner = await _participantService.getParticipantById(
        winnerParticipantId,
      );
      winnerDisplayName.value = winner?.displayName ?? winnerParticipantId;
    } catch (error) {
      AppLogger.error(
        'TournamentDetailController._loadWinnerDisplayName',
        error,
      );
      winnerDisplayName.value = winnerParticipantId;
    }
  }
}
