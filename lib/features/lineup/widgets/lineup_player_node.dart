import 'package:flutter/material.dart';

import '../../../core/lineup/lineup_types.dart';
import 'lineup_player_display.dart';
import 'squad_player_card.dart';

class LineupPlayerNode extends StatelessWidget {
  final LineupPlayer? player;
  final SlotRole role;
  final bool isSelected;
  final bool isUnavailable;
  final bool compact;
  final bool dense;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const LineupPlayerNode({
    super.key,
    required this.player,
    required this.role,
    this.isSelected = false,
    this.isUnavailable = false,
    this.compact = false,
    this.dense = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = _semanticsLabel();
    final semanticsHint = player == null
        ? 'اضغط لاختيار لاعب لهذه الخانة'
        : isSelected
        ? 'اللاعب مختار، اختر خانة للنقل أو لاعبًا للتبديل'
        : 'اضغط للاختيار، أو اضغط مطولًا لإجراءات اللاعب';

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: onTap != null,
      selected: isSelected,
      label: semanticsLabel,
      hint: onTap == null ? null : semanticsHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SquadPlayerCard(
          player: player,
          role: role,
          canvas: SquadPlayerCardCanvas.pitch,
          size: dense
              ? SquadPlayerCardSize.dense
              : compact
              ? SquadPlayerCardSize.compact
              : SquadPlayerCardSize.field,
          isSelected: isSelected,
          isUnavailable: isUnavailable,
        ),
      ),
    );
  }

  String _semanticsLabel() {
    final currentPlayer = player;
    if (currentPlayer == null) {
      return 'خانة ${role.arabicLabel} فارغة';
    }
    final parts = <String>[
      lineupDisplayName(currentPlayer),
      if (currentPlayer.number != null) 'رقم ${currentPlayer.number}',
      role.arabicLabel,
      if (currentPlayer.isTemporary)
        'لاعب مؤقت'
      else if (currentPlayer.isGuest)
        'لاعب زائر'
      else
        'لاعب مسجل',
      if (currentPlayer.isCaptain) 'قائد الفريق',
    ];
    return parts.join('، ');
  }
}
