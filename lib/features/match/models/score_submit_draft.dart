class ScoreSubmitRegisteredStatsDraft {
  final int assists;
  final int saves;
  final bool yellowCard;
  final bool redCard;

  const ScoreSubmitRegisteredStatsDraft({
    this.assists = 0,
    this.saves = 0,
    this.yellowCard = false,
    this.redCard = false,
  });

  factory ScoreSubmitRegisteredStatsDraft.fromJson(Map<String, dynamic> json) {
    return ScoreSubmitRegisteredStatsDraft(
      assists: json['assists'] as int? ?? 0,
      saves: json['saves'] as int? ?? 0,
      yellowCard: json['yellowCard'] as bool? ?? false,
      redCard: json['redCard'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'assists': assists,
    'saves': saves,
    'yellowCard': yellowCard,
    'redCard': redCard,
  };
}

class ScoreSubmitDraft {
  static const int currentSchemaVersion = 1;

  final String matchId;
  final String sourceFingerprint;
  final String scoreA;
  final String scoreB;
  final String penaltyScoreA;
  final String penaltyScoreB;
  final Map<String, int> goalsByParticipantKey;
  final String selectedMvpKey;
  final Map<String, ScoreSubmitRegisteredStatsDraft> registeredStats;

  const ScoreSubmitDraft({
    required this.matchId,
    required this.sourceFingerprint,
    required this.scoreA,
    required this.scoreB,
    this.penaltyScoreA = '',
    this.penaltyScoreB = '',
    required this.goalsByParticipantKey,
    required this.selectedMvpKey,
    required this.registeredStats,
  });

  factory ScoreSubmitDraft.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int?;
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('Unsupported score draft schema.');
    }
    return ScoreSubmitDraft(
      matchId: json['matchId'] as String? ?? '',
      sourceFingerprint: json['sourceFingerprint'] as String? ?? '',
      scoreA: json['scoreA'] as String? ?? '',
      scoreB: json['scoreB'] as String? ?? '',
      penaltyScoreA: json['penaltyScoreA'] as String? ?? '',
      penaltyScoreB: json['penaltyScoreB'] as String? ?? '',
      goalsByParticipantKey: _intMap(json['goalsByParticipantKey']),
      selectedMvpKey: json['selectedMvpKey'] as String? ?? '',
      registeredStats: _statsMap(json['registeredStats']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'matchId': matchId,
    'sourceFingerprint': sourceFingerprint,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'penaltyScoreA': penaltyScoreA,
    'penaltyScoreB': penaltyScoreB,
    'goalsByParticipantKey': goalsByParticipantKey,
    'selectedMvpKey': selectedMvpKey,
    'registeredStats': {
      for (final entry in registeredStats.entries)
        entry.key: entry.value.toJson(),
    },
  };

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const <String, int>{};
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    };
  }

  static Map<String, ScoreSubmitRegisteredStatsDraft> _statsMap(Object? value) {
    if (value is! Map) {
      return const <String, ScoreSubmitRegisteredStatsDraft>{};
    }
    return {
      for (final entry in value.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: ScoreSubmitRegisteredStatsDraft.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    };
  }
}
