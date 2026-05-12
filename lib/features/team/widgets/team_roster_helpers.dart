import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/team_member_availability.dart';
import '../../../core/enums/team_membership_role.dart';
import '../../../core/enums/team_membership_status.dart';
import '../controllers/team_roster_controller.dart';
import 'team_roster_enums.dart';

String formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month ${value.year} • $hour:$minute';
}

String roleLabel(TeamMembershipRole role) {
  return switch (role) {
    TeamMembershipRole.owner => 'مالك الفريق',
    TeamMembershipRole.viceCaptain => 'نائب قائد',
    TeamMembershipRole.player => 'لاعب',
    TeamMembershipRole.manager => 'مدير فريق',
    TeamMembershipRole.assistantManager => 'مساعد مدير',
  };
}

String availabilityLabel(TeamMemberAvailability availability) {
  return switch (availability) {
    TeamMemberAvailability.available => 'متاح',
    TeamMemberAvailability.unavailable => 'غير متاح',
    TeamMemberAvailability.injured => 'مصاب',
    TeamMemberAvailability.pending => 'قيد التحديد',
  };
}

Color availabilityColor(TeamMemberAvailability availability) {
  return switch (availability) {
    TeamMemberAvailability.available => AppColors.success,
    TeamMemberAvailability.unavailable => AppColors.textMuted,
    TeamMemberAvailability.injured => AppColors.error,
    TeamMemberAvailability.pending => AppColors.warning,
  };
}

List<PopupMenuEntry<RosterAction>> buildActionItems(
  TeamRosterMemberViewData entry,
) {
  final membership = entry.membership;
  final items = <PopupMenuEntry<RosterAction>>[];

  if (membership.status != TeamMembershipStatus.starter) {
    items.add(
      const PopupMenuItem(
        value: RosterAction.moveToStarter,
        child: Text('نقله إلى الأساسيين'),
      ),
    );
  }
  if (membership.status != TeamMembershipStatus.bench) {
    items.add(
      const PopupMenuItem(
        value: RosterAction.moveToBench,
        child: Text('نقله إلى الاحتياط'),
      ),
    );
  }
  if (membership.status != TeamMembershipStatus.inactive) {
    items.add(
      const PopupMenuItem(
        value: RosterAction.makeInactive,
        child: Text('جعله غير نشط'),
      ),
    );
  }

  if (!entry.isGuest && membership.role != TeamMembershipRole.owner) {
    if (membership.role != TeamMembershipRole.viceCaptain) {
      items.add(
        const PopupMenuItem(
          value: RosterAction.promoteViceCaptain,
          child: Text('ترقية إلى نائب قائد'),
        ),
      );
    } else {
      items.add(
        const PopupMenuItem(
          value: RosterAction.demoteToPlayer,
          child: Text('إلغاء منصب نائب القائد'),
        ),
      );
    }
  }

  if (membership.availability != TeamMemberAvailability.available) {
    items.add(
      const PopupMenuItem(
        value: RosterAction.markAvailable,
        child: Text('متاح'),
      ),
    );
  }
  if (membership.availability != TeamMemberAvailability.unavailable) {
    items.add(
      const PopupMenuItem(
        value: RosterAction.markUnavailable,
        child: Text('غير متاح'),
      ),
    );
  }
  if (membership.availability != TeamMemberAvailability.injured) {
    items.add(
      const PopupMenuItem(
        value: RosterAction.markInjured,
        child: Text('مصاب'),
      ),
    );
  }

  if (membership.role != TeamMembershipRole.owner) {
    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem(
        value: RosterAction.remove,
        child: Text('إزالة من القائمة'),
      ),
    );
  }

  if (entry.isGuest && !entry.isGuestClaimedOrLinked) {
    items.add(const PopupMenuDivider());
    items.add(
      const PopupMenuItem(
        value: RosterAction.shareGuestClaim,
        child: Text('مشاركة رابط الاستلام'),
      ),
    );
  }

  return items;
}
