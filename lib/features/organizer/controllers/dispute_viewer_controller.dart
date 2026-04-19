import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/dispute_enums.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/services/dispute_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/repositories/audit_repository_impl.dart';
import '../../../data/repositories/dispute_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../domain/entities/dispute.dart';

/// كونترولر عرض وإدارة النزاعات لمباراة أو بطولة
class DisputeViewerController extends GetxController {
  final DisputeService _disputeService;
  final AuthSession _authSession;

  final RxList<Dispute> disputes = <Dispute>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;

  /// معرف المباراة المستهدفة
  final String matchId;

  DisputeViewerController({
    required this.matchId,
    required AuthSession authSession,
    DisputeService? disputeService,
  }) : _disputeService = disputeService ??
            DisputeService(
              disputeRepository: DisputeRepositoryImpl(),
              matchRepository: MatchRepositoryImpl(),
              auditService: AuditService(repository: AuditRepositoryImpl()),
            ),
       _authSession = authSession;

  @override
  void onInit() {
    super.onInit();
    loadDisputes();
  }

  Future<void> loadDisputes() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      disputes.value = await _disputeService.getMatchDisputes(matchId);
    } catch (error) {
      AppLogger.error('DisputeViewerController.loadDisputes', error);
      errorMessage.value = 'تعذر تحميل النزاعات';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resolveDispute({
    required String disputeId,
    required String resolvedBy,
    required String resolutionNote,
  }) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';
      successMessage.value = '';

      await _disputeService.resolveDispute(
        disputeId: disputeId,
        resolvedBy: resolvedBy,
        resolutionNote: resolutionNote,
      );

      successMessage.value = 'تم حل النزاع بنجاح';
      await loadDisputes();
    } catch (error) {
      AppLogger.error('DisputeViewerController.resolveDispute', error);
      errorMessage.value = 'تعذر حل النزاع: ${error.toString()}';
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> rejectDispute({
    required String disputeId,
    required String rejectedBy,
    required String rejectionNote,
  }) async {
    try {
      isProcessing.value = true;
      errorMessage.value = '';
      successMessage.value = '';

      await _disputeService.rejectDispute(
        disputeId: disputeId,
        rejectedBy: rejectedBy,
        rejectionNote: rejectionNote,
      );

      successMessage.value = 'تم رفض النزاع';
      await loadDisputes();
    } catch (error) {
      AppLogger.error('DisputeViewerController.rejectDispute', error);
      errorMessage.value = 'تعذر رفض النزاع: ${error.toString()}';
    } finally {
      isProcessing.value = false;
    }
  }

  /// ترجمة حالة النزاع إلى نص عربي
  String statusLabel(DisputeStatus status) {
    switch (status) {
      case DisputeStatus.open:
        return 'مفتوح';
      case DisputeStatus.underReview:
        return 'قيد المراجعة';
      case DisputeStatus.resolved:
        return 'تم الحل';
      case DisputeStatus.rejected:
        return 'مرفوض';
      case DisputeStatus.expired:
        return 'منتهي الصلاحية';
    }
  }

  /// ترجمة نوع النزاع إلى نص عربي
  String typeLabel(DisputeType type) {
    switch (type) {
      case DisputeType.scoreDispute:
        return 'نزاع على النتيجة';
      case DisputeType.lineupDispute:
        return 'نزاع على التشكيلة';
      case DisputeType.mvpDispute:
        return 'نزاع على اختيار MVP';
      case DisputeType.ratingDispute:
        return 'نزاع على التقييم';
      case DisputeType.general:
        return 'نزاع عام';
    }
  }

  int get openCount => disputes.where((d) => d.isOpen).length;
  int get closedCount => disputes.where((d) => d.isClosed).length;
  String? get currentUserId => _authSession.currentUserId;
}
