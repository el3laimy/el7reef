import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_invitation.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/repositories/match_invitation_repository.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../services/auth_service.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/enums/user_role.dart';
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
  final _snapshotRepo = Get.find<MatchLineupSnapshotRepositoryImpl>();

  // ── State ──
  final Rx<Match?> match = Rx<Match?>(null);
  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;
  final RxList<MatchInvitation> sentInvitations = <MatchInvitation>[].obs;
  final RxMap<String, Offset> playerPositions = <String, Offset>{}.obs;
  final RxBool isLoading = true.obs;
  final RxBool hasLockedSnapshots = false.obs;

  String get inviteLink => 'el7reef://match/join/$matchId';
  String? get currentUserId => _authService.currentUserId;
  bool get isOrganizer => match.value?.organizerId == currentUserId;
  int get effectiveTeamSize => normalizeMatchTeamSize(match.value?.teamSize);
  bool get canChangeTeamSize {
    final m = match.value;
    return m != null &&
        m.tournamentId == null &&
        m.status == MatchStatus.open &&
        isOrganizer &&
        !hasLockedSnapshots.value;
  }

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
        _loadSnapshotState(),
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

  Future<void> _loadSnapshotState() async {
    try {
      final snapshots = await _snapshotRepo.getMatchSnapshots(matchId);
      hasLockedSnapshots.value = snapshots.isNotEmpty;
    } catch (e) {
      AppLogger.error('MatchLobbyController._loadSnapshotState', e);
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
      Get.snackbar(
        'بدأت المباراة ⚽',
        'تم بدء المباراة!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.startMatch', e);
      Get.snackbar('خطأ', 'فشل بدء المباراة');
    }
  }

  Future<bool> updateTeamSize(int teamSize) async {
    final m = match.value;
    if (m == null) return false;
    if (m.tournamentId != null) {
      Get.snackbar(
        'غير متاح',
        'حجم مباراة البطولة يتم التحكم فيه من إعدادات البطولة.',
      );
      return false;
    }
    if (!isOrganizer) {
      Get.snackbar('غير مسموح', 'منشئ المباراة فقط يمكنه تغيير عدد اللاعبين.');
      return false;
    }
    if (m.status != MatchStatus.open) {
      Get.snackbar('غير متاح', 'لا يمكن تغيير عدد اللاعبين بعد بدء المباراة.');
      return false;
    }
    await _loadSnapshotState();
    if (hasLockedSnapshots.value) {
      Get.snackbar('غير متاح', 'لا يمكن تغيير عدد اللاعبين بعد قفل أي تشكيلة.');
      return false;
    }
    final nextSize = normalizeMatchTeamSize(teamSize);
    if (nextSize == m.teamSize) {
      return true;
    }
    try {
      final updated = m.copyWith(teamSize: nextSize);
      await _matchRepo.updateMatch(updated);
      match.value = updated;
      Get.snackbar(
        'تم تحديث حجم المباراة',
        'تم تغيير المباراة إلى ${nextSize}v$nextSize. هذا يؤثر على الفريقين.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      AppLogger.error('MatchLobbyController.updateTeamSize', e);
      Get.snackbar('خطأ', 'فشل تغيير عدد اللاعبين');
      return false;
    }
  }

  /// إلغاء المباراة
  Future<void> cancelMatch() async {
    try {
      await _matchRepo.cancelMatch(matchId);
      Get.back();
      Get.snackbar(
        'تم الإلغاء ❌',
        'تم إلغاء المباراة',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.cancelMatch', e);
      Get.snackbar('خطأ', 'فشل إلغاء المباراة');
    }
  }

  /// إضافة لاعب لفريق
  Future<void> addPlayer(String playerId, String side) async {
    try {
      await _matchRepo.addPlayerToMatch(
        matchId: matchId,
        playerId: playerId,
        side: side,
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

  /// إضافة لاعب ضيف (Guest)
  Future<bool> addGuestPlayer(String name, String side) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        Get.snackbar('خطأ', 'اسم اللاعب الضيف مطلوب.');
        return false;
      }
      final guestId = const Uuid().v4();
      final guestPlayer = Player(
        id: guestId,
        name: trimmed,
        isGuest: true,
        role: UserRole.player,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Save to players collection
      await _playerRepo.createPlayer(guestPlayer);

      // Add to match
      await _matchRepo.addPlayerToMatch(
        matchId: matchId,
        playerId: guestId,
        side: side,
      );

      if (side == 'A') {
        teamAPlayers.add(guestPlayer);
      } else {
        teamBPlayers.add(guestPlayer);
      }

      Get.snackbar(
        'تم',
        'تم إضافة اللاعب الضيف $trimmed بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _refreshMatch();
      return true;
    } catch (e) {
      AppLogger.error('MatchLobbyController.addGuestPlayer', e);
      Get.snackbar('خطأ', 'فشل إضافة اللاعب الضيف');
      return false;
    }
  }

  /// إزالة لاعب من فريق
  Future<void> removePlayer(String playerId, String side) async {
    try {
      await _matchRepo.removePlayerFromMatch(
        matchId: matchId,
        playerId: playerId,
        side: side,
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
    if (sentInvitations.any(
      (inv) =>
          inv.receiverId == friendId && inv.status == InvitationStatus.pending,
    )) {
      Get.snackbar(
        'تنبيه',
        'تم إرسال دعوة لهذا اللاعب مسبقاً',
        snackPosition: SnackPosition.BOTTOM,
      );
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
      Get.snackbar(
        'تم ✅',
        'تم إرسال الدعوة بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.inviteFriend', e);
      Get.snackbar('خطأ', 'فشل إرسال الدعوة');
    }
  }

  /// نسخ رابط الدعوة
  void copyInviteLink() {
    Clipboard.setData(ClipboardData(text: inviteLink));
    Get.snackbar(
      'تم النسخ 📋',
      'تم نسخ رابط الدعوة',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Future<void> refresh() => _loadMatch();

  Future<void> _refreshMatch() async {
    final m = await _matchRepo.getMatch(matchId);
    if (m != null) match.value = m;
    await _loadSnapshotState();
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
