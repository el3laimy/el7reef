import '../../core/enums/player_trust_level.dart';
import '../../core/enums/user_role.dart';

/// كيان اللاعب — الكائن الأساسي في النظام
class Player {
  final String id;
  final String name;
  final String? username;        // RULE-01: فريد عالمياً — يبدأ null حتى يُختار
  final String? photoUrl;
  final String? photoThumbUrl;  // نسخة مصغرة للقوائم
  final String? photoFrame;     // newcomer / bronze / silver / elite / champion / star
  final String? qrCode;         // '7reef://player/{id}'
  final String? phone;
  final String? position;       // GK, DEF, MID, FWD
  final int rating;
  final int totalMatches;
  final int wins;
  final int draws;
  final int losses;
  final int mvpCount;
  final double trustWeight;
  final PlayerTrustLevel trustLevel;
  final UserRole role;
  final List<String> achievementIds;
  final List<String> teamIds;
  final List<String> friendIds;       // علاقات مؤكدة
  final List<String> followingIds;    // أحادية — أنت تتابعهم
  final List<String> blockedIds;      // حجب كامل
  final String privacySetting;        // public | friends_only | private
  final bool isGuest;                 // Phase 4: هل هو لاعب ضيف؟
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const Player({
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
    this.trustLevel = PlayerTrustLevel.newPlayer,
    this.role = UserRole.player,
    this.achievementIds = const [],
    this.teamIds = const [],
    this.friendIds = const [],
    this.followingIds = const [],
    this.blockedIds = const [],
    this.privacySetting = 'public',
    this.isGuest = false,
    required this.createdAt,
    required this.lastActiveAt,
  });

  /// نسبة الفوز
  double get winRate =>
      totalMatches > 0 ? (wins / totalMatches) * 100 : 0;

  /// هل اللاعب جديد؟
  bool get isNewPlayer => totalMatches < 5;

  /// هل اللاعب منظم؟
  bool get isOrganizer => role == UserRole.organizer;

  /// هل له username مضبوط؟
  bool get hasUsername => username != null && username!.isNotEmpty;

  /// اسم العرض المفضل
  String get displayUsername => username != null ? '@$username' : name;

  /// نسخة معدلة من اللاعب
  Player copyWith({
    String? id,
    String? name,
    String? username,
    String? photoUrl,
    String? photoThumbUrl,
    String? photoFrame,
    String? qrCode,
    String? phone,
    String? position,
    int? rating,
    int? totalMatches,
    int? wins,
    int? draws,
    int? losses,
    int? mvpCount,
    double? trustWeight,
    PlayerTrustLevel? trustLevel,
    UserRole? role,
    List<String>? achievementIds,
    List<String>? teamIds,
    List<String>? friendIds,
    List<String>? followingIds,
    List<String>? blockedIds,
    String? privacySetting,
    bool? isGuest,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      photoThumbUrl: photoThumbUrl ?? this.photoThumbUrl,
      photoFrame: photoFrame ?? this.photoFrame,
      qrCode: qrCode ?? this.qrCode,
      phone: phone ?? this.phone,
      position: position ?? this.position,
      rating: rating ?? this.rating,
      totalMatches: totalMatches ?? this.totalMatches,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      mvpCount: mvpCount ?? this.mvpCount,
      trustWeight: trustWeight ?? this.trustWeight,
      trustLevel: trustLevel ?? this.trustLevel,
      role: role ?? this.role,
      achievementIds: achievementIds ?? this.achievementIds,
      teamIds: teamIds ?? this.teamIds,
      friendIds: friendIds ?? this.friendIds,
      followingIds: followingIds ?? this.followingIds,
      blockedIds: blockedIds ?? this.blockedIds,
      privacySetting: privacySetting ?? this.privacySetting,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
