import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/enums/tournament_ops_enums.dart';
import '../../data/models/match_lineup_snapshot_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/tournament_participant_model.dart';
import '../../data/repositories/guest_player_repository_impl.dart';
import '../../data/repositories/match_side_player_repository_impl.dart';
import '../../data/repositories/match_side_repository_impl.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../data/repositories/team_membership_repository_impl.dart';
import '../../domain/entities/guest_player.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_lineup_snapshot.dart';
import '../../domain/entities/match_participant_roster.dart';
import '../../domain/entities/match_side.dart';
import '../../domain/entities/match_side_player.dart';
import '../../domain/entities/participant_ref.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/team_membership.dart';
import '../../domain/entities/tournament_participant.dart';
import '../../domain/repositories/guest_player_repository.dart';
import '../../domain/repositories/team_membership_repository.dart';

class OfficialMatchRegisteredRoster {
  final Match match;
  final List<String> teamAPlayerIds;
  final List<String> teamBPlayerIds;
  final List<Player> teamAPlayers;
  final List<Player> teamBPlayers;

  const OfficialMatchRegisteredRoster({
    required this.match,
    required this.teamAPlayerIds,
    required this.teamBPlayerIds,
    required this.teamAPlayers,
    required this.teamBPlayers,
  });

  List<String> get allPlayerIds =>
      <String>{...teamAPlayerIds, ...teamBPlayerIds}.toList(growable: false);
}

class OfficialMatchRosterService {
  final FirebaseFirestore _firestore;
  final PlayerRepositoryImpl _playerRepository;
  final GuestPlayerRepository _guestPlayerRepository;
  final TeamMembershipRepository _membershipRepository;
  final MatchSideRepositoryImpl _matchSideRepository;
  final MatchSidePlayerRepositoryImpl _matchSidePlayerRepository;

