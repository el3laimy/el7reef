import 'package:flutter/services.dart';

class LineupHaptics {
  const LineupHaptics._();

  static void select() {
    HapticFeedback.selectionClick().catchError((_) {});
  }

  static void move() {
    HapticFeedback.lightImpact().catchError((_) {});
  }

  static void commit() {
    HapticFeedback.mediumImpact().catchError((_) {});
  }
}
