import '../../core/enums/dispute_enums.dart';

/// كيان النزاع — يُمثل اعتراض على قرار في مباراة أو بطولة
class Dispute {
  final String id;
  final String matchId;
  final String? tournamentId;
  final DisputeType type;
  final DisputeStatus status;
  final String raisedBy;
  final String description;
  final List<String> evidenceUrls;
  final String? resolvedBy;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime deadline;
  final DateTime? resolvedAt;

  const Dispute({
    required this.id,
    required this.matchId,
    this.tournamentId,
    required this.type,
    this.status = DisputeStatus.open,
    required this.raisedBy,
    required this.description,
    this.evidenceUrls = const [],
    this.resolvedBy,
    this.resolutionNote,
    required this.createdAt,
    required this.deadline,
    this.resolvedAt,
  });

  /// هل النزاع لا يزال مفتوحاً؟
  bool get isOpen => status == DisputeStatus.open || status == DisputeStatus.underReview;

  /// هل انتهت المهلة؟
  bool hasExpired(DateTime now) => now.isAfter(deadline) && isOpen;

  /// هل تم الحل أو الرفض؟
  bool get isClosed =>
      status == DisputeStatus.resolved ||
      status == DisputeStatus.rejected ||
      status == DisputeStatus.expired;

  Dispute copyWith({
    String? id,
    String? matchId,
    String? tournamentId,
    DisputeType? type,
    DisputeStatus? status,
    String? raisedBy,
    String? description,
    List<String>? evidenceUrls,
    String? resolvedBy,
    String? resolutionNote,
    DateTime? createdAt,
    DateTime? deadline,
    DateTime? resolvedAt,
  }) {
    return Dispute(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      tournamentId: tournamentId ?? this.tournamentId,
      type: type ?? this.type,
      status: status ?? this.status,
      raisedBy: raisedBy ?? this.raisedBy,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolutionNote: resolutionNote ?? this.resolutionNote,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
