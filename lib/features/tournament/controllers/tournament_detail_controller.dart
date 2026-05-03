import 'package:get/get.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/tournament_repository_impl.dart';
import '../../../core/services/tournament_participant_service.dart';
import '../../../core/services/tournament_top_scorers_resolver.dart';
import '../../../domain/entities/tournament.dart';

class TournamentDetailController extends GetxController {
  final TournamentRepositoryImpl _repository;
  final TournamentParticipantService _participantService;
  final TournamentTopScorersResolver _topScorersResolver;

  TournamentDetailController({
    TournamentRepositoryImpl? repository,
    TournamentParticipantService? participantService,
    TournamentTopScorersResolver? topScorersResolver,
  }) : _repository = repository ?? TournamentRepositoryImpl(),
       _participantService =
           participantService ?? TournamentParticipantService(),
       _topScorersResolver =
           topScorersResolver ?? TournamentTopScorersResolver();

  final Rx<Tournament?> tournament = Rx<Tournament?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString winnerDisplayName = ''.obs;
  final RxList<TournamentTopScorerEntry> topScorers =
      <TournamentTopScorerEntry>[].obs;
  final RxBool isLoadingTopScorers = false.obs;
  final RxString topScorersErrorMessage = ''.obs;

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
        topScorers.clear();
        topScorersErrorMessage.value = '';
      } else {
        await _loadWinnerDisplayName(tournament.value!);
        await loadTopScorers();
      }
    } catch (error) {
      AppLogger.error('TournamentDetailController.loadTournament', error);
      errorMessage.value = 'تعذر تحميل بيانات الدورة';
      winnerDisplayName.value = '';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTopScorers() async {
    final id = tournament.value?.id ?? tournamentId;
    if (id == null || id.isEmpty) {
      topScorers.clear();
      topScorersErrorMessage.value = '';
      return;
    }

    try {
      isLoadingTopScorers.value = true;
      topScorersErrorMessage.value = '';
      topScorers.value = await _topScorersResolver.getTopScorers(id, limit: 5);
    } catch (error) {
      AppLogger.error('TournamentDetailController.loadTopScorers', error);
      topScorers.clear();
      topScorersErrorMessage.value = 'تعذر تحميل هدافي البطولة الآن.';
    } finally {
      isLoadingTopScorers.value = false;
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
