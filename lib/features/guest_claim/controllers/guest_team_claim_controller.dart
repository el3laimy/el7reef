import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/claim_code_status.dart';
import '../../../core/services/guest_claim_service.dart';
import '../../../domain/entities/claim_code.dart';
import '../../../domain/entities/guest_team.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/repositories/claim_code_repository.dart';
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/team_repository.dart';

class GuestTeamClaimController extends GetxController {
  final AuthSession _authSession;
  final ClaimCodeRepository _claimCodeRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TeamRepository _teamRepository;
  final GuestClaimService _guestClaimService;

  GuestTeamClaimController({
    required AuthSession authSession,
    required ClaimCodeRepository claimCodeRepository,
    required GuestTeamRepository guestTeamRepository,
    required TeamRepository teamRepository,
    required GuestClaimService guestClaimService,
  })  : _authSession = authSession,
        _claimCodeRepository = claimCodeRepository,
        _guestTeamRepository = guestTeamRepository,
        _teamRepository = teamRepository,
        _guestClaimService = guestClaimService;

  final claimDetails = Rxn<ClaimCode>();
  final guestTeam = Rxn<GuestTeam>();
  final pendingRequestedTeam = Rxn<Team>();
  final ownedTeams = <Team>[].obs;
  final selectedTeamId = RxnString();
  final claimResult = Rxn<GuestTeamClaimResult>();
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  String? get guestTeamId => Get.parameters['guestTeamId'];
  String? get claimCode => Get.parameters['code'];
  Player? get currentPlayer => _authSession.currentPlayer;
  String? get currentUserId => _authSession.currentUserId;
  bool get requiresApprovalHint =>
      Get.parameters['requiresApproval'] == '1' ||
      Get.parameters['requiresApproval'] == 'true';

  bool get isAuthenticated =>
      currentUserId != null && currentUserId!.isNotEmpty;

  String? get pendingRequestedTeamId {
    final teamId = claimDetails.value?.teamId;
    if (teamId == null || teamId.isEmpty) {
      return null;
    }
    return teamId;
  }

  bool get hasPendingApprovalRequest {
    final details = claimDetails.value;
    final requestedByPlayerId = details?.claimedByPlayerId;
    return details != null &&
        details.requiresApproval &&
        details.status == ClaimCodeStatus.active &&
        pendingRequestedTeamId != null &&
        requestedByPlayerId != null &&
        requestedByPlayerId.isNotEmpty;
  }

  bool get canCompletePendingApproval =>
      isAuthenticated &&
      guestTeam.value?.creatorId == currentUserId &&
      hasPendingApprovalRequest;

  @override
  void onInit() {
    super.onInit();
    loadClaimTarget();
  }

  Future<void> loadClaimTarget() async {
    isLoading.value = true;
    errorMessage.value = '';
    claimDetails.value = null;
    pendingRequestedTeam.value = null;
    try {
      final id = guestTeamId;
      if (id == null || id.isEmpty) {
        errorMessage.value = 'لم يتم تحديد الفريق الضيف المطلوب.';
        return;
      }
      if (claimCode == null || claimCode!.isEmpty) {
        errorMessage.value = 'رابط الاستلام لا يحتوي على code صالح.';
        return;
      }

      final loadedGuestTeam = await _guestTeamRepository.getGuestTeam(id);
      if (loadedGuestTeam == null) {
        errorMessage.value = 'الفريق الضيف المطلوب غير موجود.';
        return;
      }
      guestTeam.value = loadedGuestTeam;

      await _loadOwnedTeams();
      await _loadClaimDetails(expectedGuestTeamId: id);
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadOwnedTeams() async {
    final userId = currentUserId;
    ownedTeams.clear();
    selectedTeamId.value = null;
    if (userId == null || userId.isEmpty) {
      return;
    }

    final playerTeams = await _teamRepository.getPlayerTeams(userId);
    final owned = playerTeams
        .where((team) => team.ownerId == userId)
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    ownedTeams.assignAll(owned);
    if (owned.length == 1) {
      selectedTeamId.value = owned.first.id;
    }
  }

  Future<void> _loadClaimDetails({
    required String expectedGuestTeamId,
  }) async {
    final code = claimCode;
    if (code == null || code.isEmpty) {
      return;
    }

    final loadedClaim = await _claimCodeRepository.getClaimCode(code);
    if (loadedClaim == null) {
      errorMessage.value = 'لم نتمكن من تحميل بيانات رابط الاستلام.';
      return;
    }
    if (loadedClaim.targetId != expectedGuestTeamId) {
      errorMessage.value = 'رابط الاستلام لا يطابق هذا الفريق الضيف.';
      return;
    }

    claimDetails.value = loadedClaim;

    final requestedTeamId = loadedClaim.teamId;
    if (requestedTeamId == null || requestedTeamId.isEmpty) {
      return;
    }

    pendingRequestedTeam.value = await _teamRepository.getTeam(requestedTeamId);
    if (ownedTeams.any((team) => team.id == requestedTeamId)) {
      selectedTeamId.value = requestedTeamId;
    }
  }

  void selectTeam(String? teamId) {
    selectedTeamId.value = teamId;
  }

  Future<void> submitClaim() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً لإتمام claim الفريق.';
      return;
    }
    final code = claimCode;
    if (code == null || code.isEmpty) {
      errorMessage.value = 'رابط الاستلام لا يحتوي على code صالح.';
      return;
    }
    final chosenTeamId = canCompletePendingApproval
        ? pendingRequestedTeamId
        : selectedTeamId.value;
    if (chosenTeamId == null || chosenTeamId.isEmpty) {
      errorMessage.value = canCompletePendingApproval
          ? 'لا يوجد طلب claim معلق صالح حتى تتم الموافقة عليه.'
          : 'اختر الفريق الذي تريد ربطه بهذا الفريق الضيف.';
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      claimResult.value = await _guestClaimService.claimGuestTeam(
        claimCode: code,
        teamId: chosenTeamId,
        actorId: userId,
      );
      await loadClaimTarget();
      selectedTeamId.value = chosenTeamId;
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }
}
