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
    final kind = _parseKindValue(json['kind']);
    final id = _requiredString(json['id'], 'id');
    final displayName = _requiredString(json['displayName'], 'displayName');
    final linkedPlayerId = _optionalString(
      json['linkedPlayerId'],
      'linkedPlayerId',
    );
    return ParticipantRefModel(
      kind: kind.name,
      id: id,
      displayName: displayName,
      linkedPlayerId: linkedPlayerId,
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
    return _parseKindValue(value);
  }

  static ParticipantRefKind _parseKindValue(Object? value) {
    if (value is! String) {
      throw const FormatException('ParticipantRef.kind is required.');
    }
    final normalized = value.trim();
    for (final kind in ParticipantRefKind.values) {
      if (kind.name == normalized) return kind;
    }
    throw FormatException('Unknown ParticipantRef.kind: $normalized');
  }

  static String _requiredString(Object? value, String fieldName) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('ParticipantRef.$fieldName is required.');
    }
    return value.trim();
  }

  static String? _optionalString(Object? value, String fieldName) {
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('ParticipantRef.$fieldName must be a string.');
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
