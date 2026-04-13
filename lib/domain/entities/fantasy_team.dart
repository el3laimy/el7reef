/// كيان تفاصيل فريق الفانتازي الخاص بأحد المستخدمين
class FantasyTeam {
  /// معرف الفريق (غالباً يتطابق مع معرف اللاعب المالك userId)
  final String id;
  
  /// معرف اللاعب مالك التشكيلة
  final String ownerPlayerId;
  
  /// اسم فريق الفانتازي (مثل: أبطال الحريف)
  final String teamName;
  
  /// الميزانية المتبقية (تبدأ بـ 100 مليون مثلاً)
  final double budget;
  
  /// إجمالي النقاط التي حصدها الفريق منذ بداية الموسم
  final int totalPoints;
  
  /// نقاط الجولة الحالية فقط
  final int currentGameweekPoints;
  
  /// عدد التبديلات المجانية المتبقية هذا الأسبوع
  final int freeTransfers;
  
  /// إجمالي التبديلات التي أجراها المدرب طول الموسم
  final int totalTransfers;
  
  /// خطة اللعب (مثال: '2-1-1' في خماسي أو '4-3-3' في 11)
  final String formation;
  
  /// الخواص المفعلة حالياً (Bench Boost, Triple Captain..)
  final List<String> activeChips;
  
  /// تاريخ الإنشاء
  final DateTime createdAt;
  
  /// آخر عملية تحديث
  final DateTime updatedAt;

  const FantasyTeam({
    required this.id,
    required this.ownerPlayerId,
    required this.teamName,
    this.budget = 100.0,
    this.totalPoints = 0,
    this.currentGameweekPoints = 0,
    this.freeTransfers = 1,
    this.totalTransfers = 0,
    this.formation = '2-1-1', 
    this.activeChips = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  FantasyTeam copyWith({
    String? id,
    String? ownerPlayerId,
    String? teamName,
    double? budget,
    int? totalPoints,
    int? currentGameweekPoints,
    int? freeTransfers,
    int? totalTransfers,
    String? formation,
    List<String>? activeChips,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FantasyTeam(
      id: id ?? this.id,
      ownerPlayerId: ownerPlayerId ?? this.ownerPlayerId,
      teamName: teamName ?? this.teamName,
      budget: budget ?? this.budget,
      totalPoints: totalPoints ?? this.totalPoints,
      currentGameweekPoints: currentGameweekPoints ?? this.currentGameweekPoints,
      freeTransfers: freeTransfers ?? this.freeTransfers,
      totalTransfers: totalTransfers ?? this.totalTransfers,
      formation: formation ?? this.formation,
      activeChips: activeChips ?? this.activeChips,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
