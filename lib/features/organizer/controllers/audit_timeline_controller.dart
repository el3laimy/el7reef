import 'package:get/get.dart';

import '../../../core/enums/audit_action.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/audit_repository_impl.dart';
import '../../../domain/entities/audit_event.dart';

/// كونترولر عرض سجل التدقيق لكيان محدد (مباراة أو بطولة)
class AuditTimelineController extends GetxController {
  final AuditService _auditService;

  final RxList<AuditEvent> events = <AuditEvent>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  /// معرف الكيان المستهدف (matchId أو tournamentId)
  final String entityId;
  final AuditEntityType entityType;

  AuditTimelineController({
    required this.entityId,
    required this.entityType,
    AuditService? auditService,
  }) : _auditService =
           auditService ?? AuditService(repository: AuditRepositoryImpl());

  @override
  void onInit() {
    super.onInit();
    loadTimeline();
  }

  Future<void> loadTimeline() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      events.value = await _auditService.getEntityTimeline(
        entityType: entityType,
        entityId: entityId,
      );
    } catch (error) {
      AppLogger.error('AuditTimelineController.loadTimeline', error);
      errorMessage.value = 'تعذر تحميل سجل التدقيق';
    } finally {
      isLoading.value = false;
    }
  }

  /// ترجمة نوع الحدث إلى نص عربي
  String actionLabel(AuditAction action) {
    switch (action) {
      case AuditAction.matchCreated:
        return 'تم إنشاء المباراة';
      case AuditAction.matchScoreSubmitted:
        return 'تم إرسال النتيجة';
      case AuditAction.matchScoreApproved:
        return 'تم اعتماد النتيجة';
      case AuditAction.matchFrozen:
        return 'تم تجميد المباراة';
      case AuditAction.matchUnfrozen:
        return 'تم رفع التجميد';
      case AuditAction.matchGoldenRatingActivated:
        return 'تم تفعيل التقييم الذهبي';
      case AuditAction.matchSettled:
        return 'تم تسوية المباراة';
      case AuditAction.teamCheckedIn:
        return 'تم تسجيل حضور الفريق';
      case AuditAction.lineupLocked:
        return 'تم قفل التشكيل';
      case AuditAction.substitutionRecorded:
        return 'تم تسجيل تبديل';
      case AuditAction.tournamentCreated:
        return 'تم إنشاء البطولة';
      case AuditAction.tournamentStatusChanged:
        return 'تم تغيير حالة البطولة';
      case AuditAction.registrationCreated:
        return 'تم تسجيل فريق';
      case AuditAction.registrationApproved:
        return 'تم اعتماد التسجيل';
      case AuditAction.registrationRejected:
        return 'تم رفض التسجيل';
      case AuditAction.participantAdded:
        return 'تمت إضافة participant للبطولة';
      case AuditAction.participantReplaced:
        return 'تم استبدال participant';
      case AuditAction.participantWithdrawn:
        return 'تم سحب participant من البطولة';
      case AuditAction.participantReactivated:
        return 'تمت إعادة تفعيل participant';
      case AuditAction.participantSeedUpdated:
        return 'تم تحديث seed الخاصة بالمشارك';
      case AuditAction.participantsFinalized:
        return 'تم قفل قائمة المشاركين';
      case AuditAction.groupStageGenerated:
        return 'تم إنشاء مرحلة المجموعات';
      case AuditAction.groupStageRegenerated:
        return 'تمت إعادة توليد المجموعات';
      case AuditAction.fixtureScheduled:
        return 'تمت جدولة fixture';
      case AuditAction.fixturesPublished:
        return 'تم نشر fixtures البطولة';
      case AuditAction.knockoutGenerated:
        return 'تم إنشاء bracket الإقصاء';
      case AuditAction.tournamentCompleted:
        return 'تم إنهاء البطولة';
      case AuditAction.guestPlayerCreated:
        return 'تم إضافة لاعب ضيف';
      case AuditAction.guestPlayerClaimed:
        return 'تم ربط لاعب ضيف';
      case AuditAction.guestTeamCreated:
        return 'تم إضافة فريق ضيف';
      case AuditAction.guestTeamClaimed:
        return 'تم ربط فريق ضيف';
      case AuditAction.claimCodeGenerated:
        return 'تم إنشاء رمز ربط';
      case AuditAction.claimCodeConsumed:
        return 'تم استخدام رمز ربط';
      case AuditAction.fantasyRoundSettled:
        return 'تم تسوية جولة الفانتازي';
      case AuditAction.fantasyTransferExecuted:
        return 'تم تنفيذ انتقال';
      case AuditAction.fantasyChipActivated:
        return 'تم تفعيل خاصية';
      case AuditAction.memberAdded:
        return 'تم إضافة عضو';
      case AuditAction.memberRemoved:
        return 'تم إزالة عضو';
      case AuditAction.memberRoleChanged:
        return 'تم تغيير دور العضو';
      case AuditAction.disputeOpened:
        return 'تم فتح نزاع';
      case AuditAction.disputeResolved:
        return 'تم حل النزاع';
      case AuditAction.disputeRejected:
        return 'تم رفض النزاع';
      case AuditAction.disputeFrozenMatch:
        return 'تم تجميد المباراة بسبب نزاع';
    }
  }
}
