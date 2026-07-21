import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

@immutable
class PlayerShareData {
  final String displayName;
  final String initials;
  final String? photoUrl;
  final int totalGoals;
  final int totalMvps;
  final bool isGuest;
  final SharePayload sharePayload;

  const PlayerShareData({
    required this.displayName,
    required this.initials,
    this.photoUrl,
    required this.totalGoals,
    required this.totalMvps,
    required this.isGuest,
    required this.sharePayload,
  });
}
