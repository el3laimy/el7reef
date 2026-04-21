import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_invitation.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/repositories/match_invitation_repository.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../services/auth_service.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/utils/app_logger.dart';

/// Controller لشاشة لوبي المباراة
class MatchLobbyController extends GetxController {
  final MatchRepository _matchRepo;
  final MatchInvitationRepository _invitationRepo;
  final String matchId;

  MatchLobbyController({required this.matchId})
      : _matchRepo = Get.find<MatchRepository>(),
        _invitationRepo = Get.find<MatchInvitationRepository>();

  final _authService = Get.find<AuthService>();
  final _playerRepo = Get.find<PlayerRepositoryImpl>();

  // ── State ──
  final Rx<Match?> match = Rx<Match?>(null);
  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;
  final RxList<MatchInvitation> sentInvitations = <MatchInvitation>[].obs;
  final RxMap<String, Offset> playerPositions = <String, Offset>{}.obs;
  final RxBool isLoading = true.obs;

  String get inviteLink => 'el7reef://match/join/$matchId';
  String? get currentUserId => _authService.currentUserId;
  bool get isOrganizer => match.value?.organizerId == currentUserId;

  @override
  void onInit() {
    super.onInit();
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    try {
      isLoading.value = true;
      final m = await _matchRepo.getMatch(matchId);
      if (m == null) {
        Get.snackbar('خطأ', 'لم يتم العثور على المباراة');
        return;
      }
      match.value = m;
      await Future.wait([
        _loadPlayers(m),
        _loadInvitations(),
      ]);
    } catch (e) {
      AppLogger.error('MatchLobbyController._loadMatch', e);
      Get.snackbar('خطأ', 'فشل تحميل بيانات المباراة');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadInvitations() async {
    try {
      final invitations = await _invitationRepo.getInvitationsForMatch(matchId);
      sentInvitations.value = invitations;
    } catch (e) {
      AppLogger.error('MatchLobbyController._loadInvitations', e);
    }
  }

  Future<void> _loadPlayers(Match m) async {
    teamAPlayers.clear();
    teamBPlayers.clear();

    for (final id in m.teamAPlayerIds) {
      final player = await _playerRepo.getPlayer(id);
      if (player != null) teamAPlayers.add(player);
    }
    for (final id in m.teamBPlayerIds) {
      final player = await _playerRepo.getPlayer(id);
      if (player != null) teamBPlayers.add(player);
    }
  }

  /// بدء المباراة (open → live)
  Future<void> startMatch() async {
    final m = match.value;
    if (m == null) return;
    try {
      await _matchRepo.updateMatch(
        m.copyWith(status: MatchStatus.live, startedAt: DateTime.now()),
      );
      match.value = m.copyWith(status: MatchStatus.live);
      Get.snackbar('بدأت المباراة ⚽', 'تم بدء المباراة!',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('MatchLobbyController.startMatch', e);
      Get.snackbar('خطأ', 'فشل بدء المباراة');
    }
  }

  /// إلغاء المباراة
  Future<void> cancelMatch() async {
    try {
      await _matchRepo.cancelMatch(matchId);
      Get.back();
      Get.snackbar('تم الإلغاء ❌', 'تم إلغاء المباراة',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('MatchLobbyController.cancelMatch', e);
      Get.snackbar('خطأ', 'فشل إلغاء المباراة');
    }
  }

  /// إضافة لاعب لفريق
  Future<void> addPlayer(String playerId, String side) async {
    try {
      await _matchRepo.addPlayerToMatch(
        matchId: matchId, playerId: playerId, side: side,
      );
      final player = await _playerRepo.getPlayer(playerId);
      if (player != null) {
        if (side == 'A') {
          teamAPlayers.add(player);
        } else {
          teamBPlayers.add(player);
        }
      }
      await _refreshMatch();
    } catch (e) {
      AppLogger.error('MatchLobbyController.addPlayer', e);
      Get.snackbar('خطأ', 'فشل إضافة اللاعب');
    }
  }

  /// إزالة لاعب من فريق
  Future<void> removePlayer(String playerId, String side) async {
    try {
      await _matchRepo.removePlayerFromMatch(
        matchId: matchId, playerId: playerId, side: side,
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

  /// دعوة صديق
  Future<void> inviteFriend(String friendId, String side) async {
    final uid = currentUserId;
    if (uid == null) return;
    
    // Check if already invited
    if (sentInvitations.any((inv) => inv.receiverId == friendId && inv.status == InvitationStatus.pending)) {
      Get.snackbar('تنبيه', 'تم إرسال دعوة لهذا اللاعب مسبقاً', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final invitation = MatchInvitation(
        id: const Uuid().v4(),
        matchId: matchId,
        senderId: uid,
        receiverId: friendId,
        side: side,
        createdAt: DateTime.now(),
      );

      await _invitationRepo.createInvitation(invitation);
      sentInvitations.add(invitation);
      Get.snackbar('تم ✅', 'تم إرسال الدعوة بنجاح', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('MatchLobbyController.inviteFriend', e);
      Get.snackbar('خطأ', 'فشل إرسال الدعوة');
    }
  }

  /// نسخ رابط الدعوة
  void copyInviteLink() {
    Clipboard.setData(ClipboardData(text: inviteLink));
    Get.snackbar('تم النسخ 📋', 'تم نسخ رابط الدعوة',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Future<void> refresh() => _loadMatch();

  Future<void> _refreshMatch() async {
    final m = await _matchRepo.getMatch(matchId);
    if (m != null) match.value = m;
  }

  /// تحديث موقع اللاعب في خطة اللعب
  void updatePlayerPosition(String playerId, Offset position) {
    playerPositions[playerId] = position;
  }

  /// إعادة تعيين خطة اللعب
  void resetFormation() {
    playerPositions.clear();
  }
}