  OfficialMatchRosterService({
    FirebaseFirestore? firestore,
    PlayerRepositoryImpl? playerRepository,
    GuestPlayerRepository? guestPlayerRepository,
    TeamMembershipRepository? membershipRepository,
    MatchSideRepositoryImpl? matchSideRepository,
    MatchSidePlayerRepositoryImpl? matchSidePlayerRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _playerRepository =
           playerRepository ?? PlayerRepositoryImpl(firestore: firestore),
       _guestPlayerRepository =
           guestPlayerRepository ??
           GuestPlayerRepositoryImpl(firestore: firestore),
       _membershipRepository =
           membershipRepository ??
           TeamMembershipRepositoryImpl(firestore: firestore),
       _matchSideRepository =
           matchSideRepository ?? MatchSideRepositoryImpl(firestore: firestore),
       _matchSidePlayerRepository =
           matchSidePlayerRepository ??
           MatchSidePlayerRepositoryImpl(firestore: firestore);

  CollectionReference<Map<String, dynamic>> get _matchesRef =>
      _firestore.collection(FirebasePaths.matches);
  CollectionReference<Map<String, dynamic>> get _snapshotsRef =>
      _firestore.collection(FirebasePaths.matchLineupSnapshots);
  CollectionReference<Map<String, dynamic>> get _participantsRef =>
      _firestore.collection(FirebasePaths.tournamentParticipants);

  Future<OfficialMatchRegisteredRoster> loadRegisteredRoster({
    required String matchId,
    Match? match,
  }) async {
    final effectiveMatch = match ?? await _loadMatch(matchId);
    final snapshots = await _loadSnapshots(effectiveMatch.id);

    final teamAIds = _resolveSidePlayerIds(
      snapshots: snapshots,
      sideEntityId: effectiveMatch.teamAId,
      fallbackIds: effectiveMatch.teamAPlayerIds,
    );
    final teamBIds = _resolveSidePlayerIds(
      snapshots: snapshots,
      sideEntityId: effectiveMatch.teamBId,
      fallbackIds: effectiveMatch.teamBPlayerIds,
    );

    final allPlayers = await _playerRepository.getPlayersByIds(<String>[
      ...teamAIds,
      ...teamBIds,
    ]);
    final playersById = <String, Player>{
      for (final player in allPlayers) player.id: player,
    };

    return OfficialMatchRegisteredRoster(
      match: effectiveMatch,
      teamAPlayerIds: teamAIds,
      teamBPlayerIds: teamBIds,
      teamAPlayers: teamAIds
          .map((playerId) => playersById[playerId])
          .whereType<Player>()
          .toList(growable: false),
      teamBPlayers: teamBIds
          .map((playerId) => playersById[playerId])
          .whereType<Player>()
          .toList(growable: false),
    );
  }

  Future<MatchParticipantRoster> loadParticipantRoster({
    required String matchId,
    Match? match,
  }) async {
    final effectiveMatch = match ?? await _loadMatch(matchId);
    final snapshots = await _loadSnapshots(effectiveMatch.id);
    final matchSides = await _matchSideRepository.getMatchSides(
      effectiveMatch.id,
    );
    final matchSidePlayers = await _matchSidePlayerRepository.getMatchPlayers(
      effectiveMatch.id,
    );
    final sideAContext = await _buildSideContext(
      match: effectiveMatch,
      sideKey: 'A',
      snapshots: snapshots,
      matchSides: matchSides,
      matchSidePlayers: matchSidePlayers,
    );
    final sideBContext = await _buildSideContext(
      match: effectiveMatch,
      sideKey: 'B',
      snapshots: snapshots,
      matchSides: matchSides,
      matchSidePlayers: matchSidePlayers,
    );

    final playerIds = <String>{
      ...sideAContext.playerIds,
      ...sideBContext.playerIds,
    }.toList(growable: false);
    final guestPlayerIds = <String>{
      ...sideAContext.guestPlayerIds,
      ...sideBContext.guestPlayerIds,
    }.toList(growable: false);
    final playersById = {
      for (final player in await _playerRepository.getPlayersByIds(playerIds))
        player.id: player,
    };
    final guestPlayersById = {
      for (final guestPlayer
          in await _guestPlayerRepository.getGuestPlayersByIds(guestPlayerIds))
        guestPlayer.id: guestPlayer,
    };

    return MatchParticipantRoster(
      match: effectiveMatch,
      sideA: _resolveParticipantRefs(
        sideAContext,
        playersById,
        guestPlayersById,
      ),
      sideB: _resolveParticipantRefs(
        sideBContext,
        playersById,
        guestPlayersById,
      ),
    );
  }

  Future<Match> _loadMatch(String matchId) async {
    final snapshot = await _matchesRef.doc(matchId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('المباراة غير موجودة');
    }
    return MatchModel.fromJson(snapshot.data()!, snapshot.id).toEntity();
  }

  Future<List<MatchLineupSnapshot>> _loadSnapshots(String matchId) async {
    final snapshot = await _snapshotsRef
        .where('matchId', isEqualTo: matchId)
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              MatchLineupSnapshotModel.fromJson(doc.data(), doc.id).toEntity(),
        )
        .toList(growable: false);
  }

  List<String> _resolveSidePlayerIds({
    required List<MatchLineupSnapshot> snapshots,
    required String? sideEntityId,
    required List<String> fallbackIds,
  }) {
    final snapshot = _findSnapshotForSide(
      snapshots: snapshots,
      sideEntityId: sideEntityId,
    );
    if (snapshot == null) {
      return _normalizeIds(fallbackIds);
    }

    // V1 official rating/stat/fan-voting roster is registered-player only.
    // Guest-only lineup snapshots intentionally project to an empty eligible
    // roster; guest players remain display-only until they are claimed later.
    return _projectRegisteredPlayerIds(snapshot);
  }

  MatchLineupSnapshot? _findSnapshotForSide({
    required List<MatchLineupSnapshot> snapshots,
    required String? sideEntityId,
  }) {
    if (sideEntityId == null || sideEntityId.isEmpty) {
      return null;
    }
    for (final snapshot in snapshots) {
      if (snapshot.teamId == sideEntityId ||
          snapshot.guestTeamId == sideEntityId) {
        return snapshot;
      }
    }
    return null;
  }

  List<String> _projectRegisteredPlayerIds(MatchLineupSnapshot snapshot) {
    final ids = <String>[];
    for (final entry in [...snapshot.starters, ...snapshot.bench]) {
      final playerId = entry.playerId;
      if (playerId == null ||
          playerId.trim().isEmpty ||
          ids.contains(playerId)) {
        continue;
      }
      ids.add(playerId);
    }
    return ids;
  }

  List<String> _normalizeIds(List<String> ids) {
    return ids
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<_ParticipantSideContext> _buildSideContext({
    required Match match,
    required String sideKey,
    required List<MatchLineupSnapshot> snapshots,
    required List<MatchSide> matchSides,
    required List<MatchSidePlayer> matchSidePlayers,
  }) async {
    final normalizedSide = sideKey.trim().toUpperCase();
    final sideEntityId = normalizedSide == 'A' ? match.teamAId : match.teamBId;
    final fallbackPlayerIds = normalizedSide == 'A'
        ? match.teamAPlayerIds
        : match.teamBPlayerIds;
    final participantId = normalizedSide == 'A'
        ? match.teamAParticipantId
        : match.teamBParticipantId;
    final snapshot = _findFullSnapshotForSide(
      snapshots: snapshots,
      sideKey: normalizedSide,
      sideEntityId: sideEntityId,
      matchSides: matchSides,
    );
    final sidePlayers = matchSidePlayers
        .where(
          (player) => player.sideKey.trim().toUpperCase() == normalizedSide,
        )
        .toList(growable: false);
    final entries = <_ParticipantCandidate>[];

    if (snapshot != null) {
      entries.addAll(_candidatesFromSnapshot(snapshot, sidePlayers));
    } else {
      entries.addAll(
        fallbackPlayerIds.map(
          (playerId) => _ParticipantCandidate.player(playerId),
        ),
      );
      entries.addAll(
        await _candidatesFromOfficialRoster(
          sideEntityId: sideEntityId,
          participantId: participantId,
        ),
      );
    }

    entries.addAll(
      sidePlayers.map((player) => _candidateFromMatchSidePlayer(player)),
    );

    return _ParticipantSideContext(candidates: entries);
  }

  MatchLineupSnapshot? _findFullSnapshotForSide({
    required List<MatchLineupSnapshot> snapshots,
    required String sideKey,
    required String? sideEntityId,
    required List<MatchSide> matchSides,
  }) {
    for (final snapshot in snapshots) {
      if (snapshot.sideKey?.trim().toUpperCase() == sideKey) {
        return snapshot;
      }
    }

    final matchSide = matchSides.cast<MatchSide?>().firstWhere(
      (side) => side?.sideKey.trim().toUpperCase() == sideKey,
      orElse: () => null,
    );
    final matchSideId = matchSide?.id;

    for (final snapshot in snapshots) {
      if (sideEntityId != null &&
          sideEntityId.isNotEmpty &&
          (snapshot.teamId == sideEntityId ||
              snapshot.guestTeamId == sideEntityId)) {
        return snapshot;
      }
      if (matchSideId != null && snapshot.matchSideId == matchSideId) {
        return snapshot;
      }
    }
    return null;
  }

  List<_ParticipantCandidate> _candidatesFromSnapshot(
    MatchLineupSnapshot snapshot,
    List<MatchSidePlayer> sidePlayers,
  ) {
    final sidePlayersById = {
      for (final sidePlayer in sidePlayers) sidePlayer.id: sidePlayer,
    };
    return [...snapshot.starters, ...snapshot.bench]
        .map((entry) {
          final displayName = _nonEmpty(entry.displayName);
          final playerId = _nonEmpty(entry.playerId);
          if (playerId != null) {
            return _ParticipantCandidate.player(
              playerId,
              fallbackDisplayName: displayName,
            );
          }
          final guestPlayerId = _nonEmpty(entry.guestPlayerId);
          if (guestPlayerId != null) {
            return _ParticipantCandidate.guestPlayer(
              guestPlayerId,
              fallbackDisplayName: displayName,
            );
          }
          final matchSidePlayerId = _nonEmpty(entry.matchSidePlayerId);
          if (matchSidePlayerId != null) {
            final sidePlayer = sidePlayersById[matchSidePlayerId];
            final sidePlayerRegisteredId = _nonEmpty(sidePlayer?.playerId);
            if (sidePlayerRegisteredId != null) {
              return _ParticipantCandidate.player(
                sidePlayerRegisteredId,
                fallbackDisplayName:
                    _nonEmpty(sidePlayer?.displayName) ?? displayName,
              );
            }
            return _ParticipantCandidate.matchSidePlayer(
              matchSidePlayerId,
              fallbackDisplayName:
                  _nonEmpty(sidePlayer?.displayName) ?? displayName,
            );
          }
          return null;
        })
        .whereType<_ParticipantCandidate>()
        .toList(growable: false);
  }

  Future<List<_ParticipantCandidate>> _candidatesFromOfficialRoster({
    required String? sideEntityId,
    required String? participantId,
  }) async {
    final entityId = _nonEmpty(sideEntityId);
    if (entityId == null) {
      return const <_ParticipantCandidate>[];
    }

    final participant = await _loadParticipant(participantId);
    if (participant?.sourceType == TournamentParticipantSourceType.guestTeam) {
      final guestPlayers = await _guestPlayerRepository.getGuestTeamPlayers(
        entityId,
      );
      return guestPlayers
          .map(
            (guestPlayer) => _ParticipantCandidate.guestPlayer(guestPlayer.id),
          )
          .toList(growable: false);
    }

    final memberships = await _membershipRepository.getTeamMemberships(
      entityId,
    );
    return memberships
        .map((membership) => _candidateFromMembership(membership))
        .whereType<_ParticipantCandidate>()
        .toList(growable: false);
  }

  Future<TournamentParticipant?> _loadParticipant(String? participantId) async {
    final normalizedId = _nonEmpty(participantId);
    if (normalizedId == null) {
      return null;
    }
    final snapshot = await _participantsRef.doc(normalizedId).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return TournamentParticipantModel.fromJson(
      snapshot.data()!,
      snapshot.id,
    ).toEntity();
  }

  _ParticipantCandidate? _candidateFromMembership(TeamMembership membership) {
    final playerId = _nonEmpty(membership.playerId);
    if (playerId != null) {
      return _ParticipantCandidate.player(playerId);
    }
    final guestPlayerId = _nonEmpty(membership.guestPlayerId);
    if (guestPlayerId != null) {
      return _ParticipantCandidate.guestPlayer(guestPlayerId);
    }
    return null;
  }

  _ParticipantCandidate _candidateFromMatchSidePlayer(MatchSidePlayer player) {
    final playerId = _nonEmpty(player.playerId);
    if (playerId != null) {
      return _ParticipantCandidate.player(
        playerId,
        fallbackDisplayName: _nonEmpty(player.displayName),
      );
    }
    return _ParticipantCandidate.matchSidePlayer(
      player.id,
      fallbackDisplayName: _nonEmpty(player.displayName),
    );
  }

  List<ParticipantRef> _resolveParticipantRefs(
    _ParticipantSideContext context,
    Map<String, Player> playersById,
    Map<String, GuestPlayer> guestPlayersById,
  ) {
    final participants = <ParticipantRef>[];
    final seen = <String>{};
    for (final candidate in context.candidates) {
      final participant = _resolveParticipantRef(
        candidate,
        playersById,
        guestPlayersById,
      );
      if (participant == null) {
        continue;
      }
      if (seen.add(participantRosterKey(participant))) {
        participants.add(participant);
      }
    }
    return participants;
  }

  ParticipantRef? _resolveParticipantRef(
    _ParticipantCandidate candidate,
    Map<String, Player> playersById,
    Map<String, GuestPlayer> guestPlayersById,
  ) {
    switch (candidate.kind) {
      case ParticipantRefKind.player:
        final player = playersById[candidate.id];
        final displayName = _nonEmpty(player?.name) ?? candidate.displayName;
        if (displayName == null) {
          return null;
        }
        return ParticipantRef(
          kind: ParticipantRefKind.player,
          id: candidate.id,
          displayName: displayName,
        );
      case ParticipantRefKind.guestPlayer:
        final guestPlayer = guestPlayersById[candidate.id];
        final displayName =
            _nonEmpty(guestPlayer?.displayName) ?? candidate.displayName;
        if (displayName == null) {
          return null;
        }
        return ParticipantRef(
          kind: ParticipantRefKind.guestPlayer,
          id: candidate.id,
          displayName: displayName,
          linkedPlayerId: _nonEmpty(guestPlayer?.linkedPlayerId),
        );
      case ParticipantRefKind.matchSidePlayer:
        final displayName = candidate.displayName;
        if (displayName == null) {
          return null;
        }
        return ParticipantRef(
          kind: ParticipantRefKind.matchSidePlayer,
          id: candidate.id,
          displayName: displayName,
        );
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class _ParticipantSideContext {
  final List<_ParticipantCandidate> candidates;

  const _ParticipantSideContext({required this.candidates});

  List<String> get playerIds => candidates
      .where((candidate) => candidate.kind == ParticipantRefKind.player)
      .map((candidate) => candidate.id)
      .toList(growable: false);

  List<String> get guestPlayerIds => candidates
      .where((candidate) => candidate.kind == ParticipantRefKind.guestPlayer)
      .map((candidate) => candidate.id)
      .toList(growable: false);
}

class _ParticipantCandidate {
  final ParticipantRefKind kind;
  final String id;
  final String? displayName;

  const _ParticipantCandidate({
    required this.kind,
    required this.id,
    this.displayName,
  });

  factory _ParticipantCandidate.player(
    String id, {
    String? fallbackDisplayName,
  }) {
    return _ParticipantCandidate(
      kind: ParticipantRefKind.player,
      id: id,
      displayName: fallbackDisplayName,
    );
  }

  factory _ParticipantCandidate.guestPlayer(
    String id, {
    String? fallbackDisplayName,
  }) {
    return _ParticipantCandidate(
      kind: ParticipantRefKind.guestPlayer,
      id: id,
      displayName: fallbackDisplayName,
    );
  }

  factory _ParticipantCandidate.matchSidePlayer(
    String id, {
    String? fallbackDisplayName,
  }) {
    return _ParticipantCandidate(
      kind: ParticipantRefKind.matchSidePlayer,
      id: id,
      displayName: fallbackDisplayName,
    );
  }
}
