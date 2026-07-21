class TournamentGroupAdvancementConfig {
  final int? groupCount;
  final int automaticQualifiersPerGroup;
  final int bestRankedAdditionalQualifiers;

  const TournamentGroupAdvancementConfig({
    this.groupCount,
    this.automaticQualifiersPerGroup = 2,
    this.bestRankedAdditionalQualifiers = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      if (groupCount != null) 'groupCount': groupCount,
      'automaticQualifiersPerGroup': automaticQualifiersPerGroup,
      'bestRankedAdditionalQualifiers': bestRankedAdditionalQualifiers,
    };
  }

  factory TournamentGroupAdvancementConfig.fromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) {
      return const TournamentGroupAdvancementConfig();
    }
    return TournamentGroupAdvancementConfig(
      groupCount: (json['groupCount'] as num?)?.toInt(),
      automaticQualifiersPerGroup:
          (json['automaticQualifiersPerGroup'] as num?)?.toInt() ?? 2,
      bestRankedAdditionalQualifiers:
          (json['bestRankedAdditionalQualifiers'] as num?)?.toInt() ?? 0,
    );
  }

  TournamentGroupAdvancementConfig copyWith({
    Object? groupCount = _unset,
    int? automaticQualifiersPerGroup,
    int? bestRankedAdditionalQualifiers,
  }) {
    return TournamentGroupAdvancementConfig(
      groupCount: identical(groupCount, _unset)
          ? this.groupCount
          : groupCount as int?,
      automaticQualifiersPerGroup:
          automaticQualifiersPerGroup ?? this.automaticQualifiersPerGroup,
      bestRankedAdditionalQualifiers:
          bestRankedAdditionalQualifiers ?? this.bestRankedAdditionalQualifiers,
    );
  }
}

const Object _unset = Object();
