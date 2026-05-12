part of 'team_lineup_editor_controller.dart';

extension TeamLineupEditorOps on TeamLineupEditorController {
  Future<bool> addGuestPlayer(String name, {int? number}) async {
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return false;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('خطأ', 'اسم اللاعب الضيف مطلوب.');
      return false;
    }

    final now = DateTime.now();
    final guestPlayer = GuestPlayer(
      id: _uuid.v4(),
      displayName: trimmed,
      normalizedName: trimmed.toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      jerseyNumber: number,
      teamId: teamId,
      createdBy: actorId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      isSaving.value = true;
      await _guestPlayerRepository.createGuestPlayer(guestPlayer);
      await _teamRosterService.addGuestPlayer(
        teamId: teamId,
        actorId: actorId,
        guestPlayerId: guestPlayer.id,
        status: TeamMembershipStatus.bench,
        availability: TeamMemberAvailability.available,
      );
      await loadLineup();
      Get.snackbar('تم', 'تمت إضافة ${guestPlayer.displayName} إلى البدلاء.');
      return true;
    } catch (error) {
      Get.snackbar('خطأ', _readableError(error));
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> saveConfirmedLineup() async {
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return false;
    }
    final starters = starterMembershipIds;
    var allowIncompleteFriendlyLineup = false;
    if (starters.length != playerCount.value) {
      final currentMatch = match.value;
      final isFriendly =
          currentMatch != null &&
          currentMatch.tournamentId == null &&
          !currentMatch.isOrganized;
      if (!isFriendly) {
        Get.snackbar(
          'التشكيلة غير مكتملة',
          'أكمل ${playerCount.value} لاعبين أساسيين قبل حفظ التشكيلة.',
        );
        return false;
      }
      final confirmed = await _confirmIncompleteFriendlyLineup(
        selectedStarters: starters.length,
      );
      if (!confirmed) {
        return false;
      }
      allowIncompleteFriendlyLineup = true;
    }

    try {
      isSaving.value = true;
      final attendanceStatuses = <String, MatchAttendanceStatus>{
        for (final member in members)
          member.membership.id:
              member.membership.status == TeamMembershipStatus.inactive
              ? MatchAttendanceStatus.absent
              : MatchAttendanceStatus.present,
      };
      await _matchdayService.checkInRegisteredTeam(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        membershipStatuses: attendanceStatuses,
      );
      final result = await _matchdayService.lockRegisteredTeamLineup(
        matchId: matchId,
        teamId: teamId,
        actorId: actorId,
        starterMembershipIds: starters,
        benchMembershipIds: benchMembershipIds,
        allowIncompleteFriendlyLineup: allowIncompleteFriendlyLineup,
        formationCode: formationCode.value,
        formationLabel: formationCode.value,
        slotAssignments: _buildSlotAssignments(),
      );
      confirmedSnapshot.value = result.snapshot;
      _seedFromSnapshot(result.snapshot);
      return true;
    } catch (error) {
      Get.snackbar('تعذر حفظ التشكيلة', _readableError(error));
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
