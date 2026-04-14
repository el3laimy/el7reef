import 'package:get/get.dart';

import '../../../../core/services/fantasy_lifecycle_service.dart';
import '../../../../core/services/fantasy_market_service.dart';
import '../../../../core/services/transfer_engine.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../../domain/entities/fantasy_team.dart';
import '../../../../features/fantasy/presentation/models/fantasy_market_player.dart';
import '../../../../features/fantasy/presentation/models/fantasy_squad_member.dart';
import '../../../../services/auth_service.dart';

class TransferMarketController extends GetxController {
  final String leagueId;
  final FantasyRepositoryImpl _fantasyRepository;
  final FantasyMarketService _marketService;
  final TournamentRepositoryImpl _tournamentRepository;
  final FantasyLifecycleService _lifecycleService;
  final AuthService? _authService;

  late final TransferEngine _transferEngine = TransferEngine(_fantasyRepository);

  TransferMarketController({
    required this.leagueId,
    FantasyRepositoryImpl? fantasyRepository,
    FantasyMarketService? marketService,
    TournamentRepositoryImpl? tournamentRepository,
    FantasyLifecycleService? lifecycleService,
    AuthService? authService,
  })  : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
        _marketService = marketService ??
            (Get.isRegistered<FantasyMarketService>()
                ? Get.find<FantasyMarketService>()
                : FantasyMarketService()),
        _tournamentRepository =
            tournamentRepository ?? TournamentRepositoryImpl(),
        _lifecycleService = lifecycleService ??
            (Get.isRegistered<FantasyLifecycleService>()
                ? Get.find<FantasyLifecycleService>()
                : FantasyLifecycleService(
                    lifecycleRepository:
                        Get.isRegistered<FantasyLifecycleRepositoryImpl>()
                            ? Get.find<FantasyLifecycleRepositoryImpl>()
                            : null,
                    tournamentRepository:
                        tournamentRepository ?? TournamentRepositoryImpl(),
                  )),
        _authService = authService ??
            (Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null);

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString leagueTitle = 'سوق الانتقالات'.obs;
  final Rx<FantasyLeagueLifecycle?> lifecycle = Rx<FantasyLeagueLifecycle?>(null);
  final Rx<FantasyTeam?> team = Rx<FantasyTeam?>(null);
  final RxList<FantasySquadMember> squad = <FantasySquadMember>[].obs;
  final RxList<FantasyMarketPlayer> marketPlayers = <FantasyMarketPlayer>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    final userId = _authService?.currentUserId;
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً.';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      lifecycle.value = await _lifecycleService.resolveLifecycle(leagueId);

      if (leagueId != 'global') {
        final tournament = await _tournamentRepository.getTournament(leagueId);
        if (tournament != null) {
          leagueTitle.value = tournament.name;
        }
      }

      final loadedTeam = await _fantasyRepository.getFantasyTeam(userId);
      if (loadedTeam == null) {
        team.value = null;
        squad.clear();
        return;
      }

      team.value = loadedTeam;
      final slots = await _fantasyRepository.getTeamSlots(loadedTeam.id);
      final market = await _marketService.getMarketPlayers(limit: 120);
      marketPlayers.assignAll(market);
      final marketById = {for (final player in market) player.player.id: player};

      squad.assignAll(
        slots
            .where((slot) => marketById.containsKey(slot.playerId))
            .map(
              (slot) => FantasySquadMember(
                slot: slot,
                marketPlayer: marketById[slot.playerId]!,
              ),
            )
            .toList()
          ..sort((a, b) {
            if (a.slot.isStartingXI != b.slot.isStartingXI) {
              return a.slot.isStartingXI ? -1 : 1;
            }
            return a.slot.benchPriority.compareTo(b.slot.benchPriority);
          }),
      );
    } catch (_) {
      errorMessage.value = 'تعذر تحميل سوق الانتقالات.';
    } finally {
      isLoading.value = false;
    }
  }

  double get budget => team.value?.budget ?? 0;
  int get freeTransfers => team.value?.freeTransfers ?? 0;
  bool get canTransfer => lifecycle.value?.allowsTransfers ?? true;
  bool get wildcardActive =>
      team.value?.activeChips.any((chip) => chip.startsWith('Wildcard')) ?? false;

  Future<void> replacePlayer({
    required FantasySquadMember member,
    required FantasyMarketPlayer replacement,
  }) async {
    if (!canTransfer) {
      Get.snackbar(
        'سوق الانتقالات مغلق',
        'لا يمكن تنفيذ انتقالات في هذه المرحلة من الجولة.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currentTeam = team.value;
    if (currentTeam == null) {
      return;
    }

    final currentValues =
        squad.map((member) => member.marketPlayer.value).toList(growable: false);
    final currentGameweek = await _resolveCurrentGameweek();

    try {
      isSubmitting.value = true;
      await _transferEngine.executeTransfer(
        currentTeam: currentTeam,
        slotToReplace: member.slot,
        playerOutValue: member.marketPlayer.value,
        playerInValue: replacement.value,
        fullTeamValues: currentValues,
        currentGameweek: currentGameweek,
      );
      Get.snackbar(
        'تمت الصفقة',
        'تم استبدال ${member.marketPlayer.displayName} بـ ${replacement.displayName}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      await loadData();
    } catch (error) {
      Get.snackbar(
        'تعذر تنفيذ الصفقة',
        error.toString().replaceAll('Exception:', '').trim(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  List<String> selectedIdsExcluding(String currentPlayerId) {
    return squad
        .map((member) => member.marketPlayer.player.id)
        .where((id) => id != currentPlayerId)
        .toList();
  }

  Future<int> _resolveCurrentGameweek() async {
    final lifecycle = await _lifecycleService.resolveLifecycle(leagueId);
    return lifecycle.currentGameweek;
  }
}
