import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../app/theme/app_media_colors.dart';
import '../../../core/lineup/formation_engine.dart';
import '../../../core/lineup/formation_library.dart';
import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';
import '../../../data/repositories/match_lineup_snapshot_repository_impl.dart';
import '../../../data/repositories/match_side_repository_impl.dart';
import '../../../data/repositories/team_repository_impl.dart';
import '../../../domain/entities/match_lineup_entry.dart';
import '../../../domain/entities/match_lineup_snapshot.dart';
import '../../lineup/widgets/lineup_player_display.dart';
import '../models/lineup_share_data.dart';
import '../services/pride_share_payload_builder.dart';

class LineupShareController {
  final MatchLineupSnapshotRepositoryImpl snapshotRepository;
  final TeamRepositoryImpl teamRepository;
  final MatchSideRepositoryImpl matchSideRepository;

  const LineupShareController({
    required this.snapshotRepository,
    required this.teamRepository,
    required this.matchSideRepository,
  });

  static const _payloadBuilder = PrideSharePayloadBuilder();

  Future<LineupShareData> buildOfficialTeamLineup({
    required String matchId,
    required String teamId,
    String? matchLabel,
  }) async {
    final snapshot = await snapshotRepository.getSnapshotByTeamId(
      matchId: matchId,
      teamId: teamId,
    );
    if (snapshot == null) {
      throw Exception('احفظ التشكيلة أولًا قبل مشاركتها.');
    }
    final team = await teamRepository.getTeam(teamId);
    return buildFromSnapshot(
      snapshot: snapshot,
      teamName: team?.name ?? 'الفريق',
      logoUrl: team?.logoUrl,
      lineupOwnerType: LineupShareOwnerType.officialTeam,
      lineupTypeLabel: 'فريق رسمي',
      matchLabel: matchLabel,
      accentColor: AppMediaColors.actionPrimary,
    );
  }

  Future<LineupShareData> buildTemporarySideLineup({
    required String matchId,
    required String sideKey,
    String? matchLabel,
  }) async {
    final side = await matchSideRepository.getSide(
      matchId: matchId,
      sideKey: sideKey,
    );
    if (side == null) {
      throw Exception('تعذر تحميل طرف المباراة.');
    }
    final snapshot = await snapshotRepository.getSnapshotByMatchSideId(
      matchId: matchId,
      matchSideId: side.id,
    );
    if (snapshot == null) {
      throw Exception('احفظ التشكيلة أولًا قبل مشاركتها.');
    }
    return buildFromSnapshot(
      snapshot: snapshot,
      teamName: side.displayName,
      lineupOwnerType: LineupShareOwnerType.temporarySide,
      lineupTypeLabel: 'فريق مؤقت',
      matchLabel: matchLabel ?? 'مباراة ودية',
      accentColor: AppMediaColors.actionLight,
    );
  }

  LineupShareData buildFromSnapshot({
    required MatchLineupSnapshot snapshot,
    required String teamName,
    String? teamLabel,
    String? logoUrl,
    LineupShareOwnerType? lineupOwnerType,
    String? lineupTypeLabel,
    String? matchLabel,
    Color accentColor = AppMediaColors.actionPrimary,
  }) {
    final ownerType = lineupOwnerType ?? _ownerTypeForSnapshot(snapshot);
    final resolvedName = _normalizeName(teamName);
    final formationCode = _formationCode(snapshot);
    final teamSize = normalizeMatchTeamSize(
      snapshot.playerCount ?? snapshot.starters.length,
    );
    final pitchPlayers = _pitchPlayers(snapshot, teamSize, formationCode);
    return LineupShareData(
      matchId: snapshot.matchId,
      lineupOwnerType: ownerType,
      ownerId: snapshot.participantId,
      sideKey: snapshot.sideKey,
      teamName: resolvedName,
      teamLabel: _normalizeOptional(teamLabel),
      logoUrl: _normalizeOptional(logoUrl),
      initials: lineupInitialsFromName(resolvedName),
      accentColor: accentColor,
      formationCode: formationCode,
      formationLabel: _normalizeOptional(snapshot.formationLabel),
      teamSize: teamSize,
      lineupTypeLabel: lineupTypeLabel ?? _lineupTypeLabel(ownerType),
      matchLabel: _normalizeOptional(matchLabel),
      pitchPlayers: pitchPlayers,
      benchPlayers: snapshot.bench.map(_benchPlayer).toList(growable: false),
      statusLabel: 'التشكيلة المعتمدة',
      updatedLabel: intl.DateFormat('yyyy/MM/dd').format(snapshot.lockedAt),
      sharePayload: _payloadBuilder.lineup(
        matchId: snapshot.matchId,
        lineupId: snapshot.id,
      ),
    );
  }

