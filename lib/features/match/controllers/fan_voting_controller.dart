import 'dart:async';
import 'package:get/get.dart';
import '../../../core/services/fan_voting_service.dart';
import '../../../services/auth_service.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../domain/entities/fan_voting_session.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/entities/player.dart';

class FanVotingController extends GetxController {
  final Match match;
  final FanVotingService _votingService;
  final PlayerRepositoryImpl _playerRepo;
  final AuthService _authService;

  FanVotingController({
    required this.match,
  })  : _votingService = FanVotingService(),
        _playerRepo = PlayerRepositoryImpl(),
        _authService = Get.find<AuthService>();

  final Rx<FanVotingSession?> session = Rx<FanVotingSession?>(null);
  final RxList<Player> players = <Player>[].obs;
  
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;
  final RxBool hasVoted = false.obs;

  // Countdown string (HH:MM:SS)
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
    try {
      // 1. Fetch Session
      session.value = await _votingService.getSession(match.id);
      if (session.value == null) {
        errorMessage.value = 'لا توجد جلسة تصويت مفتوحة لهذه المباراة.';
        return;
      }

      // 2. Check if current user voted
      final userId = _authService.currentPlayer.value!.id;
      hasVoted.value = await _votingService.hasUserVoted(match.id, userId);

      // 3. Load all participating players
      final playerIds = [...match.teamAPlayerIds, ...match.teamBPlayerIds];
      final fetches = playerIds.map((id) => _playerRepo.getPlayer(id));
      final results = await Future.wait(fetches);
      players.value = results.whereType<Player>().toList();

      // 4. Start Countdown Timer
      _startTimer();
      
    } catch (e) {
      errorMessage.value = 'حدث خطأ أثناء تحميل بيانات التصويت: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    final s = session.value;
    if (s == null) return;

    if (s.isClosed) {
      timeRemaining.value = 'المدة انتهت';
      _timer?.cancel();
      return;
    }

    if (!s.isOpen) {
      timeRemaining.value = 'لم يبدأ بعد';
      return;
    }

    final diff = s.closesAt.difference(DateTime.now());
    if (diff.isNegative) {
      timeRemaining.value = 'المدة انتهت';
      _timer?.cancel();
    } else {
      final hh = diff.inHours.toString().padLeft(2, '0');
      final mm = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
      timeRemaining.value = '$hh:$mm:$ss';
    }
  }

  Future<void> submitVote(String targetPlayerId) async {
    if (hasVoted.value) {
      Get.snackbar('تصويت مسجل', 'لقد قمت بالتصويت بالفعل لهذه المباراة.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    
    isLoading.value = true;
    errorMessage.value = '';
    
    try {
      final userId = _authService.currentPlayer.value!.id;
      await _votingService.voteForPlayer(
        matchId: match.id,
        userId: userId,
        targetPlayerId: targetPlayerId,
      );
      hasVoted.value = true;
      successMessage.value = 'تم إرسال تصويتك بنجاح! شكراً لمشاركتك.';
    } catch (e) {
      errorMessage.value = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      isLoading.value = false;
    }
  }
}
