import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/data/repositories/team_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/team/controllers/team_controller.dart';
import 'package:el7reef/features/team/views/my_teams_screen.dart';

void main() {
  setUp(() {
    Get.testMode = true;

    final authService = _FakeAuthService(currentUserId: 'player-1');
    final teamRepository = TeamRepositoryImpl(
      firestore: FakeFirebaseFirestore(),
    );

    Get.put<AuthService>(authService);
    Get.put<TeamController>(
      TeamController(authService: authService, teamRepository: teamRepository),
    );
  });

  tearDown(Get.reset);

  testWidgets('empty my teams state opens create team sheet', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: MyTeamsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('كوّن فريقك الأول'), findsOneWidget);
    expect(find.text('إنشاء فريق الآن'), findsOneWidget);

    await tester.tap(find.text('إنشاء فريق الآن'));
    await tester.pumpAndSettle();

    expect(find.text('إنشاء فريق جديد 🏆'), findsOneWidget);
    expect(find.text('اسم الفريق'), findsOneWidget);
  });
}

class _FakeAuthService extends GetxService implements AuthService {
  @override
  final Rx<Player?> currentPlayer = Rx<Player?>(null);

  @override
  final RxBool isLoading = false.obs;

  @override
  final Rx<AuthProfileStatus> profileStatus = AuthProfileStatus.ready.obs;

  @override
  final RxString profileErrorMessage = ''.obs;

  final String? _currentUserId;

  _FakeAuthService({required String? currentUserId})
    : _currentUserId = currentUserId {
    final now = DateTime(2026, 7, 3, 10);
    currentPlayer.value = currentUserId == null
        ? null
        : Player(
            id: currentUserId,
            name: 'Test Player',
            createdAt: now,
            lastActiveAt: now,
          );
  }

  @override
  bool get isLoggedIn => _currentUserId != null;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<AuthService> init() async => this;

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<Player?> signInWithGoogle() async => currentPlayer.value;

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
