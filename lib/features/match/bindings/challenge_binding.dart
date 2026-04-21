import 'package:get/get.dart';
import '../../../data/repositories/challenge_repository_impl.dart';
import '../../../data/repositories/match_repository_impl.dart';
import '../../../domain/repositories/challenge_repository.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../services/auth_service.dart';
import '../controllers/challenge_controller.dart';

class ChallengeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ChallengeRepository>()) {
      Get.lazyPut<ChallengeRepository>(() => ChallengeRepositoryImpl());
    }
    if (!Get.isRegistered<MatchRepository>()) {
      Get.lazyPut<MatchRepository>(() => MatchRepositoryImpl());
    }
    Get.lazyPut<ChallengeController>(
      () => ChallengeController(
        challengeRepo: Get.find<ChallengeRepository>(),
        matchRepo: Get.find<MatchRepository>(),
        authService: Get.find<AuthService>(),
      ),
    );
  }
}
