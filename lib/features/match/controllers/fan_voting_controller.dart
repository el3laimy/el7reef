import 'dart:async';

import 'package:get/get.dart';

import '../../../core/services/fan_voting_service.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/fan_voting_session.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/player.dart';
import '../../../services/auth_service.dart';

class FanVotingController extends GetxController {
  final String matchId;
  final FanVotingService _votingService = FanVotingService();
  final MatchRepositoryImpl _matchRepo = MatchRepositoryImpl();
  final PlayerRepositoryImpl _playerRepo = PlayerRepositoryImpl();
  final AuthService _authService = Get.find<AuthService>();

  FanVotingController({required this.matchId});

  final Rx<Match?> match = Rx<Match?>(null);
  final Rx<FanVotingSession?> session = Rx<FanVotingSession?>(null);
  final RxList<Player> players = <Player>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;
  final RxBool hasVoted = false.obs;
  final RxString timeRemaining = ''.obs;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _initData();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> _initData() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final loadedMatch = await _matchRepo.getMatch(matchId);
      if (loadedMatch == null) {
        errorMessage.value = 'لا توجد مباراة بهذا المعرف.';
        return;
      }
      match.value = loadedMatch;

      session.value = await _votingService.getSession(matchId);
      if (session.value == null) {
        errorMessage.value = 'لا توجد جلسة تصويت مفتوحة لهذه المباراة.';
        return;
      }

      final currentUserId = _authService.currentUserId;
      if (currentUserId != null) {
        hasVoted.value = await _votingService.hasUserVoted(
          matchId,
          currentUserId,
        );
      }

      final playerIds = [...loadedMatch.teamAPlayerIds, ...loadedMatch.teamBPlayerIds];
      final results = await Future.wait(
        playerIds.map((id) => _playerRepo.getPlayer(id)),
      );
      players.value = results.whereType<Player>().toList();
      _startTimer();
    } catch (error) {
      errorMessage.value = 'حدث خطأ أثناء تحميل بيانات التصويت: $error';
    } finally {
      isLoading.value = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final currentSession = session.value;
    if (currentSession == null) return;

    if (currentSession.isClosed) {
      timeRemaining.value = 'المدة انتهت';
      _timer?.cancel();
      return;
    }

    if (!currentSession.isOpen) {
      timeRemaining.value = 'لم يبدأ بعد';
      return;
    }

    final diff = currentSession.closesAt.difference(DateTime.now());
    if (diff.isNegative) {
      timeRemaining.value = 'المدة انتهت';
      _timer?.cancel();
      return;
    }

    final hh = diff.inHours.toString().padLeft(2, '0');
    final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
    timeRemaining.value = '$hh:$mm:$ss';
  }

  Future<void> submitVote(String targetPlayerId) async {
    if (hasVoted.value) {
      Get.snackbar(
        'تصويت مسجل',
        'لقد قمت بالتصويت بالفعل لهذه المباراة.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      await _votingService.voteForPlayer(
        matchId: matchId,
        userId: currentUserId,
        targetPlayerId: targetPlayerId,
      );
      hasVoted.value = true;
      successMessage.value = 'تم إرسال تصويتك بنجاح! شكراً لمشاركتك.';
    } catch (error) {
      errorMessage.value =
          error.toString().replaceAll('Exception:', '').trim();
    } finally {
      isLoading.value = false;
    }
  }
}
