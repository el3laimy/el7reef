import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/challenge.dart';
import '../../core/enums/challenge_status.dart';

class ChallengeModel extends Challenge {
  const ChallengeModel({
    required super.id,
    required super.challengerId,
    required super.challengedId,
    super.challengerTeamId,
    super.challengedTeamId,
    super.matchId,
    super.status = ChallengeStatus.pending,
    super.message,
    super.location,
    required super.teamSize,
    required super.createdAt,
    super.respondedAt,
    required super.expiresAt,
  });

  factory ChallengeModel.fromJson(Map<String, dynamic> json, String id) {
    return ChallengeModel(
      id: id,
      challengerId: json['challengerId'] as String? ?? '',
      challengedId: json['challengedId'] as String? ?? '',
      challengerTeamId: json['challengerTeamId'] as String?,
      challengedTeamId: json['challengedTeamId'] as String?,
      matchId: json['matchId'] as String?,
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      message: json['message'] as String?,
      location: json['location'] as String?,
      teamSize: (json['teamSize'] as num?)?.toInt() ?? 5,
      createdAt: json['createdAt'] != null ? (json['createdAt'] as Timestamp).toDate() : DateTime.now(),
      respondedAt: json['respondedAt'] != null
          ? (json['respondedAt'] as Timestamp).toDate()
          : null,
      expiresAt: json['expiresAt'] != null ? (json['expiresAt'] as Timestamp).toDate() : DateTime.now().add(const Duration(days: 3)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challengerId': challengerId,
      'challengedId': challengedId,
      'challengerTeamId': challengerTeamId,
      'challengedTeamId': challengedTeamId,
      'matchId': matchId,
      'status': status.name,
      'message': message,
      'location': location,
      'teamSize': teamSize,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
