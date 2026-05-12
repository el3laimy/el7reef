import '../../domain/entities/tournament_assistant_permission.dart';

class TournamentAssistantPermissionModel {
  final String tournamentId;
  final String userId;
  final String addedBy;
  final String status;
  final String preset;
  final Map<String, bool> permissions;
  final int createdAt;
  final int updatedAt;
  final int? revokedAt;

  const TournamentAssistantPermissionModel({
    required this.tournamentId,
    required this.userId,
    required this.addedBy,
    required this.status,
    required this.preset,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.revokedAt,
  });

  factory TournamentAssistantPermissionModel.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return TournamentAssistantPermissionModel(
      tournamentId: json['tournamentId'] as String? ?? '',
      userId: json['userId'] as String? ?? docId,
      addedBy: json['addedBy'] as String? ?? '',
      status:
          json['status'] as String? ??
          TournamentAssistantPermissionStatus.active.name,
      preset:
          json['preset'] as String? ??
          TournamentAssistantPermissionPreset.customLimited.name,
      permissions: _parsePermissions(json['permissions']),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? now,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? now,
      revokedAt: (json['revokedAt'] as num?)?.toInt(),
    );
  }

  factory TournamentAssistantPermissionModel.fromEntity(
    TournamentAssistantPermission entity,
  ) {
    return TournamentAssistantPermissionModel(
      tournamentId: entity.tournamentId,
      userId: entity.userId,
      addedBy: entity.addedBy,
      status: entity.status.name,
      preset: entity.preset.name,
      permissions: permissionsToJson(entity.permissions),
      createdAt: entity.createdAt.millisecondsSinceEpoch,
      updatedAt: entity.updatedAt.millisecondsSinceEpoch,
      revokedAt: entity.revokedAt?.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'userId': userId,
      'addedBy': addedBy,
      'status': status,
      'preset': preset,
      'permissions': permissions,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'revokedAt': revokedAt,
    };
  }

  TournamentAssistantPermission toEntity() {
    return TournamentAssistantPermission(
      tournamentId: tournamentId,
      userId: userId,
      addedBy: addedBy,
      status: _parseStatus(status),
      preset: _parsePreset(preset),
      permissions: permissionsFromJson(permissions),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      revokedAt: revokedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(revokedAt!),
    );
  }

  static Map<String, bool> permissionsToJson(
    Map<TournamentAssistantPermissionKey, bool> permissions,
  ) {
    return {
      for (final permission in TournamentAssistantPermissionKey.values)
        permission.name: permissions[permission] ?? false,
    };
  }

  static Map<TournamentAssistantPermissionKey, bool> permissionsFromJson(
    Object? rawPermissions,
  ) {
    final rawMap = rawPermissions is Map ? rawPermissions : const {};
    return {
      for (final permission in TournamentAssistantPermissionKey.values)
        permission: rawMap[permission.name] is bool
            ? rawMap[permission.name] as bool
            : false,
    };
  }

  static Map<String, bool> _parsePermissions(Object? rawPermissions) {
    final parsed = permissionsFromJson(rawPermissions);
    return permissionsToJson(parsed);
  }

  static TournamentAssistantPermissionStatus _parseStatus(String status) {
    return TournamentAssistantPermissionStatus.values.firstWhere(
      (entry) => entry.name == status,
      orElse: () => TournamentAssistantPermissionStatus.active,
    );
  }

  static TournamentAssistantPermissionPreset _parsePreset(String preset) {
    return TournamentAssistantPermissionPreset.values.firstWhere(
      (entry) => entry.name == preset,
      orElse: () => TournamentAssistantPermissionPreset.customLimited,
    );
  }
}
