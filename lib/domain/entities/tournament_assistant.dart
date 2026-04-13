import '../../core/enums/tournament_enums.dart';

/// كيان دور مساعد الدورة
class TournamentAssistant {
  final String userId;
  final TournamentAssistantRole role;
  
  /// وقت تعيين المساعد
  final DateTime assignedAt;
  
  /// وقت انتهاء الصلاحية للبديل الطارئ (Emergency Backup) إن وجد
  final DateTime? expiresAt;

  const TournamentAssistant({
    required this.userId,
    required this.role,
    required this.assignedAt,
    this.expiresAt,
  });

  /// للتحقق من أن المساعد البديل الطارئ لا تزال صلاحيته سارية المفعول
  bool get isValidEmergency {
    if (role != TournamentAssistantRole.emergency) return true;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  TournamentAssistant copyWith({
    String? userId,
    TournamentAssistantRole? role,
    DateTime? assignedAt,
    DateTime? expiresAt,
  }) {
    return TournamentAssistant(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      assignedAt: assignedAt ?? this.assignedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role.name,
      'assignedAt': assignedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
    };
  }

  factory TournamentAssistant.fromJson(Map<String, dynamic> json) {
    return TournamentAssistant(
      userId: json['userId'] as String? ?? '',
      role: TournamentAssistantRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => TournamentAssistantRole.observer,
      ),
      assignedAt: json['assignedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['assignedAt'] as num).toInt())
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['expiresAt'] as num).toInt())
          : null,
    );
  }
}
