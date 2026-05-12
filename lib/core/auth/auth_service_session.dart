import '../../domain/entities/player.dart';
import '../../core/auth/auth_service.dart';
import 'auth_session.dart';

class AuthServiceSession implements AuthSession {
  final AuthService _authService;

  AuthServiceSession(this._authService);

  @override
  String? get currentUserId => _authService.currentUserId;

  @override
  Player? get currentPlayer => _authService.currentPlayer.value;
}
