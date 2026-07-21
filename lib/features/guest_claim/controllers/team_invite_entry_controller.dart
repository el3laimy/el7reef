import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/navigation/pending_deep_link_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/team_invite_service.dart';
import '../../../domain/entities/team.dart';

class TeamInviteEntryController extends GetxController {
  final AuthSession _authSession;
  final TeamInviteService _teamInviteService;
  final AnalyticsService _analyticsService;

  TeamInviteEntryController({
    required AuthSession authSession,
    required TeamInviteService teamInviteService,
    AnalyticsService? analyticsService,
  }) : _authSession = authSession,
       _teamInviteService = teamInviteService,
       _analyticsService = analyticsService ?? AnalyticsService();

  final team = Rxn<Team>();
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  String? get targetId => Get.parameters['targetId'];
  String? get code => Get.parameters['code'];

  bool get isLoggedIn => _authSession.currentUserId != null;

  @override
  void onInit() {
    super.onInit();
    _loadInviteDetails();
  }

  Future<void> _loadInviteDetails() async {
    final teamId = targetId;
    final inviteCode = code;
    if (teamId == null || teamId.isEmpty) {
      errorMessage.value = 'رابط الدعوة غير صالح أو مفقود المُعرّف.';
      isLoading.value = false;
      return;
    }
    if (inviteCode == null || inviteCode.isEmpty) {
      errorMessage.value = 'رابط الدعوة لا يحتوي على code صالح.';
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      final preview = await _teamInviteService.resolveInvite(
        code: inviteCode,
        teamId: teamId,
      );
      team.value = preview.team;
      if (isLoggedIn) {
        _analyticsService.trackClaimOpen(type: 'team_invite', targetId: teamId);
      }
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> acceptInvite() async {
    if (!isLoggedIn) {
      final query = Map<String, String?>.from(Get.parameters);
      _pendingDeepLinkService().store(AppRoutes.inviteEntryWithQuery(query));
      Get.toNamed(AppRoutes.login);
      return;
    }
    final teamId = targetId;
    final inviteCode = code;
    if (teamId == null ||
        teamId.isEmpty ||
        inviteCode == null ||
        inviteCode.isEmpty) {
      errorMessage.value = 'رابط الدعوة غير مكتمل.';
      return;
    }

    try {
      isSubmitting.value = true;
      final result = await _teamInviteService.acceptInvite(
        code: inviteCode,
        teamId: teamId,
        playerId: _authSession.currentUserId!,
      );

      _analyticsService.trackJoinCompletion(
        type: 'team_invite',
        targetId: result.team.id,
        actorId: _authSession.currentUserId!,
      );

      Get.snackbar(
        'مرحباً!',
        result.outcome == TeamInviteAcceptanceOutcome.joined
            ? 'تم الانضمام إلى الفريق بنجاح.'
            : 'أنت عضو بالفعل في هذا الفريق.',
      );
      Get.offAllNamed(AppRoutes.teamProfileById(result.team.id));
    } catch (e) {
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      Get.snackbar('خطأ', errorMessage.value);
    } finally {
      isSubmitting.value = false;
    }
  }

  PendingDeepLinkService _pendingDeepLinkService() {
    return Get.isRegistered<PendingDeepLinkService>()
        ? Get.find<PendingDeepLinkService>()
        : Get.put(PendingDeepLinkService(), permanent: true);
  }
}
