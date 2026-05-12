part of 'tournament_operations_controller.dart';

extension TournamentParticipantOps on TournamentOperationsController {
  Future<void> syncApprovedRegistrations() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    if (!_ensureCanManageTournament()) {
      return;
    }
    await _runAction(
      message: 'تمت مزامنة التسجيلات المعتمدة مع participants.',
      action: () => _migrationService.backfillTournament(tournamentId: id),
      onSuccess: (_) => _refreshParticipantsOnly(refreshTournament: true),
    );
  }

  Future<void> finalizeParticipantList() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم قفل قائمة المشاركين بنجاح.',
      action: () => _lifecycleService.finalizeParticipants(
        tournamentId: id,
        actorId: actorId,
      ),
      onSuccess: (finalizedParticipants) async {
        _applyParticipants(finalizedParticipants);
        await _refreshTournamentOnly();
      },
    );
  }

  Future<void> withdrawParticipant(String participantId) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم سحب المشارك من البطولة.',
      action: () => _participantService.withdrawParticipant(
        participantId: participantId,
        actorId: actorId,
      ),
      onSuccess: (updatedParticipant) async {
        _upsertParticipant(updatedParticipant);
      },
    );
  }

  Future<void> reactivateParticipant(String participantId) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تمت إعادة تفعيل المشارك بنجاح.',
      action: () => _participantService.reactivateParticipant(
        participantId: participantId,
        actorId: actorId,
      ),
      onSuccess: (result) async {
        _upsertParticipants(<TournamentParticipant>[
          result.reactivatedParticipant,
          if (result.withdrawnReplacement != null)
            result.withdrawnReplacement!,
        ]);
        _syncTournamentParticipantCountLocal(
          overrideCount: result.activeParticipantCount,
        );
      },
    );
  }

  Future<void> addManualParticipant({
    required TournamentParticipantSourceType sourceType,
    required String sourceEntityId,
  }) async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      return;
    }
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تمت إضافة participant يدويًا إلى البطولة.',
      action: () => _participantService.addManualParticipant(
        tournamentId: id,
        sourceType: sourceType,
        sourceEntityId: sourceEntityId,
        actorId: actorId,
      ),
      onSuccess: (participant) async {
        _upsertParticipant(participant);
      },
    );
  }

  Future<void> replaceParticipant({
    required String participantId,
    required TournamentParticipantSourceType replacementSourceType,
    required String replacementSourceEntityId,
  }) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: 'تم استبدال participant بنجاح.',
      action: () => _participantService.replaceParticipant(
        participantId: participantId,
        replacementSourceType: replacementSourceType,
        replacementSourceEntityId: replacementSourceEntityId,
        actorId: actorId,
      ),
      onSuccess: (result) async {
        _upsertParticipants(<TournamentParticipant>[
          result.replacedParticipant,
          result.replacementParticipant,
        ]);
        _syncTournamentParticipantCountLocal(
          overrideCount: result.activeParticipantCount,
        );
      },
    );
  }

  Future<void> updateParticipantSeed({
    required String participantId,
    int? seed,
  }) async {
    final actorId = _currentTournamentManagerActorId();
    if (actorId == null) return;
    await _runAction(
      message: seed == null
          ? 'تم حذف seed الخاصة بالمشارك.'
          : 'تم تحديث seed الخاصة بالمشارك.',
      action: () => _participantService.updateParticipantSeed(
        participantId: participantId,
        actorId: actorId,
        seed: seed,
      ),
      onSuccess: (updatedParticipant) async {
        _upsertParticipant(updatedParticipant);
      },
    );
  }

  Future<List<TournamentParticipantCandidate>> searchParticipantCandidates({
    required String query,
    required TournamentParticipantSourceType sourceType,
    TournamentParticipant? replacingParticipant,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <TournamentParticipantCandidate>[];
    }

    final blockedKeys = participants
        .where((participant) => participant.id != replacingParticipant?.id)
        .map(
          (participant) =>
              '${participant.sourceType.name}::${participant.sourceEntityId}',
        )
        .toSet();

    final cacheKey = '${sourceType.name}::${normalizedQuery.toLowerCase()}';
    final now = DateTime.now();
    final cached = _participantSearchCache[cacheKey];
    final baseCandidates = cached != null &&
            now.difference(cached.cachedAt) <= TournamentOperationsController._participantSearchCacheTtl
        ? cached.candidates
        : await _loadParticipantCandidates(
            normalizedQuery: normalizedQuery,
            sourceType: sourceType,
          );

    if (cached == null ||
        now.difference(cached.cachedAt) > TournamentOperationsController._participantSearchCacheTtl) {
      _participantSearchCache[cacheKey] = _ParticipantCandidateCacheEntry(
        cachedAt: now,
        candidates: baseCandidates,
      );
    }

    return baseCandidates
        .where((candidate) {
          final key =
              '${candidate.sourceType.name}::${candidate.sourceEntityId}';
          if (blockedKeys.contains(key)) {
            return false;
          }
          if (replacingParticipant == null) {
            return true;
          }
          return !(candidate.sourceType == replacingParticipant.sourceType &&
              candidate.sourceEntityId ==
                  replacingParticipant.sourceEntityId);
        })
        .toList(growable: false);
  }

  Future<List<TournamentParticipantCandidate>> _loadParticipantCandidates({
    required String normalizedQuery,
    required TournamentParticipantSourceType sourceType,
  }) async {
    switch (sourceType) {
      case TournamentParticipantSourceType.registeredTeam:
        final teams = await _teamRepository.searchTeams(normalizedQuery);
        return teams
            .map(
              (team) => TournamentParticipantCandidate(
                sourceType: sourceType,
                sourceEntityId: team.id,
                displayName: team.name,
              ),
            )
            .toList(growable: false);
      case TournamentParticipantSourceType.guestTeam:
        final guestTeams =
            await _guestTeamRepository.searchGuestTeams(normalizedQuery);
        return guestTeams
            .map(
              (guestTeam) => TournamentParticipantCandidate(
                sourceType: sourceType,
                sourceEntityId: guestTeam.id,
                displayName: guestTeam.name,
              ),
            )
            .toList(growable: false);
    }
  }
}
