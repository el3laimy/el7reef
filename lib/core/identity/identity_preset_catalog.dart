import 'package:flutter/material.dart';

import '../../app/theme/app_media_colors.dart';
import 'identity_preset.dart';

/// Launch catalog for built-in team and tournament identities.
///
/// References are persisted, so IDs are intentionally stable and versioned.
abstract final class IdentityPresetCatalog {
  static const Color _violet = Color(0xFF9C7BFF);
  static const Color _cyan = Color(0xFF3DD5D0);
  static const Color _pink = Color(0xFFEC6FA8);
  static const Color _tangerine = Color(0xFFEF7A3A);
  static const Color _indigo = Color(0xFF6675E8);
  static const Color _aqua = Color(0xFF48C7A0);
  static const Color _blue = Color(0xFF3D86E6);
  static const Color _red = Color(0xFFE75D62);

  static const List<IdentityPreset> teamBadges = <IdentityPreset>[
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'street_bolt',
      ),
      nameAr: 'برق الشارع',
      motif: IdentityPresetMotif.bolt,
      primaryColor: AppMediaColors.actionStrong,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'falcon_wing',
      ),
      nameAr: 'جناح الصقر',
      motif: IdentityPresetMotif.wing,
      primaryColor: AppMediaColors.socialAccent,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'fortress_gate',
      ),
      nameAr: 'بوابة الحصن',
      motif: IdentityPresetMotif.gate,
      primaryColor: _violet,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'street_flame',
      ),
      nameAr: 'لهب الحارة',
      motif: IdentityPresetMotif.flame,
      primaryColor: _tangerine,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'city_bridge',
      ),
      nameAr: 'كوبري المدينة',
      motif: IdentityPresetMotif.bridge,
      primaryColor: AppMediaColors.info,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'shield_stripes',
      ),
      nameAr: 'خطوط الملعب',
      motif: IdentityPresetMotif.stripes,
      primaryColor: _indigo,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'night_panther',
      ),
      nameAr: 'فهد الليل',
      motif: IdentityPresetMotif.panther,
      primaryColor: _pink,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'goal_net',
      ),
      nameAr: 'شباك الهدف',
      motif: IdentityPresetMotif.goalNet,
      primaryColor: _cyan,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'sunrise_pitch',
      ),
      nameAr: 'شروق الملعب',
      motif: IdentityPresetMotif.sunrise,
      primaryColor: AppMediaColors.socialLight,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'crossed_lines',
      ),
      nameAr: 'تقاطع الخطوط',
      motif: IdentityPresetMotif.crossedLines,
      primaryColor: _aqua,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'twin_floodlights',
      ),
      nameAr: 'كشافين',
      motif: IdentityPresetMotif.floodlights,
      primaryColor: _blue,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamBadge,
        id: 'city_blocks',
      ),
      nameAr: 'بلوك الحارة',
      motif: IdentityPresetMotif.cityBlocks,
      primaryColor: _red,
      secondaryColor: AppMediaColors.textPrimary,
    ),
  ];

  static const List<IdentityPreset> teamPennants = <IdentityPreset>[
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamPennant,
        id: 'diagonal_dash',
      ),
      nameAr: 'قطر سريع',
      motif: IdentityPresetMotif.diagonal,
      primaryColor: AppMediaColors.actionStrong,
      secondaryColor: AppMediaColors.socialAccent,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamPennant,
        id: 'sharp_chevron',
      ),
      nameAr: 'سهم حاد',
      motif: IdentityPresetMotif.chevron,
      primaryColor: _violet,
      secondaryColor: _cyan,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamPennant,
        id: 'split_lanes',
      ),
      nameAr: 'نصفين',
      motif: IdentityPresetMotif.split,
      primaryColor: AppMediaColors.socialAccent,
      secondaryColor: _indigo,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamPennant,
        id: 'horizon_wave',
      ),
      nameAr: 'خط الأفق',
      motif: IdentityPresetMotif.horizon,
      primaryColor: AppMediaColors.info,
      secondaryColor: _pink,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamPennant,
        id: 'fast_sash',
      ),
      nameAr: 'وشاح سريع',
      motif: IdentityPresetMotif.sash,
      primaryColor: _tangerine,
      secondaryColor: _aqua,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.teamPennant,
        id: 'goal_channels',
      ),
      nameAr: 'ممرات الجون',
      motif: IdentityPresetMotif.channels,
      primaryColor: _blue,
      secondaryColor: AppMediaColors.tactical,
    ),
  ];

  static const List<IdentityPreset> tournamentEmblems = <IdentityPreset>[
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.tournamentEmblem,
        id: 'floodlights',
      ),
      nameAr: 'كشافات الملعب',
      motif: IdentityPresetMotif.floodlights,
      primaryColor: AppMediaColors.actionStrong,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.tournamentEmblem,
        id: 'center_circle',
      ),
      nameAr: 'دائرة البداية',
      motif: IdentityPresetMotif.centerCircle,
      primaryColor: _cyan,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.tournamentEmblem,
        id: 'street_gate',
      ),
      nameAr: 'بوابة الحارة',
      motif: IdentityPresetMotif.gate,
      primaryColor: _violet,
      secondaryColor: AppMediaColors.textPrimary,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.tournamentEmblem,
        id: 'whistle',
      ),
      nameAr: 'صافرة البداية',
      motif: IdentityPresetMotif.whistle,
      primaryColor: AppMediaColors.socialAccent,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.tournamentEmblem,
        id: 'match_ball',
      ),
      nameAr: 'كرة المباراة',
      motif: IdentityPresetMotif.matchBall,
      primaryColor: AppMediaColors.info,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
    IdentityPreset(
      reference: IdentityPresetReference(
        family: IdentityPresetFamily.tournamentEmblem,
        id: 'tournament_flame',
      ),
      nameAr: 'شعلة البطولة',
      motif: IdentityPresetMotif.flame,
      primaryColor: _tangerine,
      secondaryColor: AppMediaColors.canvasDeep,
    ),
  ];

  static const List<IdentityPreset> all = <IdentityPreset>[
    ...teamBadges,
    ...teamPennants,
    ...tournamentEmblems,
  ];

  static List<IdentityPreset> forScope(IdentityPresetScope scope) {
    return switch (scope) {
      IdentityPresetScope.team => <IdentityPreset>[
        ...teamBadges,
        ...teamPennants,
      ],
      IdentityPresetScope.tournament => tournamentEmblems,
    };
  }

  static IdentityPreset? findByReference(String? value) {
    final reference = IdentityPresetReference.tryParse(value);
    if (reference == null) return null;

    for (final preset in all) {
      if (preset.reference == reference) return preset;
    }
    return null;
  }

  static bool containsReference(String? value) =>
      findByReference(value) != null;
}
