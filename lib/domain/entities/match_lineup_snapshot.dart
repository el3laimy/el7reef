import 'match_lineup_entry.dart';

/// Authoritative frozen lineup captured when a side is locked before kickoff.
class MatchLineupSnapshot {
  final String id;
  final String matchId;
  final String? teamId;
  final String? guestTeamId;
  final String? matchSideId;
  final String? sideKey;
  final String? tournamentRegistrationId;
  final String? checkInId;
  final List<MatchLineupEntry> starters;
  final List<MatchLineupEntry> bench;
  final String lockedBy;
  final DateTime lockedAt;
  final int? playerCount;
  final String? formationCode;
  final String? formationLabel;
  final String? notes;

  const MatchLineupSnapshot({
    required this.id,
    required this.matchId,
    this.teamId,
    this.guestTeamId,
    this.matchSideId,
    this.sideKey,
    this.tournamentRegistrationId,
    this.checkInId,
    required this.starters,
    this.bench = const [],
    required this.lockedBy,
    required this.lockedAt,
    this.playerCount,
    this.formationCode,
    this.formationLabel,
    this.notes,
  }) : assert(
         (teamId == null ? 0 : 1) +
                 (guestTeamId == null ? 0 : 1) +
                 (matchSideId == null ? 0 : 1) ==
             1,
         'Exactly one of teamId, guestTeamId, or matchSideId must be set.',
       );

  bool get isGuestTeam => guestTeamId != null;
  bool get isRegisteredTeam => teamId != null;
  bool get isMatchSide => matchSideId != null;
  int get guestCount =>
      [...starters, ...bench].where((entry) => entry.isGuest).length;
  String get participantId => teamId ?? guestTeamId ?? matchSideId!;

  String get summaryLabel {
    final effectiveFormation = formationCode?.trim().isNotEmpty == true
        ? formationCode!.trim()
        : formationLabel?.trim();
    if (effectiveFormation != null && effectiveFormation.isNotEmpty) {
      return effectiveFormation;
    }
    return 'أساسي ${starters.length} • احتياط ${bench.length} • ضيوف $guestCount';
  }
}
