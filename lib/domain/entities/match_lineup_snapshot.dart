import 'match_lineup_entry.dart';

/// Authoritative frozen lineup captured when a side is locked before kickoff.
class MatchLineupSnapshot {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final List<MatchLineupEntry> starters;
  final List<MatchLineupEntry> bench;
  final String lockedBy;
  final DateTime lockedAt;
  final String? formationLabel;
  final String? notes;

  const MatchLineupSnapshot({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.tournamentRegistrationId,
    this.checkInId,
    required this.starters,
    this.bench = const [],
    required this.lockedBy,
    required this.lockedAt,
    this.formationLabel,
    this.notes,
  }) : assert(
          (teamId != null) != (guestTeamId != null),
          'Exactly one of teamId or guestTeamId must be set.',
        );

  bool get isGuestTeam => guestTeamId != null;
  bool get isRegisteredTeam => teamId != null;
  int get guestCount =>
      [...starters, ...bench].where((entry) => entry.isGuest).length;
  String get participantId => teamId ?? guestTeamId!;

  String get summaryLabel {
    final effectiveFormation = formationLabel?.trim();
    if (effectiveFormation != null && effectiveFormation.isNotEmpty) {
      return effectiveFormation;
    }
    return 'أساسي ${starters.length} • احتياط ${bench.length} • ضيوف $guestCount';
  }
}
