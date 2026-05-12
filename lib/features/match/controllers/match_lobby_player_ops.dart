part of 'match_lobby_controller.dart';

extension MatchLobbyPlayerOps on MatchLobbyController {
  Future<void> addRegisteredPlayerToSide({
    required String playerId,
    required String sideKey,
  }) async {
    final m = match.value;
    final normalizedSide = sideKey.trim().toUpperCase();
    if (m == null) return;
    if (playerId.trim().isEmpty) {
      Get.snackbar('بيانات ناقصة', 'اختر لاعبًا مسجلًا أولاً.');
      return;
    }
    if (m.tournamentId != null) {
      Get.snackbar('غير متاح', 'إدارة أطراف البطولة تتم من مسار البطولة.');
      return;
    }
    if (!isOrganizer) {
      Get.snackbar('غير مسموح', 'منظم المباراة فقط يمكنه تعديل الأطراف.');
      return;
    }
    if (normalizedSide != 'A' && normalizedSide != 'B') {
      Get.snackbar('خطأ', 'طرف المباراة غير صحيح.');
      return;
    }
    if (m.status != MatchStatus.open && m.status != MatchStatus.full) {
      Get.snackbar('غير متاح', 'لا يمكن تعديل اللاعبين بعد بدء المباراة.');
      return;
    }
    final targetPlayers = normalizedSide == 'A'
        ? m.teamAPlayerIds
        : m.teamBPlayerIds;
    final oppositePlayers = normalizedSide == 'A'
        ? m.teamBPlayerIds
        : m.teamAPlayerIds;
    if (targetPlayers.contains(playerId)) {
      Get.snackbar('موجود بالفعل', 'هذا اللاعب موجود بالفعل في هذا الفريق.');
      return;
    }
    if (oppositePlayers.contains(playerId)) {
      Get.snackbar('موجود بالفعل', 'هذا اللاعب موجود بالفعل في الفريق الآخر.');
      return;
    }

    try {
      final updated = normalizedSide == 'A'
          ? m.copyWith(teamAPlayerIds: [...m.teamAPlayerIds, playerId])
          : m.copyWith(teamBPlayerIds: [...m.teamBPlayerIds, playerId]);
      await _matchRepo.updateMatch(updated);
      match.value = updated;
      await Future.wait([
        _loadPlayers(updated),
        _loadSideViews(updated),
        _loadSnapshotState(),
      ]);
      if (currentUserId != null) {
        startReadiness.value = await _matchStartService.getStartReadiness(
          matchId: matchId,
          actorId: currentUserId!,
        );
      }
      Get.snackbar(
        'تمت الإضافة',
        'تمت إضافة اللاعب إلى فريق $normalizedSide.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.addRegisteredPlayerToSide', e);
      Get.snackbar('خطأ', 'فشل إضافة اللاعب');
    }
  }

  Future<void> renameTemporarySide({
    required String sideKey,
    required String displayName,
  }) async {
    final m = match.value;
    final actorId = currentUserId;
    final normalizedSide = sideKey.trim().toUpperCase();
    final trimmedName = displayName.trim();
    if (m == null) return;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    if (m.tournamentId != null) {
      Get.snackbar('غير متاح', 'تسمية الأطراف المؤقتة متاحة للوديات فقط.');
      return;
    }
    if (!isOrganizer) {
      Get.snackbar('غير مسموح', 'منظم المباراة فقط يمكنه تسمية الأطراف.');
      return;
    }
    if (normalizedSide != 'A' && normalizedSide != 'B') {
      Get.snackbar('خطأ', 'طرف المباراة غير صحيح.');
      return;
    }
    final officialTeamId = normalizedSide == 'A' ? m.teamAId : m.teamBId;
    if (officialTeamId != null && officialTeamId.trim().isNotEmpty) {
      Get.snackbar('غير متاح', 'اسم الفريق الرسمي يأتي من بيانات الفريق.');
      return;
    }
    if (trimmedName.isEmpty) {
      Get.snackbar('بيانات ناقصة', 'اكتب اسم الفريق المؤقت أولاً.');
      return;
    }

    try {
      await _sideRepo.upsertSide(
        match: m,
        sideKey: normalizedSide,
        displayName: trimmedName,
        actorId: actorId,
      );
      await _loadSideViews(m);
      Get.snackbar(
        'تم تحديث الاسم',
        'تم حفظ اسم فريق $normalizedSide.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.renameTemporarySide', e);
      Get.snackbar('خطأ', 'فشل حفظ اسم الفريق المؤقت');
    }
  }

