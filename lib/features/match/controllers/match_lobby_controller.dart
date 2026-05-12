import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/match_invitation.dart';
import '../../../domain/entities/match_side.dart';
import '../../../domain/entities/match_side_player.dart';
import '../../../domain/entities/player.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/repositories/match_invitation_repository.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../data/repositories/match_side_player_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/services/match_cancellation_service.dart';
import '../../../core/services/match_start_service.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/utils/app_logger.dart';
import '../models/friendly_match_side_view.dart';

part 'match_lobby_player_ops.dart';

class MatchLobbyController extends GetxController {
  final MatchRepository _matchRepo;
  final MatchInvitationRepository _invitationRepo;
  final String matchId;

  MatchLobbyController({required this.matchId})
    : _matchRepo = Get.find<MatchRepository>(),
      _invitationRepo = Get.find<MatchInvitationRepository>();

  final _authService = Get.find<AuthService>();
  final _playerRepo = Get.find<PlayerRepositoryImpl>();
  final _teamRepo = Get.find<TeamRepositoryImpl>();
  final _sideRepo = Get.find<MatchSideRepositoryImpl>();
  final _sidePlayerRepo = Get.find<MatchSidePlayerRepositoryImpl>();
  final _snapshotRepo = Get.find<MatchLineupSnapshotRepositoryImpl>();
  final _matchStartService = Get.find<MatchStartService>();
  final _matchCancellationService = Get.find<MatchCancellationService>();

  // ── State ──
  final Rx<Match?> match = Rx<Match?>(null);
  final RxList<FriendlyMatchSideView> sideViews = <FriendlyMatchSideView>[].obs;
  final RxList<Player> teamAPlayers = <Player>[].obs;
  final RxList<Player> teamBPlayers = <Player>[].obs;
  final RxList<MatchInvitation> sentInvitations = <MatchInvitation>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool hasLockedSnapshots = false.obs;
  final Rx<MatchStartReadiness> startReadiness = Rx<MatchStartReadiness>(
    const MatchStartReadiness(canStart: false),
  );

  String get inviteLink => 'el7reef://match/join/$matchId';
  String? get currentUserId => _authService.currentUserId;
  bool get isOrganizer => match.value?.organizerId == currentUserId;
  bool get isFriendlyMatchHost {
    final m = match.value;
    final uid = currentUserId;
    return m != null &&
        m.tournamentId == null &&
        uid != null &&
        uid.isNotEmpty &&
        m.organizerId == uid;
  }

  int get effectiveTeamSize => normalizeMatchTeamSize(match.value?.teamSize);
  bool get canChangeTeamSize {
    final m = match.value;
    return m != null &&
        m.tournamentId == null &&
        m.status == MatchStatus.open &&
        isOrganizer &&
        !hasLockedSnapshots.value;
  }

  bool get canCancelMatch {
    final m = match.value;
    return m != null &&
        m.tournamentId == null &&
        isOrganizer &&
        !m.isFrozen &&
        (m.status == MatchStatus.open || m.status == MatchStatus.full);
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
        _loadSideViews(m),
        _loadPlayers(m),
        _loadInvitations(),
        _loadSnapshotState(),
      ]);
      if (currentUserId != null) {
        startReadiness.value = await _matchStartService.getStartReadiness(
          matchId: matchId,
          actorId: currentUserId!,
        );
      }
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

  Future<void> _loadSideViews(Match m) async {
    final teamIds = <String>[
      if (m.teamAId != null && m.teamAId!.isNotEmpty) m.teamAId!,
      if (m.teamBId != null && m.teamBId!.isNotEmpty) m.teamBId!,
    ];
    final teams = await _teamRepo.getTeamsByIds(teamIds);
    final teamsById = {for (final team in teams) team.id: team};
    final actorId = currentUserId;
    if (m.tournamentId == null &&
        actorId != null &&
        actorId.isNotEmpty &&
        m.organizerId == actorId) {
      await _sideRepo.ensureFriendlySides(
        match: m,
        actorId: actorId,
        teamADisplayName: teamsById[m.teamAId]?.name ?? 'فريق A',
        teamBDisplayName: teamsById[m.teamBId]?.name ?? 'فريق B',
      );
    }
    final results = await Future.wait<dynamic>([
      _sideRepo.getMatchSides(m.id),
      _sidePlayerRepo.getMatchPlayers(m.id),
    ]);
    final sides = results[0] as List<MatchSide>;
    final sidePlayers = results[1] as List<MatchSidePlayer>;
    sideViews.assignAll(
      FriendlyMatchSideView.fromMatch(
        match: m,
        teamsById: teamsById,
        sides: sides,
        sidePlayers: sidePlayers,
      ),
    );
  }

  Future<void> startMatch() async {
    final m = match.value;
    if (m == null) return;
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    try {
      final started = await _matchStartService.startMatch(
        matchId: matchId,
        actorId: actorId,
      );
      match.value = started;
      Get.snackbar(
        'بدأت المباراة ⚽',
        'تم بدء المباراة!',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('MatchLobbyController.startMatch', e);
      Get.snackbar('خطأ', _readableError(e));
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

  Future<void> cancelMatch({String? reason}) async {
    final actorId = currentUserId;
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('غير مسموح', 'يجب تسجيل الدخول أولاً.');
      return;
    }
    try {
      final cancelled = await _matchCancellationService.cancelFriendlyMatch(
        matchId: matchId,
        actorId: actorId,
        reason: reason,
      );
      match.value = cancelled;
      Get.snackbar(
        'تم الإلغاء ❌',
        'تم إلغاء المباراة',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.back();
    } catch (e) {
      AppLogger.error('MatchLobbyController.cancelMatch', e);
      Get.snackbar('خطأ', _readableError(e));
    }
  }

  Future<void> addPlayer(String playerId, String side) async {
    await addRegisteredPlayerToSide(playerId: playerId, sideKey: side);
  }

  Future<void> inviteFriend(String friendId, String side) async {
    final uid = currentUserId;
    if (uid == null) return;

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
    if (m != null) {
      match.value = m;
      await _loadSideViews(m);
      if (currentUserId != null) {
        startReadiness.value = await _matchStartService.getStartReadiness(
          matchId: matchId,
          actorId: currentUserId!,
        );
      }
    }
    await _loadSnapshotState();
  }

  String _readableError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.substring('Bad state: '.length);
    }
    return raw;
  }

  FriendlyMatchSideView? _sideViewFor(String sideKey) {
    for (final side in sideViews) {
      if (side.sideKey == sideKey) return side;
    }
    return null;
  }
}
