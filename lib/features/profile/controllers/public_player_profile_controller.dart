import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/participant_ref.dart';
import '../models/public_player_profile_data.dart';
import '../services/public_player_profile_resolver.dart';
import '../services/user_safety_service.dart';

class PublicPlayerProfileController extends GetxController {
  final PublicPlayerProfileResolver _resolver;
  final String kind;
  final String id;
  final UserSafetyService? _userSafetyService;

  PublicPlayerProfileController({
    required this.kind,
    required this.id,
    PublicPlayerProfileResolver? resolver,
    UserSafetyService? userSafetyService,
  }) : _resolver = resolver ?? PublicPlayerProfileResolver(),
       _userSafetyService = userSafetyService;

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final Rx<PublicPlayerProfileData?> profile = Rx<PublicPlayerProfileData?>(
    null,
  );

  static const Set<String> _claimPayloadKeys = {
    'code',
    'type',
    'targetId',
    'subjectName',
    'scope',
    'teamId',
    'tournamentId',
    'requiresApproval',
    'expiresAt',
    'status',
  };

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final resolved = await _resolver.resolve(kind: kind, id: id);
      if (resolved == null) {
        final fallback = _guestProfileFallback();
        if (fallback == null) {
          profile.value = null;
          errorMessage.value = 'تعذر العثور على هذا اللاعب.';
          return;
        }
        profile.value = fallback;
        return;
      }
      profile.value = _applyGuestQueryFallbacks(resolved);
    } catch (error, stackTrace) {
      AppLogger.error(
        'PublicPlayerProfileController.loadProfile',
        error,
        stackTrace,
      );
      final fallback = _guestProfileFallback();
      if (fallback == null) {
        profile.value = null;
        errorMessage.value = 'تعذر تحميل بروفايل اللاعب الآن.';
        return;
      }
      profile.value = fallback;
    } finally {
      isLoading.value = false;
    }
  }

  bool get hasValidGuestClaimPayload {
    final data = profile.value;
    if (!_canEvaluateGuestClaim(data)) return false;
    if (!_hasAnyClaimPayload) return false;
    return guestClaimWarningMessage == null;
  }

  String? get guestClaimWarningMessage {
    final data = profile.value;
    if (!_canEvaluateGuestClaim(data)) return null;
    final guestProfile = data!;
    if (!_hasAnyClaimPayload) return null;

    final code = _queryValue('code');
    final type = _queryValue('type');
    final targetId = _queryValue('targetId');
    if (!_hasText(code) || !_hasText(targetId)) {
      return 'رابط الدعوة غير مكتمل. اطلب رابطًا جديدًا من منظم البطولة أو قائد الفريق.';
    }
    if (type != 'guestPlayer') {
      return 'رابط الدعوة لا يخص بروفايل لاعب ضيف.';
    }
    if (targetId != guestProfile.id) {
      return 'رابط الدعوة لا يطابق هذا البروفايل.';
    }

    final status = _queryValue('status');
    if (_hasText(status) && status != 'active') {
      return 'رابط الدعوة لم يعد نشطًا. اطلب رابطًا جديدًا من منظم البطولة أو قائد الفريق.';
    }

    final expiresAt = _queryValue('expiresAt');
    if (_hasText(expiresAt)) {
      final expiresAtMillis = int.tryParse(expiresAt!);
      if (expiresAtMillis == null) {
        return 'رابط الدعوة غير صالح. اطلب رابطًا جديدًا من منظم البطولة أو قائد الفريق.';
      }
      final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(
        expiresAtMillis,
      );
      if (expiresAtDate.isBefore(DateTime.now())) {
        return 'انتهت صلاحية رابط الدعوة. اطلب رابطًا جديدًا من منظم البطولة أو قائد الفريق.';
      }
    }

    return null;
  }

  Map<String, String?> get guestClaimQueryParameters {
    if (!hasValidGuestClaimPayload) return const {};

    return {
      for (final key in _claimPayloadKeys)
        if (_hasText(Get.parameters[key])) key: Get.parameters[key]!.trim(),
    };
  }

  String? get guestClaimRoute {
    final data = profile.value;
    if (data == null || !hasValidGuestClaimPayload) return null;
    return AppRoutes.guestPlayerClaimById(
      data.id,
      queryParameters: guestClaimQueryParameters,
    );
  }

  void openGuestClaim() {
    final route = guestClaimRoute;
    if (route == null) return;
    Get.toNamed(route);
  }

  bool get canReportProfile {
    final data = profile.value;
    return data != null && (_userSafetyService?.canReport(data) ?? false);
  }

  bool get canBlockPlayer {
    final data = profile.value;
    return data != null && (_userSafetyService?.canBlock(data) ?? false);
  }

  Future<bool> reportProfile({
    required UserReportReason reason,
    String details = '',
  }) async {
    final data = profile.value;
    final service = _userSafetyService;
    if (data == null || service == null || !service.canReport(data)) {
      return false;
    }
    try {
      final reported = await service.reportProfile(
        profile: data,
        reason: reason,
        details: details,
      );
      Get.snackbar(
        reported ? 'وصل البلاغ' : 'تعذر إرسال البلاغ',
        reported
            ? 'سنراجع البروفايل ونتخذ الإجراء المناسب.'
            : 'حاول مرة أخرى بعد قليل.',
      );
      return reported;
    } catch (error, stackTrace) {
      AppLogger.error(
        'PublicPlayerProfileController.reportProfile',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر إرسال البلاغ', 'حاول مرة أخرى بعد قليل.');
      return false;
    }
  }

  Future<bool> blockPlayer() async {
    final data = profile.value;
    final service = _userSafetyService;
    if (data == null || service == null || !service.canBlock(data)) {
      return false;
    }
    try {
      final blocked = await service.blockPlayer(data);
      Get.snackbar(
        blocked ? 'تم الحظر' : 'تعذر الحظر',
        blocked
            ? 'لن يظهر هذا اللاعب ضمن تفاعلاتك الاجتماعية.'
            : 'حاول مرة أخرى بعد قليل.',
      );
      return blocked;
    } catch (error, stackTrace) {
      AppLogger.error(
        'PublicPlayerProfileController.blockPlayer',
        error,
        stackTrace,
      );
      Get.snackbar('تعذر الحظر', 'حاول مرة أخرى بعد قليل.');
      return false;
    }
  }

  String? _queryValue(String key) {
    final value = Get.parameters[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  bool get _hasAnyClaimPayload =>
      _claimPayloadKeys.any((key) => _hasText(Get.parameters[key]));

  bool _canEvaluateGuestClaim(PublicPlayerProfileData? data) {
    if (data == null) return false;
    if (!data.isGuest) return false;
    if (data.id.trim().isEmpty) return false;
    if (data.isClaimed || _hasText(data.linkedPlayerId)) return false;
    return true;
  }

  PublicPlayerProfileData? _applyGuestQueryFallbacks(
    PublicPlayerProfileData resolved,
  ) {
    if (!resolved.isGuest) {
      return resolved;
    }

    final subjectName = _queryValue('subjectName');
    if (subjectName == null) {
      return resolved;
    }

    return PublicPlayerProfileData(
      kind: resolved.kind,
      id: resolved.id,
      displayName: subjectName,
      totalGoals: resolved.totalGoals,
      totalMvps: resolved.totalMvps,
      linkedPlayerId: resolved.linkedPlayerId,
      isClaimed: resolved.isClaimed,
    );
  }

  PublicPlayerProfileData? _guestProfileFallback() {
    final subjectName = _queryValue('subjectName');
    if (!_hasText(subjectName)) {
      return null;
    }
    final kindValue = kind.trim();
    if (kindValue != 'guestPlayer') {
      return null;
    }

    return PublicPlayerProfileData(
      kind: ParticipantRefKind.guestPlayer,
      id: id.trim(),
      displayName: subjectName!,
      totalGoals: 0,
      totalMvps: 0,
      isClaimed: false,
    );
  }
}
