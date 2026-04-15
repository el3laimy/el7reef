import 'fantasy_chip.dart';

/// كيان تفاصيل فريق الفانتازي الخاص بأحد المستخدمين
class FantasyTeam {
  /// معرف الفريق (غالباً يتطابق مع معرف اللاعب المالك userId)
  final String id;
  
  /// معرف اللاعب مالك التشكيلة
  final String ownerPlayerId;
  
  /// اسم فريق الفانتازي (مثل: أبطال الحريف)
  final String teamName;

  /// الدوريات التي يشارك فيها الفريق.
  /// يتم إدراج `global` افتراضياً حتى يظهر كل فريق في الترتيب العام.
  final List<String> leagueIds;
  
  /// الميزانية المتبقية (تبدأ بـ 100 مليون مثلاً)
  final double budget;
  
  /// إجمالي النقاط التي حصدها الفريق منذ بداية الموسم
  final int totalPoints;
  
  /// نقاط الجولة الحالية فقط
  final int currentGameweekPoints;
  
  /// عدد التبديلات المجانية المتبقية هذا الأسبوع
  final int freeTransfers;

  /// آخر جولة تمت مزامنة رصيد التبديلات المجانية لها.
  /// القيمة `0` تعني أن الفريق قديم ولم يُرحّل بعد إلى نظام التتبع الحالي.
  final int freeTransfersGameweek;
  
  /// إجمالي التبديلات التي أجراها المدرب طول الموسم
  final int totalTransfers;
  
  /// خطة اللعب (مثال: '2-1-1' في خماسي أو '4-3-3' في 11)
  final String formation;
  
  /// سجلات تفعيل الخواص على مستوى الجولات المختلفة.
  final List<ChipUsage> chipUsages;
  
  /// تاريخ الإنشاء
  final DateTime createdAt;
  
  /// آخر عملية تحديث
  final DateTime updatedAt;

  const FantasyTeam({
    required this.id,
    required this.ownerPlayerId,
    required this.teamName,
    this.leagueIds = const ['global'],
    this.budget = 100.0,
    this.totalPoints = 0,
    this.currentGameweekPoints = 0,
    this.freeTransfers = 1,
    this.freeTransfersGameweek = 0,
    this.totalTransfers = 0,
    this.formation = '2-1-1', 
    this.chipUsages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  List<ChipUsage> activeChipsForGameweek(int gameweek) {
    return chipUsages
        .where((usage) => usage.isActiveInGameweek(gameweek))
        .toList(growable: false);
  }

  List<String> activeChipLabelsForGameweek(int gameweek) {
    return activeChipsForGameweek(gameweek)
        .map((usage) => usage.displayName)
        .toList(growable: false);
  }

  bool hasActiveChip(
    ChipType chipType, {
    required int gameweek,
  }) {
    return activeChipsForGameweek(gameweek)
        .any((usage) => usage.chipType == chipType);
  }

  bool hasConsumedChip(ChipType chipType) {
    return chipUsages.any((usage) => usage.chipType == chipType);
  }

  FantasyTeam copyWith({
    String? id,
    String? ownerPlayerId,
    String? teamName,
    List<String>? leagueIds,
    double? budget,
    int? totalPoints,
    int? currentGameweekPoints,
    int? freeTransfers,
    int? freeTransfersGameweek,
    int? totalTransfers,
    String? formation,
    List<ChipUsage>? chipUsages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FantasyTeam(
      id: id ?? this.id,
      ownerPlayerId: ownerPlayerId ?? this.ownerPlayerId,
      teamName: teamName ?? this.teamName,
      leagueIds: leagueIds ?? this.leagueIds,
      budget: budget ?? this.budget,
      totalPoints: totalPoints ?? this.totalPoints,
      currentGameweekPoints: currentGameweekPoints ?? this.currentGameweekPoints,
      freeTransfers: freeTransfers ?? this.freeTransfers,
      freeTransfersGameweek:
          freeTransfersGameweek ?? this.freeTransfersGameweek,
      totalTransfers: totalTransfers ?? this.totalTransfers,
      formation: formation ?? this.formation,
      chipUsages: chipUsages ?? this.chipUsages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
