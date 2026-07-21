import '../../data/repositories/guest_player_repository_impl.dart';
import '../../domain/entities/participant_ref.dart';
import '../../domain/repositories/guest_player_repository.dart';

class ClaimedParticipantIdentityResolver {
  final GuestPlayerRepository _guestPlayerRepository;

  ClaimedParticipantIdentityResolver({
    GuestPlayerRepository? guestPlayerRepository,
  }) : _guestPlayerRepository =
           guestPlayerRepository ?? GuestPlayerRepositoryImpl();

  Future<ParticipantRef> resolve(ParticipantRef actor) async {
    final known = canonicalizeKnownLink(actor);
    if (!identical(known, actor)) return known;
    final resolved = await resolveAll([actor]);
    return resolved[_key(actor)] ?? actor;
  }

  static ParticipantRef canonicalizeKnownLink(ParticipantRef actor) {
    final linkedPlayerId = actor.linkedPlayerId?.trim();
    if (actor.kind != ParticipantRefKind.guestPlayer ||
        linkedPlayerId == null ||
        linkedPlayerId.isEmpty) {
      return actor;
    }
    return ParticipantRef(
      kind: ParticipantRefKind.player,
      id: linkedPlayerId,
      displayName: actor.displayName,
    );
  }

  Future<Map<String, ParticipantRef>> resolveAll(
    Iterable<ParticipantRef> actors,
  ) async {
    final distinctActors = <String, ParticipantRef>{
      for (final actor in actors) _key(actor): actor,
    };
    final guestIds = <String>{
      for (final actor in distinctActors.values)
        if (actor.kind == ParticipantRefKind.guestPlayer &&
            _linkedPlayerId(actor) == null)
          actor.id,
    };
    final linkedPlayerIds = <String, String>{};
    if (guestIds.isNotEmpty) {
      final guests = await _guestPlayerRepository.getGuestPlayersByIds(
        guestIds.toList(growable: false),
      );
      for (final guest in guests) {
        final linkedPlayerId = guest.linkedPlayerId?.trim();
        if (linkedPlayerId != null && linkedPlayerId.isNotEmpty) {
          linkedPlayerIds[guest.id] = linkedPlayerId;
        }
      }
    }
    return {
      for (final entry in distinctActors.entries)
        entry.key: _canonicalize(entry.value, linkedPlayerIds),
    };
  }

  ParticipantRef _canonicalize(
    ParticipantRef actor,
    Map<String, String> linkedPlayerIds,
  ) {
    if (actor.kind != ParticipantRefKind.guestPlayer) return actor;
    final known = canonicalizeKnownLink(actor);
    if (!identical(known, actor)) return known;
    final linkedPlayerId = linkedPlayerIds[actor.id];
    if (linkedPlayerId == null) return actor;
    return ParticipantRef(
      kind: ParticipantRefKind.player,
      id: linkedPlayerId,
      displayName: actor.displayName,
    );
  }

  String? _linkedPlayerId(ParticipantRef actor) {
    final value = actor.linkedPlayerId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String _key(ParticipantRef actor) => '${actor.kind.name}:${actor.id}';
}
