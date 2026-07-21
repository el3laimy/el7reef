import 'package:flutter/foundation.dart';

import '../../../domain/entities/share_payload.dart';

@immutable
class MvpShareData {
  final String title;
  final String mvpDisplayName;
  final bool isGuest;
  final String? tournamentName;
  final String? photoUrl;
  final String initials;
  final String? scoreLine;
  final String? sideLabel;
  final String brandLabel;
  final SharePayload? sharePayload;

  const MvpShareData({
    required this.title,
    required this.mvpDisplayName,
    required this.isGuest,
    this.tournamentName,
    this.photoUrl,
    this.initials = 'ح',
    this.scoreLine,
    this.sideLabel,
    this.brandLabel = 'الحريف',
    this.sharePayload,
  });

  MvpShareData copyWith({SharePayload? sharePayload}) {
    return MvpShareData(
      title: title,
      mvpDisplayName: mvpDisplayName,
      isGuest: isGuest,
      tournamentName: tournamentName,
      photoUrl: photoUrl,
      initials: initials,
      scoreLine: scoreLine,
      sideLabel: sideLabel,
      brandLabel: brandLabel,
      sharePayload: sharePayload ?? this.sharePayload,
    );
  }
}
