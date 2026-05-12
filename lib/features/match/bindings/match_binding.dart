import 'package:get/get.dart';
import '../controllers/match_controller.dart';
import '../controllers/challenge_controller.dart';
import '../../../domain/repositories/challenge_repository.dart';
import '../../../data/repositories/challenge_repository_impl.dart';
import '../../../core/auth/auth_service.dart';
import '../../../domain/repositories/match_repository.dart';
import '../../../data/repositories/match_repository_impl.dart';

class MatchBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ChallengeRepository>()) {
      Get.lazyPut<ChallengeRepository>(() => ChallengeRepositoryImpl());
    }
    if (!Get.isRegistered<MatchRepository>()) {
      Get.lazyPut<MatchRepository>(() => MatchRepositoryImpl());
    }
    Get.lazyPut<MatchController>(() => MatchController());
    Get.lazyPut<ChallengeController>(
      () => ChallengeController(
        challengeRepo: Get.find<ChallengeRepository>(),
        authService: Get.find<AuthService>(),
      ),
    );
  }
}
