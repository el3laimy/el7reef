import '../../domain/entities/player.dart';

/// Lightweight auth/session contract used by features that only need the
/// current user identity and loaded player profile.
abstract class AuthSession {
  String? get currentUserId;
  Player? get currentPlayer;
}
