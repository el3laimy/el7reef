import '../../core/enums/challenge_status.dart';

class Challenge {
  final String id;
  final String challengerId;
  final String challengedId;
  final String? challengerTeamId;
  final String? challengedTeamId;
  final String? matchId; // Set when accepted
  final ChallengeStatus status;
  final String? message;
  final String? location;
  final int teamSize;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;

  const Challenge({
    required this.id,
    required this.challengerId,
    required this.challengedId,
    this.challengerTeamId,
    this.challengedTeamId,
    this.matchId,
    this.status = ChallengeStatus.pending,
    this.message,
    this.location,
    required this.teamSize,
    required this.createdAt,
    this.respondedAt,
    required this.expiresAt,
  });

  bool get isTeamChallenge => challengerTeamId != null && challengedTeamId != null;

  Challenge copyWith({
    String? id,
    String? challengerId,
    String? challengedId,
    String? challengerTeamId,
    String? challengedTeamId,
    String? matchId,
    ChallengeStatus? status,
    String? message,
    String? location,
    int? teamSize,
    DateTime? createdAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      challengerId: challengerId ?? this.challengerId,
      challengedId: challengedId ?? this.challengedId,
      challengerTeamId: challengerTeamId ?? this.challengerTeamId,
      challengedTeamId: challengedTeamId ?? this.challengedTeamId,
      matchId: matchId ?? this.matchId,
      status: status ?? this.status,
      message: message ?? this.message,
      location: location ?? this.location,
      teamSize: teamSize ?? this.teamSize,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
