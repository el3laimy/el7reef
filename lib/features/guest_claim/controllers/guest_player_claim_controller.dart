import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/enums/guest_claim_status.dart';
import '../../../core/navigation/app_link_route_parser.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/guest_claim_service.dart';
import '../../../core/services/pride_share_attribution.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/entities/share_payload.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/repositories/guest_player_repository.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../shareables/services/guest_mvp_claim_link_service.dart';

class GuestPlayerClaimController extends GetxController {
  final AuthSession _authSession;
  final GuestPlayerRepository _guestPlayerRepository;
  final TeamRepository _teamRepository;
  final GuestClaimService _guestClaimService;
  final AnalyticsService _analyticsService;

  GuestPlayerClaimController({
    required AuthSession authSession,
    required GuestPlayerRepository guestPlayerRepository,
    required TeamRepository teamRepository,
    required GuestClaimService guestClaimService,
    AnalyticsService? analyticsService,
  }) : _authSession = authSession,
       _guestPlayerRepository = guestPlayerRepository,
       _teamRepository = teamRepository,
       _guestClaimService = guestClaimService,
       _analyticsService = analyticsService ?? AnalyticsService();

  final guestPlayer = Rxn<GuestPlayer>();
  final linkedTeam = Rxn<Team>();
  final claimResult = Rxn<GuestPlayerClaimResult>();
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  String? get guestPlayerId => Get.parameters['guestPlayerId'];
  String? get claimCode => Get.parameters['code'];
  String? get subjectName => Get.parameters['subjectName'];
  String? get claimTeamId => Get.parameters['teamId'];
  String? get claimTournamentId => Get.parameters['tournamentId'];
  Player? get currentPlayer => _authSession.currentPlayer;
  String? get currentUserId => _authSession.currentUserId;
  SharePayload? get pridePayload {
    final payload = PrideShareAttribution.fromQueryParameters(
      Get.parameters,
      targetUrl: Uri(
        scheme: 'https',
        host: AppLinkRouteParser.pilotWebHost,
        path: AppRoutes.claimEntry,
      ),
    );
    return GuestMvpClaimLinkService.claimableCardTypes.contains(
              payload?.cardType,
            ) &&
            payload?.entityType == ShareEntityType.guestPlayer &&
            payload?.entityId == guestPlayerId
        ? payload
        : null;
  }

  bool get hasSuccessfulClaim {
    final outcome = claimResult.value?.outcome;
    return outcome == GuestPlayerClaimOutcome.claimed ||
        outcome == GuestPlayerClaimOutcome.alreadyClaimed;
  }

  String? get claimedPlayerId =>
      hasSuccessfulClaim ? claimResult.value?.playerId : null;

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

      guestPlayer.value = _buildFallbackGuestPlayer(id);
      if (claimTeamId != null && claimTeamId!.isNotEmpty) {
        await _loadLinkedTeam(claimTeamId!);
      }

      final canEnrichFromFirestore =
          isAuthenticated || subjectName == null || subjectName!.trim().isEmpty;
      if (canEnrichFromFirestore) {
        try {
          final loadedGuestPlayer = await _guestPlayerRepository.getGuestPlayer(
            id,
          );
          if (loadedGuestPlayer != null) {
            guestPlayer.value = loadedGuestPlayer;
            if (loadedGuestPlayer.teamId != null &&
                loadedGuestPlayer.teamId!.isNotEmpty) {
              await _loadLinkedTeam(loadedGuestPlayer.teamId!);
            }
          }
        } catch (error) {
          AppLogger.warning(
            'GuestPlayerClaimController.loadClaimTarget.secureReadFallback',
            error,
          );
          // Keep the query-param fallback when the secure read is unavailable.
        }
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
    final sourcePayload = pridePayload;
    if (sourcePayload != null) {
      _analyticsService.trackClaimStartedFromCard(sourcePayload);
    }
    try {
      claimResult.value = await _guestClaimService.claimGuestPlayer(
        claimCode: code,
        playerId: userId,
      );
      if (claimResult.value?.outcome == GuestPlayerClaimOutcome.claimed &&
          sourcePayload != null) {
        _analyticsService.trackClaimCompletedFromCard(sourcePayload);
      }
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

  GuestPlayer _buildFallbackGuestPlayer(String id) {
    final effectiveName = _normalizeText(subjectName) ?? 'لاعب ضيف';
    return GuestPlayer(
      id: id,
      displayName: effectiveName,
      normalizedName: effectiveName.toLowerCase(),
      teamId: claimTeamId,
      tournamentId: claimTournamentId,
      createdBy: currentUserId ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      claimStatus: GuestClaimStatus.invited,
      claimCode: claimCode,
    );
  }

  Future<void> _loadLinkedTeam(String teamId) async {
    try {
      linkedTeam.value = await _teamRepository.getTeam(teamId);
    } catch (error) {
      AppLogger.warning('GuestPlayerClaimController._loadLinkedTeam', error);
      linkedTeam.value = null;
    }
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
