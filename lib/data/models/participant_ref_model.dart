import '../../domain/entities/participant_ref.dart';

class ParticipantRefModel {
  final String kind;
  final String id;
  final String displayName;
  final String? linkedPlayerId;

  const ParticipantRefModel({
    required this.kind,
    required this.id,
    required this.displayName,
    this.linkedPlayerId,
  });

  factory ParticipantRefModel.fromJson(Map<String, dynamic> json) {
    return ParticipantRefModel(
      kind: json['kind'] as String? ?? ParticipantRefKind.player.name,
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      linkedPlayerId: json['linkedPlayerId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'id': id,
      'displayName': displayName,
      'linkedPlayerId': linkedPlayerId,
    };
  }

  ParticipantRef toEntity() {
    return ParticipantRef(
      kind: _parseKind(kind),
      id: id,
      displayName: displayName,
      linkedPlayerId: linkedPlayerId,
    );
  }

  factory ParticipantRefModel.fromEntity(ParticipantRef ref) {
    return ParticipantRefModel(
      kind: ref.kind.name,
      id: ref.id,
      displayName: ref.displayName,
      linkedPlayerId: ref.linkedPlayerId,
    );
  }

  static ParticipantRefKind _parseKind(String value) {
    return ParticipantRefKind.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => ParticipantRefKind.player,
    );
  }
}
