import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/services/guest_claim_service.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/repositories/guest_player_repository.dart';
import '../../../domain/repositories/team_repository.dart';

class GuestPlayerClaimController extends GetxController {
  final AuthSession _authSession;
  final GuestPlayerRepository _guestPlayerRepository;
  final TeamRepository _teamRepository;
  final GuestClaimService _guestClaimService;

  GuestPlayerClaimController({
    required AuthSession authSession,
    required GuestPlayerRepository guestPlayerRepository,
    required TeamRepository teamRepository,
    required GuestClaimService guestClaimService,
  })  : _authSession = authSession,
        _guestPlayerRepository = guestPlayerRepository,
        _teamRepository = teamRepository,
        _guestClaimService = guestClaimService;

  final guestPlayer = Rxn<GuestPlayer>();
  final linkedTeam = Rxn<Team>();
  final claimResult = Rxn<GuestPlayerClaimResult>();
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  String? get guestPlayerId => Get.parameters['guestPlayerId'];
  String? get claimCode => Get.parameters['code'];
  Player? get currentPlayer => _authSession.currentPlayer;
  String? get currentUserId => _authSession.currentUserId;

  bool get isAuthenticated =>
      currentUserId != null && currentUserId!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadClaimTarget();
  }

  Future<void> loadClaimTarget() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final id = guestPlayerId;
      if (id == null || id.isEmpty) {
        errorMessage.value = 'لم يتم تحديد اللاعب الضيف المطلوب.';
        return;
      }
      if (claimCode == null || claimCode!.isEmpty) {
        errorMessage.value = 'رابط الاستلام لا يحتوي على code صالح.';
        return;
      }

      final loadedGuestPlayer = await _guestPlayerRepository.getGuestPlayer(id);
      if (loadedGuestPlayer == null) {
        errorMessage.value = 'اللاعب الضيف المطلوب غير موجود.';
        return;
      }

      guestPlayer.value = loadedGuestPlayer;
      if (loadedGuestPlayer.teamId != null && loadedGuestPlayer.teamId!.isNotEmpty) {
        linkedTeam.value = await _teamRepository.getTeam(loadedGuestPlayer.teamId!);
      }
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitClaim() async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً لاستلام مكانك.';
      return;
    }
    final code = claimCode;
    if (code == null || code.isEmpty) {
      errorMessage.value = 'رابط الاستلام لا يحتوي على code صالح.';
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      claimResult.value = await _guestClaimService.claimGuestPlayer(
        claimCode: code,
        playerId: userId,
      );
      await loadClaimTarget();
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
