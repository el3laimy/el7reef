enum TournamentAssistantPermissionStatus { active, revoked }

enum TournamentAssistantPermissionPreset {
  resultsAssistant,
  matchdayAssistant,
  scoreApprover,
  customLimited,
}

enum TournamentAssistantPermissionKey {
  canViewMatchday,
  canStartMatch,
  canSubmitScore,
  canRecordGoalsAndMvp,
  canApproveScore,
  canDeclareForfeit,
  canManageGuestRoster,
}

class TournamentAssistantPermission {
  final String tournamentId;
  final String userId;
  final String addedBy;
  final TournamentAssistantPermissionStatus status;
  final TournamentAssistantPermissionPreset preset;
  final Map<TournamentAssistantPermissionKey, bool> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? revokedAt;

  TournamentAssistantPermission({
    required this.tournamentId,
    required this.userId,
    required this.addedBy,
    this.status = TournamentAssistantPermissionStatus.active,
    required this.preset,
    required Map<TournamentAssistantPermissionKey, bool> permissions,
    required this.createdAt,
    required this.updatedAt,
    this.revokedAt,
  }) : permissions = Map.unmodifiable(_normalizePermissions(permissions));

  factory TournamentAssistantPermission.resultsAssistant({
    required String tournamentId,
    required String userId,
    required String addedBy,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return TournamentAssistantPermission(
      tournamentId: tournamentId,
      userId: userId,
      addedBy: addedBy,
      preset: TournamentAssistantPermissionPreset.resultsAssistant,
      permissions: _permissionsFor([
        TournamentAssistantPermissionKey.canViewMatchday,
        TournamentAssistantPermissionKey.canSubmitScore,
        TournamentAssistantPermissionKey.canRecordGoalsAndMvp,
      ]),
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  factory TournamentAssistantPermission.matchdayAssistant({
    required String tournamentId,
    required String userId,
    required String addedBy,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return TournamentAssistantPermission(
      tournamentId: tournamentId,
      userId: userId,
      addedBy: addedBy,
      preset: TournamentAssistantPermissionPreset.matchdayAssistant,
      permissions: _permissionsFor([
        TournamentAssistantPermissionKey.canViewMatchday,
        TournamentAssistantPermissionKey.canStartMatch,
        TournamentAssistantPermissionKey.canSubmitScore,
        TournamentAssistantPermissionKey.canRecordGoalsAndMvp,
        TournamentAssistantPermissionKey.canDeclareForfeit,
      ]),
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  factory TournamentAssistantPermission.scoreApprover({
    required String tournamentId,
    required String userId,
    required String addedBy,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return TournamentAssistantPermission(
      tournamentId: tournamentId,
      userId: userId,
      addedBy: addedBy,
      preset: TournamentAssistantPermissionPreset.scoreApprover,
      permissions: _permissionsFor([
        TournamentAssistantPermissionKey.canViewMatchday,
        TournamentAssistantPermissionKey.canApproveScore,
      ]),
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  factory TournamentAssistantPermission.customLimited({
    required String tournamentId,
    required String userId,
    required String addedBy,
    required Map<TournamentAssistantPermissionKey, bool> permissions,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return TournamentAssistantPermission(
      tournamentId: tournamentId,
      userId: userId,
      addedBy: addedBy,
      preset: TournamentAssistantPermissionPreset.customLimited,
      permissions: permissions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  bool get isActive => status == TournamentAssistantPermissionStatus.active;

  bool hasPermission(TournamentAssistantPermissionKey permission) {
    return isActive && (permissions[permission] ?? false);
  }

  TournamentAssistantPermission copyWith({
    TournamentAssistantPermissionStatus? status,
    TournamentAssistantPermissionPreset? preset,
    Map<TournamentAssistantPermissionKey, bool>? permissions,
    DateTime? updatedAt,
    Object? revokedAt = _unset,
  }) {
    return TournamentAssistantPermission(
      tournamentId: tournamentId,
      userId: userId,
      addedBy: addedBy,
      status: status ?? this.status,
      preset: preset ?? this.preset,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revokedAt: identical(revokedAt, _unset)
          ? this.revokedAt
          : revokedAt as DateTime?,
    );
  }

  static Map<TournamentAssistantPermissionKey, bool> _permissionsFor(
    Iterable<TournamentAssistantPermissionKey> enabled,
  ) {
    final enabledSet = enabled.toSet();
    return {
      for (final permission in TournamentAssistantPermissionKey.values)
        permission: enabledSet.contains(permission),
    };
  }

  static Map<TournamentAssistantPermissionKey, bool> _normalizePermissions(
    Map<TournamentAssistantPermissionKey, bool> permissions,
  ) {
    return {
      for (final permission in TournamentAssistantPermissionKey.values)
        permission: permissions[permission] ?? false,
    };
  }
}

const Object _unset = Object();
