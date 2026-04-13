/// محرك الإقصاء — يولّد شجرة الإقصاء ويديرها
class KnockoutBracketEngine {
  /// توليد Bracket من قائمة فرق (يجب أن تكون قوة 2: 2, 4, 8, 16)
  static KnockoutBracket generateBracket(List<String> qualifiedTeamIds) {
    final size = qualifiedTeamIds.length;
    assert(size >= 2 && (size & (size - 1)) == 0,
        'عدد الفرق يجب أن يكون قوة 2');

    final rounds = <KnockoutRound>[];
    var currentTeams = List<String>.from(qualifiedTeamIds);

    while (currentTeams.length > 1) {
      final matches = <KnockoutMatch>[];
      for (int i = 0; i < currentTeams.length; i += 2) {
        matches.add(KnockoutMatch(
          teamAId: currentTeams[i],
          teamBId: currentTeams[i + 1],
        ));
      }
      rounds.add(KnockoutRound(
        name: _getRoundName(currentTeams.length),
        matches: matches,
        isCompleted: false,
      ));
      // الفائزون يتقدمون — NULL حتى يُحدَّث بعد اللعب
      currentTeams = List.filled(currentTeams.length ~/ 2, '');
    }

    return KnockoutBracket(rounds: rounds);
  }

  /// تحديث الـ Bracket بعد مباراة
  static KnockoutBracket advanceWinner({
    required KnockoutBracket bracket,
    required int roundIndex,
    required int matchIndex,
    required String winnerId,
  }) {
    final rounds = List<KnockoutRound>.from(bracket.rounds);
    final round = rounds[roundIndex];
    final matches = List<KnockoutMatch>.from(round.matches);
    matches[matchIndex] = matches[matchIndex].copyWith(winnerId: winnerId);

    // فحص إذا اكتملت الجولة كلها
    final allDone = matches.every((m) => m.winnerId != null);

    // تحديث الجولة التالية بالفائزين
    if (allDone && roundIndex + 1 < rounds.length) {
      final nextRound = rounds[roundIndex + 1];
      final nextMatches = List<KnockoutMatch>.from(nextRound.matches);
      final winners = matches.map((m) => m.winnerId!).toList();
      for (int i = 0; i < nextMatches.length; i++) {
        nextMatches[i] = nextMatches[i].copyWith(
          teamAId: winners[i * 2],
          teamBId: winners[i * 2 + 1],
        );
      }
      rounds[roundIndex + 1] = nextRound.copyWith(matches: nextMatches);
    }

    rounds[roundIndex] = round.copyWith(
      matches: matches,
      isCompleted: allDone,
    );

    return KnockoutBracket(rounds: rounds);
  }

  /// الفائز النهائي ببطولة
  static String? getFinalWinner(KnockoutBracket bracket) {
    if (bracket.rounds.isEmpty) return null;
    final finalRound = bracket.rounds.last;
    if (!finalRound.isCompleted) return null;
    return finalRound.matches.first.winnerId;
  }

  static String _getRoundName(int teamCount) {
    return switch (teamCount) {
      2 => 'النهائي',
      4 => 'نصف النهائي',
      8 => 'ربع النهائي',
      16 => 'دور الـ 16',
      _ => 'جولة ($teamCount فريق)',
    };
  }
}

/// شجرة الإقصاء الكاملة
class KnockoutBracket {
  final List<KnockoutRound> rounds;
  const KnockoutBracket({required this.rounds});

  bool get isCompleted =>
      rounds.isNotEmpty && rounds.last.isCompleted;
}

/// جولة في الإقصاء
class KnockoutRound {
  final String name;
  final List<KnockoutMatch> matches;
  final bool isCompleted;

  const KnockoutRound({
    required this.name,
    required this.matches,
    this.isCompleted = false,
  });

  KnockoutRound copyWith({
    String? name,
    List<KnockoutMatch>? matches,
    bool? isCompleted,
  }) => KnockoutRound(
    name: name ?? this.name,
    matches: matches ?? this.matches,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}

/// مباراة في الإقصاء
class KnockoutMatch {
  final String teamAId;
  final String teamBId;
  final String? winnerId;
  final int? scoreA;
  final int? scoreB;

  const KnockoutMatch({
    required this.teamAId,
    required this.teamBId,
    this.winnerId,
    this.scoreA,
    this.scoreB,
  });

  bool get isPlayed => winnerId != null;

  KnockoutMatch copyWith({
    String? teamAId,
    String? teamBId,
    String? winnerId,
    int? scoreA,
    int? scoreB,
  }) => KnockoutMatch(
    teamAId: teamAId ?? this.teamAId,
    teamBId: teamBId ?? this.teamBId,
    winnerId: winnerId ?? this.winnerId,
    scoreA: scoreA ?? this.scoreA,
    scoreB: scoreB ?? this.scoreB,
  );
}