  List<LineupSharePlayerData> _pitchPlayers(
    MatchLineupSnapshot snapshot,
    int teamSize,
    String formationCode,
  ) {
    if (_hasCompleteSavedAssignments(snapshot)) {
      return snapshot.starters
          .map(_pitchPlayerFromEntry)
          .toList(growable: false);
    }

    final generated = FormationEngine.generateFormationSlots(
      playerCount: teamSize,
      formationCode: formationCode,
    );
    final lineupPlayers = snapshot.starters
        .map(_lineupPlayerFromEntry)
        .toList(growable: false);
    final assigned = LineupUtils.assignPlayersToGeneratedSlots(
      slots: generated,
      starters: lineupPlayers,
    );
    final entriesByKey = {
      for (final entry in snapshot.starters)
        _lineupPlayerFromEntry(entry).key: entry,
    };
    return assigned.slots
        .where((slot) => slot.occupantKey != null)
        .map((slot) {
          final entry = entriesByKey[slot.occupantKey]!;
          return _pitchPlayerFromEntry(entry, fallbackSlot: slot);
        })
        .toList(growable: false);
  }

  LineupSharePlayerData _pitchPlayerFromEntry(
    MatchLineupEntry entry, {
    FormationSlot? fallbackSlot,
  }) {
    final role =
        _parseRole(entry.slotRole) ?? fallbackSlot?.role ?? SlotRole.mid;
    final displayName = lineupDisplayNameFromName(entry.displayName);
    return LineupSharePlayerData(
      id: entry.participantId,
      displayName: displayName,
      initials: lineupInitialsFromName(displayName),
      slotId: entry.slotId ?? fallbackSlot?.id ?? entry.participantId,
      slotRole: role,
      slotX: entry.slotX ?? fallbackSlot?.x ?? 50,
      slotY: entry.slotY ?? fallbackSlot?.y ?? 50,
      isTemporary: entry.matchSidePlayerId != null,
      shirtNumber: entry.shirtNumber,
      positionLabel: _positionLabelForRole(
        role,
        entry.slotX ?? fallbackSlot?.x ?? 50,
      ),
      shortName: _shortDisplayName(entry.displayName),
    );
  }

  LineupShareBenchPlayerData _benchPlayer(MatchLineupEntry entry) {
    final displayName = lineupDisplayNameFromName(entry.displayName);
    return LineupShareBenchPlayerData(
      id: entry.participantId,
      displayName: displayName,
      initials: lineupInitialsFromName(displayName),
      shirtNumber: entry.shirtNumber,
      isTemporary: entry.matchSidePlayerId != null,
    );
  }

  LineupPlayer _lineupPlayerFromEntry(MatchLineupEntry entry) {
    return LineupPlayer(
      id: entry.teamMembershipId ?? entry.participantId,
      name: entry.displayName,
      preferredPosition: entry.position,
      isRegistered: entry.playerId != null,
      isTemporary: entry.matchSidePlayerId != null,
    );
  }

  bool _hasCompleteSavedAssignments(MatchLineupSnapshot snapshot) {
    if (snapshot.starters.isEmpty) return false;
    return snapshot.starters.every((entry) {
      return entry.slotId?.trim().isNotEmpty == true &&
          _parseRole(entry.slotRole) != null &&
          entry.lineIndex != null &&
          entry.slotIndex != null &&
          entry.slotX != null &&
          entry.slotY != null;
    });
  }

  SlotRole? _parseRole(String? raw) {
    if (raw == null) return null;
    for (final role in SlotRole.values) {
      if (role.name == raw) return role;
    }
    return null;
  }

  String _formationCode(MatchLineupSnapshot snapshot) {
    final count = normalizeMatchTeamSize(
      snapshot.playerCount ?? snapshot.starters.length,
    );
    final raw = snapshot.formationCode ?? snapshot.formationLabel ?? '';
    return isValidFormationForPlayerCount(count, raw)
        ? raw
        : getDefaultFormation(count);
  }

  LineupShareOwnerType _ownerTypeForSnapshot(MatchLineupSnapshot snapshot) {
    if (snapshot.teamId != null) return LineupShareOwnerType.officialTeam;
    if (snapshot.matchSideId != null) return LineupShareOwnerType.temporarySide;
    return LineupShareOwnerType.guestTeam;
  }

  String _lineupTypeLabel(LineupShareOwnerType type) {
    return switch (type) {
      LineupShareOwnerType.officialTeam => 'فريق رسمي',
      LineupShareOwnerType.temporarySide => 'فريق مؤقت',
      LineupShareOwnerType.guestTeam => 'فريق ضيف',
    };
  }

  String _normalizeName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'الفريق' : trimmed;
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _positionLabelForRole(SlotRole role, double slotX) {
    // slotX: 0=left of pitch, 100=right. In RTL context:
    // slotX < 35 = right side, slotX > 65 = left side, middle = center.
    final isRight = slotX < 35;
    final isLeft = slotX > 65;

    return switch (role) {
      SlotRole.gk => 'حارس مرمى',
      SlotRole.def =>
        isRight
            ? 'ظهير أيمن'
            : isLeft
            ? 'ظهير أيسر'
            : 'قلب دفاع',
      SlotRole.mid =>
        isRight
            ? 'جناح أيمن'
            : isLeft
            ? 'جناح أيسر'
            : 'نص ملعب',
      SlotRole.att =>
        isRight
            ? 'جناح أيمن'
            : isLeft
            ? 'جناح أيسر'
            : 'مهاجم صريح',
    };
  }

  String _shortDisplayName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last}';
  }
}
