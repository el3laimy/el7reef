import '../../core/enums/player_trust_level.dart';
import '../../core/enums/user_role.dart';
import '../../domain/entities/player.dart';

/// نموذج بيانات اللاعب — تحويل من/إلى Firestore
class PlayerModel {
  final String id;
  final String name;
  final String? username;
  final String? photoUrl;
  final String? photoThumbUrl;
  final String? photoFrame;
  final String? qrCode;
  final String? phone;
  final String? position;
  final int rating;
  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final int mvpCount;
  final double trustWeight;
  final String trustLevel;
  final String role;
  final List<String> achievementIds;
  final List<String> teamIds;
  final List<String> friendIds;
  final List<String> followingIds;
  final List<String> blockedIds;
  final String privacySetting;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const PlayerModel({
    required this.id,
    required this.name,
    this.username,
    this.photoUrl,
    this.photoThumbUrl,
    this.photoFrame,
    this.qrCode,
    this.phone,
    this.position,
    this.rating = 1000,
    this.totalMatches = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.mvpCount = 0,
    this.trustWeight = 0.5,
    this.trustLevel = 'newPlayer',
    this.role = 'player',
    this.achievementIds = const [],
    this.teamIds = const [],
    this.friendIds = const [],
    this.followingIds = const [],
    this.blockedIds = const [],
    this.privacySetting = 'public',
    required this.createdAt,
    required this.lastActiveAt,
  });

  /// من Firestore Map إلى PlayerModel
  factory PlayerModel.fromJson(Map<String, dynamic> json, String docId) {
    return PlayerModel(
      id: docId,
      name: json['name'] as String? ?? '',
      username: json['username'] as String?,
      photoUrl: json['photoUrl'] as String?,
      photoThumbUrl: json['photoThumbUrl'] as String?,
      photoFrame: json['photoFrame'] as String?,
      qrCode: json['qrCode'] as String? ?? '7reef://player/$docId',
      phone: json['phone'] as String?,
      position: json['position'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 1000,
      totalMatches: (json['totalMatches'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      mvpCount: (json['mvpCount'] as num?)?.toInt() ?? 0,
      trustWeight: (json['trustWeight'] as num?)?.toDouble() ?? 0.5,
      trustLevel: json['trustLevel'] as String? ?? 'newPlayer',
      role: json['role'] as String? ?? 'player',
      achievementIds: (json['achievementIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      teamIds: (json['teamIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      friendIds: (json['friendIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      followingIds: (json['followingIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      blockedIds: (json['blockedIds'] as List<dynamic>?)
              ?.map((e) => e as String).toList() ?? [],
      privacySetting: json['privacySetting'] as String? ?? 'public',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['createdAt'] as num).toInt())
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['lastActiveAt'] as num).toInt())
          : DateTime.now(),
    );
  }

  /// من PlayerModel إلى Firestore Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'usernameLower': username?.toLowerCase(),
      'photoUrl': photoUrl,
      'photoThumbUrl': photoThumbUrl,
      'photoFrame': photoFrame,
      'qrCode': qrCode ?? '7reef://player/$id',
      'phone': phone,
      'position': position,
      'rating': rating,
      'totalMatches': totalMatches,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'mvpCount': mvpCount,
      'trustWeight': trustWeight,
      'trustLevel': trustLevel,
      'role': role,
      'achievementIds': achievementIds,
      'teamIds': teamIds,
      'friendIds': friendIds,
      'followingIds': followingIds,
      'blockedIds': blockedIds,
      'privacySetting': privacySetting,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastActiveAt': lastActiveAt.millisecondsSinceEpoch,
    };
  }

  /// تحويل إلى Domain Entity
  Player toEntity() {
    return Player(
      id: id,
      name: name,
      username: username,
      photoUrl: photoUrl,
      photoThumbUrl: photoThumbUrl,
      photoFrame: photoFrame,
      qrCode: qrCode ?? '7reef://player/$id',
      phone: phone,
      position: position,
      rating: rating,
      totalMatches: totalMatches,
      wins: wins,
      draws: draws,
      losses: losses,
      mvpCount: mvpCount,
      trustWeight: trustWeight,
      trustLevel: _parseTrustLevel(trustLevel),
      role: _parseRole(role),
      achievementIds: achievementIds,
      teamIds: teamIds,
      friendIds: friendIds,
      followingIds: followingIds,
      blockedIds: blockedIds,
      privacySetting: privacySetting,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
    );
  }

  /// من Domain Entity إلى Model
  factory PlayerModel.fromEntity(Player player) {
    return PlayerModel(
      id: player.id,
      name: player.name,
      username: player.username,
      photoUrl: player.photoUrl,
      photoThumbUrl: player.photoThumbUrl,
      photoFrame: player.photoFrame,
      qrCode: player.qrCode ?? '7reef://player/${player.id}',
      phone: player.phone,
      position: player.position,
      rating: player.rating,
      totalMatches: player.totalMatches,
      wins: player.wins,
      draws: player.draws,
      losses: player.losses,
      mvpCount: player.mvpCount,
      trustWeight: player.trustWeight,
      trustLevel: player.trustLevel.name,
      role: player.role.name,
      achievementIds: player.achievementIds,
      teamIds: player.teamIds,
      friendIds: player.friendIds,
      followingIds: player.followingIds,
      blockedIds: player.blockedIds,
      privacySetting: player.privacySetting,
      createdAt: player.createdAt,
      lastActiveAt: player.lastActiveAt,
    );
  }

  static PlayerTrustLevel _parseTrustLevel(String value) {
    return PlayerTrustLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PlayerTrustLevel.newPlayer,
    );
  }

  static UserRole _parseRole(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.player,
    );
  }
}
