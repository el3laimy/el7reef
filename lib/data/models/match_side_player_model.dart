import '../../domain/entities/match_side_player.dart';

class MatchSidePlayerModel {
  final String id;
  final String matchId;
  final String sideKey;
  final String sideId;
  final String kind;
  final String? playerId;
  final String displayName;
  final String? position;
  final int? shirtNumber;
  final bool ratingEligible;
  final String addedBy;
  final DateTime createdAt;

  const MatchSidePlayerModel({
    required this.id,
    required this.matchId,
    required this.sideKey,
    required this.sideId,
    required this.kind,
    this.playerId,
    required this.displayName,
    this.position,
    this.shirtNumber,
    required this.ratingEligible,
    required this.addedBy,
    required this.createdAt,
  });

  factory MatchSidePlayerModel.fromJson(Map<String, dynamic> json, String id) {
    return MatchSidePlayerModel(
      id: id,
      matchId: json['matchId'] as String? ?? '',
      sideKey: json['sideKey'] as String? ?? '',
      sideId: json['sideId'] as String? ?? '',
      kind: json['kind'] as String? ?? 'temporary',
      playerId: json['playerId'] as String?,
      displayName: json['displayName'] as String? ?? '',
      position: json['position'] as String?,
      shirtNumber: (json['shirtNumber'] as num?)?.toInt(),
      ratingEligible: json['ratingEligible'] as bool? ?? false,
      addedBy: json['addedBy'] as String? ?? '',
      createdAt: _dateFromMs(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'sideKey': sideKey,
      'sideId': sideId,
      'kind': kind,
      'playerId': playerId,
      'displayName': displayName,
      'position': position,
      'shirtNumber': shirtNumber,
      'ratingEligible': ratingEligible,
      'addedBy': addedBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  MatchSidePlayer toEntity() {
    return MatchSidePlayer(
      id: id,
      matchId: matchId,
      sideKey: sideKey,
      sideId: sideId,
      kind: kind,
      playerId: playerId,
      displayName: displayName,
      position: position,
      shirtNumber: shirtNumber,
      ratingEligible: ratingEligible,
      addedBy: addedBy,
      createdAt: createdAt,
    );
  }

  factory MatchSidePlayerModel.fromEntity(MatchSidePlayer player) {
    return MatchSidePlayerModel(
      id: player.id,
      matchId: player.matchId,
      sideKey: player.sideKey,
      sideId: player.sideId,
      kind: player.kind,
      playerId: player.playerId,
      displayName: player.displayName,
      position: player.position,
      shirtNumber: player.shirtNumber,
      ratingEligible: player.ratingEligible,
      addedBy: player.addedBy,
      createdAt: player.createdAt,
    );
  }

  static DateTime _dateFromMs(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }
}