  Future<void> addTemporaryPlayerToSide({
    required String sideKey,
    required String displayName,
    String? position,
    int? shirtNumber,
  }) async {
    final m = match.value;
    final actorId = currentUserId;
    final normalizedSide = sideKey.trim().toUpperCase();
    final trimmedName = displayName.trim();
    if (m == null) return;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    if (m.tournamentId != null) {
      Get.snackbar('غير متاح', 'اللاعبون المؤقتون متاحون للوديات فقط.');
      return;
    }
    if (!isOrganizer) {
      Get.snackbar('غير مسموح', 'منظم المباراة فقط يمكنه تعديل الأطراف.');
      return;
    }
    if (normalizedSide != 'A' && normalizedSide != 'B') {
      Get.snackbar('خطأ', 'طرف المباراة غير صحيح.');
      return;
    }
    if (m.status != MatchStatus.open && m.status != MatchStatus.full) {
      Get.snackbar('غير متاح', 'لا يمكن تعديل اللاعبين بعد بدء المباراة.');
      return;
    }
    if (trimmedName.isEmpty) {
      Get.snackbar('بيانات ناقصة', 'اكتب اسم اللاعب المؤقت أولاً.');
      return;
    }

    final sideView = _sideViewFor(normalizedSide);
    final duplicateName =
        sideView?.temporaryPlayers.any(
          (player) => player.displayName.trim() == trimmedName,
        ) ??
        false;
    if (duplicateName) {
      Get.snackbar('موجود بالفعل', 'هذا الاسم موجود بالفعل في نفس الفريق.');
      return;
    }

    try {
      final side = await _sideRepo.upsertSide(
        match: m,
        sideKey: normalizedSide,
        displayName: sideView?.displayName ?? 'فريق $normalizedSide',
        actorId: actorId,
      );
      await _sidePlayerRepo.addTemporaryPlayer(
        matchId: m.id,
        sideKey: normalizedSide,
        sideId: side.id,
        displayName: trimmedName,
        addedBy: actorId,
        position: position,
        shirtNumber: shirtNumber,
      );
      await _loadSideViews(m);
      startReadiness.value = await _matchStartService.getStartReadiness(
        matchId: matchId,
        actorId: actorId,
      );
      Get.snackbar(
        'تمت الإضافة',
        'تمت إضافة $trimmedName إلى فريق $normalizedSide.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.addTemporaryPlayerToSide', e);
      Get.snackbar('خطأ', 'فشل إضافة اللاعب المؤقت');
    }
  }

  Future<void> editTemporaryPlayer({
    required String sideKey,
    required String playerId,
    required String displayName,
    String? position,
    int? shirtNumber,
  }) async {
    final m = match.value;
    final actorId = currentUserId;
    final normalizedSide = sideKey.trim().toUpperCase();
    final trimmedName = displayName.trim();
    if (m == null) return;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    if (m.tournamentId != null) {
      Get.snackbar('غير متاح', 'تعديل اللاعبين المؤقتين متاح للوديات فقط.');
      return;
    }
    if (!isOrganizer) {
      Get.snackbar('غير مسموح', 'منظم المباراة فقط يمكنه تعديل الأطراف.');
      return;
    }
    if (m.status != MatchStatus.open && m.status != MatchStatus.full) {
      Get.snackbar('غير متاح', 'لا يمكن تعديل اللاعبين بعد بدء المباراة.');
      return;
    }
    if (trimmedName.isEmpty) {
      Get.snackbar('بيانات ناقصة', 'اكتب اسم اللاعب المؤقت أولاً.');
      return;
    }

    final sideView = _sideViewFor(normalizedSide);
    final duplicateName =
        sideView?.temporaryPlayers.any(
          (p) => p.id != playerId && p.displayName.trim() == trimmedName,
        ) ??
        false;
    if (duplicateName) {
      Get.snackbar('موجود بالفعل', 'هذا الاسم موجود بالفعل في نفس الفريق.');
      return;
    }

    try {
      await _sidePlayerRepo.updateTemporaryPlayer(
        playerId: playerId,
        displayName: trimmedName,
        position: position,
        shirtNumber: shirtNumber,
      );
      await _loadSideViews(m);
      Get.snackbar(
        'تم التعديل ✏️',
        'تم تحديث بيانات اللاعب المؤقت.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.editTemporaryPlayer', e);
      Get.snackbar('خطأ', _readableError(e));
    }
  }

  Future<void> removeTemporaryPlayerFromSide({
    required String sideKey,
    required String playerId,
  }) async {
    final m = match.value;
    final actorId = currentUserId;
    if (m == null) return;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    if (m.tournamentId != null) {
      Get.snackbar('غير متاح', 'حذف اللاعبين المؤقتين متاح للوديات فقط.');
      return;
    }
    if (!isOrganizer) {
      Get.snackbar('غير مسموح', 'منظم المباراة فقط يمكنه تعديل الأطراف.');
      return;
    }
    if (m.status != MatchStatus.open && m.status != MatchStatus.full) {
      Get.snackbar('غير متاح', 'لا يمكن تعديل اللاعبين بعد بدء المباراة.');
      return;
    }

    try {
      await _sidePlayerRepo.removeTemporaryPlayer(playerId: playerId);
      await _loadSideViews(m);
      if (actorId.isNotEmpty) {
        startReadiness.value = await _matchStartService.getStartReadiness(
          matchId: matchId,
          actorId: actorId,
        );
      }
      Get.snackbar(
        'تمت الإزالة 🗑️',
        'تم حذف اللاعب المؤقت.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.removeTemporaryPlayerFromSide', e);
      Get.snackbar('خطأ', _readableError(e));
    }
  }

  Future<void> removePlayer(String playerId, String side) async {
    try {
      await _matchRepo.removePlayerFromMatch(
        matchId: matchId,
        playerId: playerId,
        side: side,
      );
      if (side == 'A') {
        teamAPlayers.removeWhere((p) => p.id == playerId);
      } else {
        teamBPlayers.removeWhere((p) => p.id == playerId);
      }
      await _refreshMatch();
    } catch (e) {
      AppLogger.error('MatchLobbyController.removePlayer', e);
      Get.snackbar('خطأ', 'فشل إزالة اللاعب');
    }
  }

  void inviteTemporaryPlayer({required MatchSidePlayer player}) {
    final text =
        '${player.displayName}، '
        'أنت مسجل كلاعب مؤقت في المباراة. '
        'سجّل في التطبيق وانضم:\n$inviteLink';
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'تم النسخ 📋',
      'تم نسخ رسالة الدعوة لـ ${player.displayName}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
