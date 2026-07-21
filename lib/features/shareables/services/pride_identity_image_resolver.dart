import 'dart:async';

import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/participant_ref.dart';

const Duration prideIdentityLookupTimeout = Duration(seconds: 2);

class PrideIdentityImageResolver {
  PlayerRepositoryImpl? _playerRepository;

  PrideIdentityImageResolver({PlayerRepositoryImpl? playerRepository})
    : _playerRepository = playerRepository;

  Future<String?> imageUrlFor(ParticipantRef actor) async {
    if (actor.kind != ParticipantRefKind.player) return null;
    final player = await (_playerRepository ??= PlayerRepositoryImpl())
        .getPlayer(actor.id)
        .timeout(prideIdentityLookupTimeout);
    return _normalizedOptional(player?.photoThumbUrl) ??
        _normalizedOptional(player?.photoUrl);
  }

  Future<Map<String, String?>> imageUrlsFor(
    Iterable<ParticipantRef> actors,
  ) async {
    final distinctActors = <String, ParticipantRef>{
      for (final actor in actors) identityKey(actor): actor,
    };
    final entries = await Future.wait(
      distinctActors.entries.map((entry) async {
        try {
          return MapEntry(entry.key, await imageUrlFor(entry.value));
        } catch (_) {
          return MapEntry(entry.key, null);
        }
      }),
    );
    return Map<String, String?>.fromEntries(entries);
  }

  static String identityKey(ParticipantRef actor) =>
      '${actor.kind.name}:${actor.id}';

  String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
