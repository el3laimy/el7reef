import 'package:flutter/foundation.dart';

@immutable
class PublicTeamProfileData {
  final String kind;
  final String id;
  final String name;
  final String? logoUrl;
  final int? playerCount;
  final int? wins;
  final int? totalMatches;

  const PublicTeamProfileData({
    required this.kind,
    required this.id,
    required this.name,
    this.logoUrl,
    this.playerCount,
    this.wins,
    this.totalMatches,
  });

  bool get isGuestTeam => kind == 'guestTeam';
  String get kindLabel => isGuestTeam ? 'فريق ضيف' : 'فريق مسجل';
}
