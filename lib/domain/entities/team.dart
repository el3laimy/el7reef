/// كيان الفريق — فريق مسجل رقمياً للمشاركة في الدورات
class Team {
  final String id;
  final String name;
  final String? logoUrl;
  final String ownerId;
  final List<String> viceCaptainIds;
  final List<String> playerIds; // Includes owner, viceCaptains, and regular players
  final List<String> invitedIds;
  final double avgRating;
  final List<String> tournamentIds;
  final int wins;
  final int draws;
  final int losses;
  final DateTime createdAt;

  const Team({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.ownerId,
    this.viceCaptainIds = const [],
    this.playerIds = const [],
    this.invitedIds = const [],
    this.avgRating = 1000.0,
    this.tournamentIds = const [],
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    required this.createdAt,
  });

  int get totalMatches => wins + draws + losses;
  int get playerCount => playerIds.length;

  Team copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? ownerId,
    List<String>? viceCaptainIds,
    List<String>? playerIds,
    List<String>? invitedIds,
    double? avgRating,
    List<String>? tournamentIds,
    int? wins,
    int? draws,
    int? losses,
    DateTime? createdAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      ownerId: ownerId ?? this.ownerId,
      viceCaptainIds: viceCaptainIds ?? this.viceCaptainIds,
      playerIds: playerIds ?? this.playerIds,
      invitedIds: invitedIds ?? this.invitedIds,
      avgRating: avgRating ?? this.avgRating,
      tournamentIds: tournamentIds ?? this.tournamentIds,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
