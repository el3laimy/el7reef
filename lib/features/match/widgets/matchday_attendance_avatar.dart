import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/match_attendance_status.dart';

class MatchdayAttendanceAvatar extends StatelessWidget {
  final String name;
  final MatchAttendanceStatus status;

  const MatchdayAttendanceAvatar({super.key, required this.name, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = attendanceStatusColor(status);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

Color attendanceStatusColor(MatchAttendanceStatus status) {
  return switch (status) {
    MatchAttendanceStatus.present => AppColors.success,
    MatchAttendanceStatus.late => AppColors.warning,
    MatchAttendanceStatus.absent => AppColors.error,
    MatchAttendanceStatus.excused => AppColors.info,
    MatchAttendanceStatus.pending => AppColors.textMuted,
  };
}
