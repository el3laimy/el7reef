import '../../domain/entities/match_side.dart';

class MatchSideModel {
  final String id;
  final String matchId;
  final String sideKey;
  final String type;
  final String displayName;
  final String? officialTeamId;
  final String? captainUserId;
  final List<String> managedByUserIds;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MatchSideModel({
    required this.id,
    required this.matchId,
    required this.sideKey,
    required this.type,
    required this.displayName,
    this.officialTeamId,
    this.captainUserId,
    this.managedByUserIds = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MatchSideModel.fromJson(Map<String, dynamic> json, String id) {
    return MatchSideModel(
      id: id,
      matchId: json['matchId'] as String? ?? '',
      sideKey: json['sideKey'] as String? ?? '',
      type: json['type'] as String? ?? 'temporary',
      displayName: json['displayName'] as String? ?? '',
      officialTeamId: json['officialTeamId'] as String?,
      captainUserId: json['captainUserId'] as String?,
      managedByUserIds:
          (json['managedByUserIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const [],
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: _dateFromMs(json['createdAt']),
      updatedAt: _dateFromMs(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'sideKey': sideKey,
      'type': type,
      'displayName': displayName,
      'officialTeamId': officialTeamId,
      'captainUserId': captainUserId,
      'managedByUserIds': managedByUserIds,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  MatchSide toEntity() {
    return MatchSide(
      id: id,
      matchId: matchId,
      sideKey: sideKey,
      type: type,
      displayName: displayName,
      officialTeamId: officialTeamId,
      captainUserId: captainUserId,
      managedByUserIds: managedByUserIds,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory MatchSideModel.fromEntity(MatchSide side) {
    return MatchSideModel(
      id: side.id,
      matchId: side.matchId,
      sideKey: side.sideKey,
      type: side.type,
      displayName: side.displayName,
      officialTeamId: side.officialTeamId,
      captainUserId: side.captainUserId,
      managedByUserIds: side.managedByUserIds,
      createdBy: side.createdBy,
      createdAt: side.createdAt,
      updatedAt: side.updatedAt,
    );
  }

  static DateTime _dateFromMs(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }
}
