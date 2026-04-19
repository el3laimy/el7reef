import '../../core/enums/tournament_ops_enums.dart';

class TournamentGroupStandingsConfig {
  final List<GroupStandingsMetric> tiebreakerOrder;

  const TournamentGroupStandingsConfig({
    this.tiebreakerOrder = const [
      GroupStandingsMetric.points,
      GroupStandingsMetric.goalDifference,
      GroupStandingsMetric.goalsFor,
      GroupStandingsMetric.randomDraw,
    ],
  });

  Map<String, dynamic> toJson() {
    return {
      'tiebreakerOrder': tiebreakerOrder.map((metric) => metric.name).toList(),
    };
  }

  factory TournamentGroupStandingsConfig.fromJson(Map<String, dynamic>? json) {
    final encoded =
        (json?['tiebreakerOrder'] as List<dynamic>?)
            ?.map((value) => value as String)
            .toList(growable: false) ??
        const <String>[];
    if (encoded.isEmpty) {
      return const TournamentGroupStandingsConfig();
    }
    return TournamentGroupStandingsConfig(
      tiebreakerOrder: encoded
          .map(
            (value) => GroupStandingsMetric.values.firstWhere(
              (metric) => metric.name == value,
              orElse: () => GroupStandingsMetric.randomDraw,
            ),
          )
          .toList(growable: false),
    );
  }

  TournamentGroupStandingsConfig copyWith({
    List<GroupStandingsMetric>? tiebreakerOrder,
  }) {
    return TournamentGroupStandingsConfig(
      tiebreakerOrder: tiebreakerOrder ?? this.tiebreakerOrder,
    );
  }
}
