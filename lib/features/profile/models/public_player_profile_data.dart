import '../../../domain/entities/participant_ref.dart';

class PublicPlayerProfileData {
  final ParticipantRefKind kind;
  final String id;
  final String displayName;
  final int totalGoals;
  final int totalMvps;
  final String? linkedPlayerId;
  final bool isClaimed;

  const PublicPlayerProfileData({
    required this.kind,
    required this.id,
    required this.displayName,
    required this.totalGoals,
    required this.totalMvps,
    this.linkedPlayerId,
    this.isClaimed = false,
  });

  bool get isGuest => kind == ParticipantRefKind.guestPlayer;
  String get badgeLabel => isGuest ? 'ضيف' : 'لاعب';
  bool get showClaimPlaceholder => isGuest && !isClaimed;
}
