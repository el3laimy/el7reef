import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:el7reef/app/routes/app_routes.dart';
import 'package:el7reef/core/auth/auth_firebase_gateway.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';
import 'package:el7reef/data/repositories/player_repository_impl.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/features/profile/controllers/profile_controller.dart';
import 'package:el7reef/features/profile/views/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets(
    'account deletion reauthenticates before deleting and signs out',
    (tester) async {
      final authService = _FakeAuthService(player: _player());
      final cloudService = _FakeCloudSensitiveOpsService(result: true);
      final controller = _controller(authService, cloudService);

      await tester.pumpWidget(_testApp());
      final deleted = await controller.deleteAccount();
      await tester.pump();

      expect(find.text('تم قبول طلب الحذف'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(authService.calls, ['reauthenticate', 'signOut']);
      expect(cloudService.calls, 1);
      expect(Get.currentRoute, AppRoutes.login);
    },
  );

  testWidgets('failed cloud deletion keeps the signed-in session intact', (
    tester,
  ) async {
    final authService = _FakeAuthService(player: _player());
    final cloudService = _FakeCloudSensitiveOpsService(result: false);
    final controller = _controller(authService, cloudService);

    await tester.pumpWidget(_testApp());
    final deleted = await controller.deleteAccount();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(deleted, isFalse);
    expect(authService.calls, ['reauthenticate']);
    expect(cloudService.calls, 1);
    expect(controller.isDeletingAccount.value, isFalse);
  });

  testWidgets('destructive confirmation requires the exact Arabic phrase', (
    tester,
  ) async {
    final authService = _FakeAuthService(player: _player());
    final cloudService = _FakeCloudSensitiveOpsService(result: true);
    _controller(authService, cloudService);

    await tester.pumpWidget(_testApp(home: const ProfileScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('حذف الحساب نهائيًا'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('حذف الحساب نهائيًا'));
    await tester.pumpAndSettle();

    final confirmButton = find.widgetWithText(FilledButton, 'احذف حسابي');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'حذف الحساب');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'حذف');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    expect(cloudService.calls, 0);
  });
}

ProfileController _controller(
  _FakeAuthService authService,
  _FakeCloudSensitiveOpsService cloudService,
) {
  return Get.put(
    ProfileController(
      authService: authService,
      playerRepository: PlayerRepositoryImpl(
        firestore: FakeFirebaseFirestore(),
      ),
      cloudSensitiveOps: cloudService,
    ),
  );
}

Widget _testApp({Widget? home}) {
  return GetMaterialApp(
    initialRoute: '/',
    getPages: [
      GetPage(name: '/', page: () => home ?? const SizedBox()),
      GetPage(name: AppRoutes.login, page: () => const Text('تسجيل الدخول')),
    ],
  );
}

Player _player() {
  final now = DateTime(2026, 7, 11);
  return Player(
    id: 'player-1',
    name: 'لاعب الحريف',
    username: 'el7reef',
    createdAt: now,
    lastActiveAt: now,
  );
}

class _FakeAuthService extends AuthService {
  final List<String> calls = [];
  final String? _uid;

  _FakeAuthService({required Player player, String? uid = 'player-1'})
    : _uid = uid,
      super(
        authGateway: _NoopAuthGateway(),
        googleGateway: _NoopGoogleGateway(),
        playerRepository: PlayerRepositoryImpl(
          firestore: FakeFirebaseFirestore(),
        ),
      ) {
    currentPlayer.value = player;
  }

  @override
  String? get currentUserId => _uid;

  @override
  Future<void> reauthenticateWithGoogle() async {
    calls.add('reauthenticate');
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    currentPlayer.value = null;
  }
}

class _FakeCloudSensitiveOpsService extends CloudSensitiveOpsService {
  final bool result;
  int calls = 0;

  _FakeCloudSensitiveOpsService({required this.result});

  @override
  Future<bool> deleteAccountData() async {
    calls += 1;
    return result;
  }
}

class _NoopAuthGateway implements AuthFirebaseGateway {
  @override
  AuthFirebaseUser? get currentUser => null;

  @override
  Stream<AuthFirebaseUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthFirebaseUser?> signInWithCredential(
    AuthCredential credential,
  ) async => null;

  @override
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {}

  @override
  Future<void> signOut() async {}
}

class _NoopGoogleGateway implements AuthGoogleGateway {
  @override
  Future<GoogleSignInAccount?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}
