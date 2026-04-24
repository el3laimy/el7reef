import 'dart:math' as math;

import 'lineup_types.dart';

class LineupPreservationResult {
  final List<FormationSlot> slots;
  final List<String> movedToBenchKeys;

  const LineupPreservationResult({
    required this.slots,
    this.movedToBenchKeys = const [],
  });
}

class LineupUtils {
  const LineupUtils._();

  static LineupPreservationResult preserveAssignments({
    required List<FormationSlot> oldSlots,
    required List<FormationSlot> newSlots,
    required Map<String, LineupPlayer> playersByKey,
  }) {
    final occupiedOldSlots = oldSlots
        .where((slot) => slot.occupantKey != null)
        .where((slot) => playersByKey.containsKey(slot.occupantKey))
        .toList(growable: false);
    final updatedSlots = newSlots.map((slot) => slot.clearPlayer()).toList();
    final assignedNewSlotIds = <String>{};
    final movedToBench = <String>[];

    final orderedOldSlots = List<FormationSlot>.from(occupiedOldSlots)
      ..sort((left, right) {
        final leftRole = _roleOrder(left.role);
        final rightRole = _roleOrder(right.role);
        if (leftRole != rightRole) {
          return leftRole.compareTo(rightRole);
        }
        return left.slotIndex.compareTo(right.slotIndex);
      });

    for (final oldSlot in orderedOldSlots) {
      final key = oldSlot.occupantKey;
      final player = key == null ? null : playersByKey[key];
      if (player == null) {
        continue;
      }

      final targetIndex = _bestTargetSlotIndex(
        player: player,
        oldSlot: oldSlot,
        newSlots: updatedSlots,
        assignedSlotIds: assignedNewSlotIds,
      );

      if (targetIndex == null) {
        movedToBench.add(player.key);
        continue;
      }

      assignedNewSlotIds.add(updatedSlots[targetIndex].id);
      updatedSlots[targetIndex] = updatedSlots[targetIndex].assignPlayer(
        player,
      );
    }

    return LineupPreservationResult(
      slots: updatedSlots,
      movedToBenchKeys: movedToBench,
    );
  }

  static LineupPreservationResult assignPlayersToGeneratedSlots({
    required List<FormationSlot> slots,
    required List<LineupPlayer> starters,
  }) {
    final emptySlots = slots.map((slot) => slot.clearPlayer()).toList();
    final assignedSlotIds = <String>{};
    final movedToBench = <String>[];

    final orderedPlayers = List<LineupPlayer>.from(starters)
      ..sort((left, right) {
        final leftRole = preferredRoleForPosition(left.preferredPosition);
        final rightRole = preferredRoleForPosition(right.preferredPosition);
        final leftOrder = leftRole == null ? 99 : _roleOrder(leftRole);
        final rightOrder = rightRole == null ? 99 : _roleOrder(rightRole);
        if (leftOrder != rightOrder) {
          return leftOrder.compareTo(rightOrder);
        }
        return left.name.compareTo(right.name);
      });

    for (final player in orderedPlayers) {
      final targetIndex = _bestTargetSlotIndex(
        player: player,
        oldSlot: null,
        newSlots: emptySlots,
        assignedSlotIds: assignedSlotIds,
      );
      if (targetIndex == null) {
        movedToBench.add(player.key);
        continue;
      }
      assignedSlotIds.add(emptySlots[targetIndex].id);
      emptySlots[targetIndex] = emptySlots[targetIndex].assignPlayer(player);
    }

    return LineupPreservationResult(
      slots: emptySlots,
      movedToBenchKeys: movedToBench,
    );
  }

  static SlotRole? preferredRoleForPosition(String? rawPosition) {
    for (final role in SlotRole.values) {
      if (role.matchesPosition(rawPosition)) {
        return role;
      }
    }
    return null;
  }

  static List<LineupPlayer> playersForSlots({
    required List<FormationSlot> slots,
    required Map<String, LineupPlayer> playersByKey,
  }) {
    return slots
        .map((slot) => slot.occupantKey)
        .whereType<String>()
        .map((key) => playersByKey[key])
        .whereType<LineupPlayer>()
        .toList(growable: false);
  }

  static List<FormationSlot> assignPlayerToSlot({
    required List<FormationSlot> slots,
    required LineupPlayer player,
    required String slotId,
  }) {
    return slots
        .map((slot) {
          if (slot.id == slotId) {
            return slot.assignPlayer(player);
          }
          if (slot.occupantKey == player.key) {
            return slot.clearPlayer();
          }
          return slot;
        })
        .toList(growable: false);
  }

  static List<FormationSlot> removePlayerFromSlots({
    required List<FormationSlot> slots,
    required LineupPlayer player,
  }) {
    return slots
        .map(
          (slot) => slot.occupantKey == player.key ? slot.clearPlayer() : slot,
        )
        .toList(growable: false);
  }

  static int _roleOrder(SlotRole role) {
    return switch (role) {
      SlotRole.gk => 0,
      SlotRole.def => 1,
      SlotRole.mid => 2,
      SlotRole.att => 3,
    };
  }

  static int? _bestTargetSlotIndex({
    required LineupPlayer player,
    required FormationSlot? oldSlot,
    required List<FormationSlot> newSlots,
    required Set<String> assignedSlotIds,
  }) {
    final preferredRole = preferredRoleForPosition(player.preferredPosition);
    final targetRole = preferredRole ?? oldSlot?.role;
    var bestIndex = -1;
    var bestScore = double.infinity;

    for (var index = 0; index < newSlots.length; index += 1) {
      final candidate = newSlots[index];
      if (assignedSlotIds.contains(candidate.id) || !candidate.isEmpty) {
        continue;
      }

      var score = 0.0;
      if (targetRole != null && candidate.role != targetRole) {
        score += 1000;
      }
      if (oldSlot != null) {
        score += (candidate.y - oldSlot.y).abs() * 3;
        score += (candidate.x - oldSlot.x).abs();
      } else if (preferredRole != null && candidate.role == preferredRole) {
        score -= 100;
      }
      if (candidate.role == SlotRole.gk && preferredRole != SlotRole.gk) {
        score += 600;
      }
      if (candidate.role != SlotRole.gk && preferredRole == SlotRole.gk) {
        score += 600;
      }
      score += math.max(0, candidate.slotIndex - 2) * 0.1;

      if (score < bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }

    return bestIndex == -1 ? null : bestIndex;
  }
}
