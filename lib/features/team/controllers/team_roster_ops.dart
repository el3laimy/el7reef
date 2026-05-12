part of 'team_roster_controller.dart';

extension TeamRosterOps on TeamRosterController {
  Future<bool> saveFormationTemplate({
    required String name,
    String? formationLabel,
  }) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return false;
    }

    try {
      isSubmitting.value = true;
      await _teamFormationService.saveCurrentAsTemplate(
        teamId: targetTeamId,
        actorId: actorId,
        name: name,
        formationLabel: formationLabel,
      );
      clearTemplateForm();
      await loadTeamRoster();
      Get.snackbar('تم', 'تم حفظ القالب الجديد بنجاح.');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> createRosterSnapshot({
    required String label,
    String? formationLabel,
    String? sourceTemplateId,
  }) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return false;
    }

    try {
      isSubmitting.value = true;
      await _teamFormationService.createRosterSnapshot(
        teamId: targetTeamId,
        actorId: actorId,
        label: label,
        formationLabel: formationLabel,
        sourceTemplateId: sourceTemplateId,
      );
      clearSnapshotForm();
      await loadTeamRoster();
      Get.snackbar('تم', 'تم إنشاء نسخة جاهزة للمباراة.');
      return true;
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> applyTemplate(TeamFormationTemplate template) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      final result = await _teamFormationService.applyTemplate(
        teamId: targetTeamId,
        actorId: actorId,
        templateId: template.id,
      );
      await loadTeamRoster();
      final suffix = result.missingMembers > 0
          ? ' مع ${result.missingMembers} عنصر لم يعد موجودًا في القائمة.'
          : '.';
      Get.snackbar(
        'تم',
        'تم تطبيق القالب على ${result.matchedMembers} عنصر$suffix',
      );
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> deleteTemplate(TeamFormationTemplate template) async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      return;
    }

    try {
      isSubmitting.value = true;
      await _teamFormationService.deleteTemplate(
        teamId: targetTeamId,
        actorId: actorId,
        templateId: template.id,
      );
      await loadTeamRoster();
      Get.snackbar('تم', 'تم حذف القالب ${template.name}.');
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> shareTeamInviteLink() async {
    final targetTeamId = teamId;
    final actorId = currentUserId;
    if (targetTeamId == null || actorId == null) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return;
    }

    try {
      isSubmitting.value = true;
      final shareLink = await _shareLinkService.createTeamInviteLink(
        teamId: targetTeamId,
        actorId: actorId,
      );
      await _shareText(shareLink.shareText);
    } catch (e) {
      Get.snackbar('خطأ', _readableError(e));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> shareGuestPlayerClaimLink(String guestPlayerId) async {
    final actorId = currentUserId;
    if (actorId == null) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول أولاً.');
      return false;
    }
    if (!canManageRoster) {
      Get.snackbar('خطأ', 'لا تملك صلاحية إرسال رابط الاستلام لهذا الضيف.');
      return false;
    }

    try {
      isSubmitting.value = true;
      final guestPlayer = await _guestPlayerRepository.getGuestPlayer(
        guestPlayerId,
      );
      if (guestPlayer == null) {
        Get.snackbar('خطأ', 'اللاعب الضيف المطلوب غير موجود.');
        return false;
      }
      if (guestPlayer.isClaimed || guestPlayer.hasLinkedPlayer) {
        Get.snackbar('تم الربط', 'تم ربط هذا الضيف بالفعل ببروفايل لاعب مسجل.');
        return false;
      }
      final shareLink = await _shareLinkService.createGuestPlayerClaimLink(
        guestPlayerId: guestPlayerId,
        actorId: actorId,
      );
      await _shareText(shareLink.shareText);
      return true;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'تعذر إنشاء رابط الاستلام الآن. تأكد من الصلاحيات وحاول مرة أخرى.',
      );
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
