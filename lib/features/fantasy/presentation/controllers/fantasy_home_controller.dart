import 'package:get/get.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_team.dart';
import '../../../../domain/entities/tournament.dart';

class FantasyLeagueSummary {
  final String id;
  final String title;
  final String subtitle;
  final bool isGlobal;
  final bool joined;

  const FantasyLeagueSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isGlobal,
    required this.joined,
  });
}

class FantasyHomeController extends GetxController {
  final FantasyRepositoryImpl _fantasyRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final AuthSession? _authSession;

  FantasyHomeController({
    FantasyRepositoryImpl? fantasyRepository,
    TournamentRepositoryImpl? tournamentRepository,
    AuthSession? authSession,
  })  : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
        _tournamentRepository =
            tournamentRepository ?? TournamentRepositoryImpl(),
        _authSession = authSession;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<FantasyTeam?> currentTeam = Rx<FantasyTeam?>(null);
  final RxList<FantasyLeagueSummary> leagues = <FantasyLeagueSummary>[].obs;
  final RxInt globalRank = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final userId = _authSession?.currentUserId;
      FantasyTeam? team;
      if (userId != null && userId.isNotEmpty) {
        team = await _fantasyRepository.getFantasyTeam(userId);
      }
      currentTeam.value = team;

      final liveTournaments = await _tournamentRepository.getLiveTournaments(
        limit: 30,
      );
      final fantasyTournaments = liveTournaments
          .where((tournament) => tournament.isFantasyEnabled)
          .toList();

      leagues.assignAll([
        FantasyLeagueSummary(
          id: 'global',
          title: 'الدوري العالمي',
          subtitle: 'الترتيب العام لكل فرق الفانتازي',
          isGlobal: true,
          joined: team?.leagueIds.contains('global') ?? false,
        ),
        ...fantasyTournaments.map(
          (tournament) => FantasyLeagueSummary(
            id: tournament.id,
            title: tournament.name,
            subtitle: _buildTournamentSubtitle(tournament),
            isGlobal: false,
            joined: team?.leagueIds.contains(tournament.id) ?? false,
          ),
        ),
      ]);

      if (team != null) {
        final teamId = team.id;
        final leaderboard = await _fantasyRepository.getLeagueLeaderboard(
          'global',
          limit: 200,
        );
        final rankIndex = leaderboard.indexWhere((item) => item.id == teamId);
        globalRank.value = rankIndex >= 0 ? rankIndex + 1 : 0;
      } else {
        globalRank.value = 0;
      }
    } catch (_) {
      errorMessage.value = 'تعذر تحميل واجهة الفانتازي حالياً.';
    } finally {
      isLoading.value = false;
    }
  }

  String _buildTournamentSubtitle(Tournament tournament) {
    return tournament.location == null || tournament.location!.isEmpty
        ? 'دوري خاص مرتبط بهذه البطولة'
        : 'بطولة في ${tournament.location}';
  }
}
