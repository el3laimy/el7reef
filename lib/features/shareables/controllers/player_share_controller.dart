import '../../../domain/entities/participant_ref.dart';
import '../../profile/models/public_player_profile_data.dart';
import '../models/player_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class PlayerShareController {
  const PlayerShareController();

  static const _payloadBuilder = PrideSharePayloadBuilder();

  PlayerShareData build({
    required PublicPlayerProfileData profile,
    String? tournamentId,
    String? matchId,
  }) {
    final displayName = _displayName(profile.displayName);
    return PlayerShareData(
      displayName: displayName,
      initials: _initials(displayName),
      photoUrl: _normalizedOptional(profile.photoUrl),
      totalGoals: profile.totalGoals,
      totalMvps: profile.totalMvps,
      isGuest: profile.isGuest,
      sharePayload: _payloadBuilder.player(
        actor: ParticipantRef(
          kind: profile.kind,
          id: profile.id,
          displayName: displayName,
        ),
        tournamentId: tournamentId,
        matchId: matchId,
      ),
    );
  }

  String _displayName(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'لاعب الحريف' : normalized;
  }

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _initials(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'ح';
    if (words.length == 1) return _take(words.first, 2);
    return '${_take(words.first, 1)}${_take(words[1], 1)}';
  }

  String _take(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);
}
