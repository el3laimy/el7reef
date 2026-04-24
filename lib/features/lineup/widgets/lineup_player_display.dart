import 'package:flutter/material.dart';

import '../../../core/lineup/lineup_types.dart';
import '../../../core/lineup/lineup_utils.dart';

const Color lineupGoalkeeperColor = Color(0xFFF59E0B);
const Color lineupDefenderColor = Color(0xFF2563EB);
const Color lineupMidfielderColor = Color(0xFF22C55E);
const Color lineupAttackerColor = Color(0xFFEF4444);

Color lineupRoleColor(SlotRole role) {
  return switch (role) {
    SlotRole.gk => lineupGoalkeeperColor,
    SlotRole.def => lineupDefenderColor,
    SlotRole.mid => lineupMidfielderColor,
    SlotRole.att => lineupAttackerColor,
  };
}

Color lineupPlayerRoleColor(LineupPlayer player, {Color? fallback}) {
  final role = LineupUtils.preferredRoleForPosition(player.preferredPosition);
  return role == null
      ? fallback ?? lineupMidfielderColor
      : lineupRoleColor(role);
}

String lineupDisplayName(LineupPlayer player) {
  final username = _normalizeAlias(player.username);
  if (username.isNotEmpty) {
    return username;
  }
  return lineupDisplayNameFromName(player.name);
}

String lineupDisplayNameFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'لاعب';
  }
  if (parts.length == 1) {
    return parts.first;
  }
  return '${parts[0]} ${parts[1]}';
}

String lineupInitialsForPlayer(LineupPlayer player) {
  return lineupInitialsFromName(lineupDisplayName(player));
}

String lineupInitialsFromName(String name) {
  final displayName = lineupDisplayNameFromName(name);
  final parts = displayName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    final value = parts.first;
    if (RegExp(r'^[A-Za-z0-9_]+$').hasMatch(value)) {
      return value.characters.take(2).toString().toUpperCase();
    }
    return value.characters.first.toUpperCase();
  }
  return '${parts[0].characters.first} ${parts[1].characters.first}'
      .toUpperCase();
}

String _normalizeAlias(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.startsWith('@') ? trimmed.substring(1).trim() : trimmed;
}
