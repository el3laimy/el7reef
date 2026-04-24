import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../core/enums/challenge_status.dart';
import '../../../core/enums/match_status.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/challenge.dart';
import '../../../domain/entities/match.dart';
import '../../../domain/repositories/challenge_repository.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../domain/repositories/player_repository.dart';
import '../../../data/repositories/player_repository_impl.dart';
import '../../../services/auth_service.dart';

class ChallengeController extends GetxController {
  final ChallengeRepository _challengeRepo;
  final MatchRepository _matchRepo;
  final AuthService _authService;

  ChallengeController({
    required ChallengeRepository challengeRepo,
    required MatchRepository matchRepo,
    required AuthService authService,
  }) : _challengeRepo = challengeRepo,
       _matchRepo = matchRepo,
       _authService = authService;

  final RxList<Challenge> sentChallenges = <Challenge>[].obs;
  final RxList<Challenge> receivedChallenges = <Challenge>[].obs;
  final RxBool isLoading = false.obs;
  final RxMap<String, String> playerNames = <String, String>{}.obs;

  final PlayerRepository _playerRepo = PlayerRepositoryImpl();

  String? get currentUserId => _authService.currentUserId;

  @override
  void onInit() {
    super.onInit();
    if (currentUserId != null) {
      loadChallenges();
    }
    ever(_authService.currentPlayer, (player) {
      if (player != null) {
        loadChallenges();
      } else {
        sentChallenges.clear();
        receivedChallenges.clear();
      }
    });
  }

  Future<void> loadChallenges() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      isLoading.value = true;
      final results = await Future.wait([
        _challengeRepo.getSentChallenges(uid),
        _challengeRepo.getReceivedChallenges(uid),
      ]);
      sentChallenges.value = results[0];
      receivedChallenges.value = results[1];

      // Fetch names
      final allIds = <String>{};
      for (var c in sentChallenges) {
        allIds.add(c.challengedId);
      }
      for (var c in receivedChallenges) {
        allIds.add(c.challengerId);
      }

      final missingIds = allIds
          .where((id) => !playerNames.containsKey(id))
          .toList();
      if (missingIds.isNotEmpty) {
        final players = await _playerRepo.getPlayersByIds(missingIds);
        for (var p in players) {
          playerNames[p.id] = p.name;
        }
      }
    } catch (e) {
      AppLogger.error('ChallengeController.loadChallenges', e);
    } finally {
      isLoading.value = false;
    }
  }

  String getPlayerName(String id) {
    if (playerNames.containsKey(id)) {
      return playerNames[id]!;
    }
    return 'لاعب ${id.length >= 5 ? id.substring(0, 5) : id}';
  }

  Future<void> sendChallenge({
    required String challengedId,
    String? challengerTeamId,
    String? challengedTeamId,
    String? message,
    String? location,
    required int teamSize,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final challenge = Challenge(
        id: const Uuid().v4(),
        challengerId: uid,
        challengedId: challengedId,
        challengerTeamId: challengerTeamId,
        challengedTeamId: challengedTeamId,
        message: message,
        location: location,
        teamSize: teamSize,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      );

      await _challengeRepo.createChallenge(challenge);
      sentChallenges.insert(0, challenge);
      Get.back(); // Close sheet
      Get.snackbar(
        'تم',
        'تم إرسال التحدي بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('ChallengeController.sendChallenge', e);
      Get.snackbar('خطأ', 'فشل إرسال التحدي');
    }
  }

  Future<void> acceptChallenge(Challenge challenge) async {
    final uid = currentUserId;
    if (uid == null || challenge.challengedId != uid) return;

    if (challenge.status != ChallengeStatus.pending) {
      Get.snackbar(
        'عذراً',
        'هذا التحدي لم يعد متاحاً',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (challenge.expiresAt.isBefore(DateTime.now())) {
      Get.snackbar(
        'عذراً',
        'انتهت صلاحية هذا التحدي',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _challengeRepo.updateChallengeStatus(
        challenge.id,
        ChallengeStatus.expired,
      );
      await loadChallenges();
      return;
    }

    try {
      // 1. Create a Match
      final matchId = const Uuid().v4();
      final match = Match(
        id: matchId,
        organizerId: challenge.challengerId,
        status: MatchStatus.open,
        createdAt: DateTime.now(),
        location: challenge.location,
        teamSize: normalizeMatchTeamSize(challenge.teamSize),
        teamAPlayerIds: [challenge.challengerId],
        teamBPlayerIds: [challenge.challengedId],
        teamAId: challenge.challengerTeamId,
        teamBId: challenge.challengedTeamId,
        isOrganized: false,
      );

      await _matchRepo.createMatch(match);

      // 2. Update Challenge
      await _challengeRepo.updateChallengeStatus(
        challenge.id,
        ChallengeStatus.accepted,
        matchId: matchId,
      );

      await loadChallenges();

      Get.snackbar(
        'تم',
        'تم قبول التحدي وإنشاء المباراة',
        snackPosition: SnackPosition.BOTTOM,
      );

      // 3. Go to Lobby
      Get.toNamed('/match/lobby/$matchId');
    } catch (e) {
      AppLogger.error('ChallengeController.acceptChallenge', e);
      Get.snackbar('خطأ', 'فشل قبول التحدي');
    }
  }

  Future<void> declineChallenge(String challengeId) async {
    try {
      await _challengeRepo.updateChallengeStatus(
        challengeId,
        ChallengeStatus.declined,
      );
      await loadChallenges();
      Get.snackbar('تم', 'تم رفض التحدي', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      AppLogger.error('ChallengeController.declineChallenge', e);
    }
  }

  Future<void> cancelChallenge(String challengeId) async {
    try {
      await _challengeRepo.cancelChallenge(challengeId);
      await loadChallenges();
      Get.snackbar(
        'تم',
        'تم إلغاء التحدي',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      AppLogger.error('ChallengeController.cancelChallenge', e);
    }
  }
}
