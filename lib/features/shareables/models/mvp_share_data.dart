import 'package:flutter/foundation.dart';

@immutable
class MvpShareData {
  final String title;
  final String mvpDisplayName;
  final bool isGuest;
  final String tournamentName;
  final String? scoreLine;
  final String? sideLabel;
  final String brandLabel;

  const MvpShareData({
    required this.title,
    required this.mvpDisplayName,
    required this.isGuest,
    required this.tournamentName,
    this.scoreLine,
    this.sideLabel,
    this.brandLabel = 'الحريف',
  });
}
