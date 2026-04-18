import '../../core/enums/dispute_enums.dart';
import '../../domain/entities/dispute.dart';

class DisputeModel {
  final String id;
  final String matchId;
  final String? tournamentId;
  final String type;
  final String status;
  final String raisedBy;
  final String description;
  final List<String> evidenceUrls;
  final String? resolvedBy;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime deadline;
  final DateTime? resolvedAt;

  const DisputeModel({
    required this.id,
    required this.matchId,
    this.tournamentId,
    required this.type,
    required this.status,
    required this.raisedBy,
    required this.description,
    this.evidenceUrls = const [],
    this.resolvedBy,
    this.resolutionNote,
    required this.createdAt,
    required this.deadline,
    this.resolvedAt,
  });

  factory DisputeModel.fromJson(Map<String, dynamic> json, String docId) {
    return DisputeModel(
      id: docId,
      matchId: json['matchId'] as String? ?? '',
      tournamentId: json['tournamentId'] as String?,
      type: json['type'] as String? ?? 'general',
      status: json['status'] as String? ?? 'open',
      raisedBy: json['raisedBy'] as String? ?? '',
      description: json['description'] as String? ?? '',
      evidenceUrls: (json['evidenceUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      resolvedBy: json['resolvedBy'] as String?,
      resolutionNote: json['resolutionNote'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt())
          : DateTime.now(),
      deadline: json['deadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['deadline'] as num).toInt())
          : DateTime.now().add(const Duration(hours: 24)),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['resolvedAt'] as num).toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'tournamentId': tournamentId,
      'type': type,
      'status': status,
      'raisedBy': raisedBy,
      'description': description,
      'evidenceUrls': evidenceUrls,
      'resolvedBy': resolvedBy,
      'resolutionNote': resolutionNote,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'deadline': deadline.millisecondsSinceEpoch,
      'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
    };
  }

  Dispute toEntity() {
    return Dispute(
      id: id,
      matchId: matchId,
      tournamentId: tournamentId,
      type: _parseType(type),
      status: _parseStatus(status),
      raisedBy: raisedBy,
      description: description,
      evidenceUrls: evidenceUrls,
      resolvedBy: resolvedBy,
      resolutionNote: resolutionNote,
      createdAt: createdAt,
      deadline: deadline,
      resolvedAt: resolvedAt,
    );
  }

  factory DisputeModel.fromEntity(Dispute dispute) {
    return DisputeModel(
      id: dispute.id,
      matchId: dispute.matchId,
      tournamentId: dispute.tournamentId,
      type: dispute.type.name,
      status: dispute.status.name,
      raisedBy: dispute.raisedBy,
      description: dispute.description,
      evidenceUrls: dispute.evidenceUrls,
      resolvedBy: dispute.resolvedBy,
      resolutionNote: dispute.resolutionNote,
      createdAt: dispute.createdAt,
      deadline: dispute.deadline,
      resolvedAt: dispute.resolvedAt,
    );
  }

  static DisputeType _parseType(String value) {
    return DisputeType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => DisputeType.general,
    );
  }

  static DisputeStatus _parseStatus(String value) {
    return DisputeStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DisputeStatus.open,
    );
  }
}
