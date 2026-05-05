import 'package:flutter/foundation.dart';

@immutable
class TopScorersShareEntryData {
  final int rank;
  final String displayName;
  final int goals;
  final bool isGuest;

  const TopScorersShareEntryData({
    required this.rank,
    required this.displayName,
    required this.goals,
    required this.isGuest,
  });

  String get goalLabel => goals == 1 ? '1 هدف' : '$goals أهداف';
}

@immutable
class TopScorersShareData {
  final String title;
  final String tournamentName;
  final List<TopScorersShareEntryData> scorers;
  final String brandLabel;

  const TopScorersShareData({
    required this.title,
    required this.tournamentName,
    required this.scorers,
    this.brandLabel = 'الحريف',
  });
}
