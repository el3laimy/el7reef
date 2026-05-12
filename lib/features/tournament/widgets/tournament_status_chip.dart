import 'package:flutter/material.dart';

class TournamentStatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;

  const TournamentStatusChip({super.key, required this.label, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
