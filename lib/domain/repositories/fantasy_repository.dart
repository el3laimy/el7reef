import '../entities/fantasy_team.dart';
import '../entities/fantasy_slot.dart';
import '../entities/player_fantasy_value.dart';
import '../entities/transfer_record.dart';

/// مسودة العمليات الأساسية لمستودع بيانات الفانتازي
abstract class FantasyRepository {
  /// جلب فريق فانتازي لمستخدم معين
  Future<FantasyTeam?> getFantasyTeam(String ownerPlayerId);
  
  /// إنشاء فريق فانتازي جديد
  Future<void> createFantasyTeam(FantasyTeam team, List<FantasySlot> slots);
  
  /// تحديث بيانات فريق الفانتازي (الميزانية والنقاط إلخ)
  Future<void> updateFantasyTeam(FantasyTeam team);

  /// جلب التشكيلة (الخانات) الخاصة بفريق معين
  Future<List<FantasySlot>> getTeamSlots(String fantasyTeamId);
  
  /// تحديث خانة واحدة (مثال: لاعب احتياط دخل مكان أساسي)
  Future<void> updateFantasySlot(FantasySlot slot);
  
  /// إجراء عملية تبديل كاملة (بيع وشراء) في خطوة واحدة لضمان أمان البيانات
  Future<void> processTransfer(FantasyTeam team, TransferRecord record, List<FantasySlot> updatedSlots);

  /// جلب قيمة وتصنيف لاعب في البورصة
  Future<PlayerFantasyValue?> getPlayerFantasyValue(String playerId);
  
  /// تحديث قيمة وتصنيف لاعب (يستخدمه محرك الأسعار في الخلفية)
  Future<void> updatePlayerFantasyValue(PlayerFantasyValue value);

  /// جلب تاريخ تبديلات فريق فانتازي معين
  Future<List<TransferRecord>> getTeamTransfers(String fantasyTeamId);
}
