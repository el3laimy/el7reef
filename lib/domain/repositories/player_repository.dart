import '../entities/player.dart';
import '../entities/player_match_stats.dart';

/// عقد مستودع اللاعب — الواجهة المجردة
abstract class PlayerRepository {
  /// جلب بيانات لاعب بالـ ID
  Future<Player?> getPlayer(String playerId);
  Future<List<Player>> getPlayersByIds(List<String> playerIds);

  /// إنشاء لاعب جديد
  Future<void> createPlayer(Player player);

  /// تحديث بيانات لاعب
  Future<void> updatePlayer(Player player);

  /// البحث عن لاعبين بالاسم
  Future<List<Player>> searchPlayers(String query);

  /// جلب المتصدرين
  Future<List<Player>> getLeaderboard({int limit = 50});

  /// تحديث rating اللاعب
  Future<void> updateRating(String playerId, int newRating);

  /// تحديث إحصائيات اللاعب بعد المباراة
  Future<void> updateMatchStats({
    required String playerId,
    required bool isWin,
    required bool isDraw,
    required bool isMvp,
    PlayerMatchStats? detailedStats,
  });
}
