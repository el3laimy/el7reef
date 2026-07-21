import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:el7reef/core/auth/auth_firebase_gateway.dart';
import 'package:el7reef/core/auth/auth_service.dart';
import 'package:el7reef/core/auth/session_reset_coordinator.dart';
import 'package:el7reef/domain/entities/player.dart';
import 'package:el7reef/domain/repositories/player_repository.dart';

void main() {
  test('profile load failure keeps auth session and requires repair', () async {
    final authGateway = _FakeAuthGateway(
      currentUser: const _FakeFirebaseUser(uid: 'player-1'),
    );
    final googleGateway = _FakeGoogleGateway();
    final authService = AuthService(
      authGateway: authGateway,
      googleGateway: googleGateway,
      playerRepository: _FailingPlayerRepository(),
      sessionResetCoordinator: SessionResetCoordinator(),
    );

    await authService.init();

    expect(authService.isLoggedIn, isTrue);
    expect(authService.currentUserId, 'player-1');
    expect(authService.currentPlayer.value, isNull);
    expect(authService.profileStatus.value, AuthProfileStatus.repairRequired);
    expect(authService.profileErrorMessage.value, contains('صلاحيات'));
    expect(authGateway.signOutCalls, 0);
    expect(googleGateway.signOutCalls, 0);
  });
}

class _FakeAuthGateway implements AuthFirebaseGateway {
  AuthFirebaseUser? _currentUser;
  int signOutCalls = 0;

  _FakeAuthGateway({required AuthFirebaseUser? currentUser})
    : _currentUser = currentUser;

  @override
  AuthFirebaseUser? get currentUser => _currentUser;

  @override
  Stream<AuthFirebaseUser?> authStateChanges() => const Stream.empty();

  @override
  Future<AuthFirebaseUser?> signInWithCredential(AuthCredential credential) {
    return Future.value(_currentUser);
  }

  @override
  Future<void> reauthenticateWithCredential(AuthCredential credential) async {}

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _currentUser = null;
  }
}

class _FakeGoogleGateway implements AuthGoogleGateway {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async => null;
}

class _FakeFirebaseUser implements AuthFirebaseUser {
  @override
  final String uid;

  const _FakeFirebaseUser({required this.uid});

  @override
  String? get displayName => 'لاعب';

  @override
  String? get phoneNumber => null;

  @override
  String? get photoURL => null;
}

class _FailingPlayerRepository implements PlayerRepository {
  @override
  Future<Player?> getPlayer(String playerId) {
    throw StateError('PERMISSION_DENIED');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
