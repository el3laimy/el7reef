import 'package:flutter/material.dart';

class TournamentMetricChip extends StatelessWidget {
  final String label;
  final String value;

  const TournamentMetricChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
