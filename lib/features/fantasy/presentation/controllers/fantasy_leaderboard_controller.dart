import 'package:get/get.dart';

import '../../../../core/auth/auth_session.dart';
import '../../services/fantasy_lifecycle_service.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/player_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../../domain/entities/fantasy_team.dart';

class FantasyLeaderboardEntry {
  final FantasyTeam team;
  final String managerName;
  final bool isMine;

  const FantasyLeaderboardEntry({
    required this.team,
    required this.managerName,
    required this.isMine,
  });
}

class FantasyLeaderboardController extends GetxController {
  final String leagueId;
  final FantasyRepositoryImpl _fantasyRepository;
  final PlayerRepositoryImpl _playerRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final FantasyLifecycleService _lifecycleService;
  final AuthSession? _authSession;

  FantasyLeaderboardController({
    required this.leagueId,
    FantasyRepositoryImpl? fantasyRepository,
    PlayerRepositoryImpl? playerRepository,
    TournamentRepositoryImpl? tournamentRepository,
    FantasyLifecycleService? lifecycleService,
    AuthSession? authSession,
  })  : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
        _playerRepository = playerRepository ?? PlayerRepositoryImpl(),
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
        _authSession = authSession;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString leagueTitle = 'الدوري العالمي'.obs;
  final Rx<FantasyLeagueLifecycle?> lifecycle = Rx<FantasyLeagueLifecycle?>(null);
  final Rx<FantasyTeam?> currentTeam = Rx<FantasyTeam?>(null);
  final RxList<FantasyLeaderboardEntry> entries =
      <FantasyLeaderboardEntry>[].obs;

  String? get currentUserId => _authSession?.currentUserId;
  bool get isJoinedLeague =>
      currentTeam.value?.leagueIds.contains(leagueId) ?? false;

  @override
  void onInit() {
    super.onInit();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      lifecycle.value = await _lifecycleService.resolveLifecycle(leagueId);

      final userId = currentUserId;
      if (userId != null && userId.isNotEmpty) {
        currentTeam.value = await _fantasyRepository.getFantasyTeam(userId);
      } else {
        currentTeam.value = null;
      }

      if (leagueId != 'global') {
        final tournament = await _tournamentRepository.getTournament(leagueId);
        if (tournament != null) {
          leagueTitle.value = tournament.name;
        } else {
          leagueTitle.value = leagueId;
        }
      } else {
        leagueTitle.value = 'الدوري العالمي';
      }

      final leaderboard = await _fantasyRepository.getLeagueLeaderboard(
        leagueId,
        limit: 50,
      );

      final loadedEntries = await Future.wait(
        leaderboard.map((team) async {
          final player = await _playerRepository.getPlayer(team.ownerPlayerId);
          return FantasyLeaderboardEntry(
            team: team,
            managerName: player?.name ?? 'مدرب مجهول',
            isMine: team.ownerPlayerId == currentUserId,
          );
        }),
      );

      entries.assignAll(loadedEntries);
    } catch (_) {
      errorMessage.value = 'تعذر تحميل الترتيب حالياً.';
    } finally {
      isLoading.value = false;
    }
  }
}
