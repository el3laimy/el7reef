import '../../domain/entities/tournament.dart';

/// محرك المجموعات — يولّد الجدول ويحسب الترتيب
class GroupStageGenerator {
  /// توليد مباريات Round Robin بين الفرق
  /// كل فريقين يتقابلان مرة واحدة
  static List<RoundRobinFixture> generateFixtures(List<String> teamIds) {
    final fixtures = <RoundRobinFixture>[];
    for (int i = 0; i < teamIds.length; i++) {
      for (int j = i + 1; j < teamIds.length; j++) {
        fixtures.add(RoundRobinFixture(
          homeTeamId: teamIds[i],
          awayTeamId: teamIds[j],
        ));
      }
    }
    return fixtures;
  }

  /// حساب الترتيب من نتائج المباريات
  static List<GroupStanding> calculateStandings(
    List<String> teamIds,
    List<GroupMatchResult> results,
  ) {
    final standingMap = <String, GroupStanding>{};

    // تهيئة الجدول
    for (final id in teamIds) {
      standingMap[id] = GroupStanding(teamId: id, teamName: id);
    }

    // تطبيق النتائج
    for (final result in results) {
      final home = standingMap[result.homeTeamId];
      final away = standingMap[result.awayTeamId];
      if (home == null || away == null) continue;

      if (result.homeGoals > result.awayGoals) {
        // فوز home
        standingMap[result.homeTeamId] = _addResult(home, true, false,
            result.homeGoals, result.awayGoals);
        standingMap[result.awayTeamId] = _addResult(away, false, false,
            result.awayGoals, result.homeGoals);
      } else if (result.awayGoals > result.homeGoals) {
        // فوز away
        standingMap[result.homeTeamId] = _addResult(home, false, false,
            result.homeGoals, result.awayGoals);
        standingMap[result.awayTeamId] = _addResult(away, true, false,
            result.awayGoals, result.homeGoals);
      } else {
        // تعادل
        standingMap[result.homeTeamId] = _addResult(home, false, true,
            result.homeGoals, result.awayGoals);
        standingMap[result.awayTeamId] = _addResult(away, false, true,
            result.awayGoals, result.homeGoals);
      }
    }

    // الترتيب: نقاط → فارق أهداف → أهداف مسجلة
    final standings = standingMap.values.toList();
    standings.sort((a, b) => a.compareTo(b));
    return standings;
  }

  static GroupStanding _addResult(
    GroupStanding s,
    bool isWin,
    bool isDraw,
    int goalsFor,
    int goalsAgainst,
  ) {
    return GroupStanding(
      teamId: s.teamId,
      teamName: s.teamName,
      played: s.played + 1,
      wins: s.wins + (isWin ? 1 : 0),
      draws: s.draws + (isDraw ? 1 : 0),
      losses: s.losses + (!isWin && !isDraw ? 1 : 0),
      goalsFor: s.goalsFor + goalsFor,
      goalsAgainst: s.goalsAgainst + goalsAgainst,
    );
  }

  /// اختيار المتأهلين من المجموعة (أول N فرق)
  static List<String> getQualifiers(
    List<GroupStanding> standings,
    int qualifiersCount,
  ) {
    return standings.take(qualifiersCount).map((s) => s.teamId).toList();
  }
}

/// مباراة في المجموعات
class RoundRobinFixture {
  final String homeTeamId;
  final String awayTeamId;
  const RoundRobinFixture({required this.homeTeamId, required this.awayTeamId});
}

/// نتيجة مباراة مجموعات
class GroupMatchResult {
  final String homeTeamId;
  final String awayTeamId;
  final int homeGoals;
  final int awayGoals;
  const GroupMatchResult({
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeGoals,
    required this.awayGoals,
  });
}
