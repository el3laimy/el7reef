import '../../core/enums/fantasy_league_phase.dart';
import '../../domain/entities/fantasy_league_lifecycle.dart';

class FantasyLeagueLifecycleModel extends FantasyLeagueLifecycle {
  const FantasyLeagueLifecycleModel({
    required super.leagueId,
    super.currentGameweek = 1,
    super.phase = FantasyLeaguePhase.draft,
    super.deadlineAt,
    super.isLocked = false,
    super.isGlobal = false,
    super.openedAt,
    super.settledAt,
    required super.updatedAt,
  });

  factory FantasyLeagueLifecycleModel.fromJson(
    Map<String, dynamic> json,
    String documentId,
  ) {
    final phaseName = json['phase'] as String? ?? FantasyLeaguePhase.draft.name;
    return FantasyLeagueLifecycleModel(
      leagueId: documentId,
      currentGameweek: (json['currentGameweek'] as num?)?.toInt() ?? 1,
      phase: FantasyLeaguePhase.values.firstWhere(
        (value) => value.name == phaseName,
        orElse: () => FantasyLeaguePhase.draft,
      ),
      deadlineAt: json['deadlineAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deadlineAt'] as int)
          : null,
      isLocked: json['isLocked'] as bool? ?? false,
      isGlobal: json['isGlobal'] as bool? ?? documentId == 'global',
      openedAt: json['openedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['openedAt'] as int)
          : null,
      settledAt: json['settledAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['settledAt'] as int)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentGameweek': currentGameweek,
      'phase': phase.name,
      'deadlineAt': deadlineAt?.millisecondsSinceEpoch,
      'isLocked': isLocked,
      'isGlobal': isGlobal,
      'openedAt': openedAt?.millisecondsSinceEpoch,
      'settledAt': settledAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory FantasyLeagueLifecycleModel.fromEntity(
    FantasyLeagueLifecycle entity,
  ) {
    return FantasyLeagueLifecycleModel(
      leagueId: entity.leagueId,
      currentGameweek: entity.currentGameweek,
      phase: entity.phase,
      deadlineAt: entity.deadlineAt,
      isLocked: entity.isLocked,
      isGlobal: entity.isGlobal,
      openedAt: entity.openedAt,
      settledAt: entity.settledAt,
      updatedAt: entity.updatedAt,
    );
  }

  FantasyLeagueLifecycle toEntity() {
    return FantasyLeagueLifecycle(
      leagueId: leagueId,
      currentGameweek: currentGameweek,
      phase: phase,
      deadlineAt: deadlineAt,
      isLocked: isLocked,
      isGlobal: isGlobal,
      openedAt: openedAt,
      settledAt: settledAt,
      updatedAt: updatedAt,
    );
  }
}
