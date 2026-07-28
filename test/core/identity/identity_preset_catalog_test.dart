import 'package:el7reef/app/theme/app_media_colors.dart';
import 'package:el7reef/core/identity/identity_preset.dart';
import 'package:el7reef/core/identity/identity_preset_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdentityPresetCatalog', () {
    test('ships the bounded launch catalog', () {
      expect(IdentityPresetCatalog.teamBadges, hasLength(12));
      expect(IdentityPresetCatalog.teamPennants, hasLength(6));
      expect(IdentityPresetCatalog.tournamentEmblems, hasLength(6));
      expect(IdentityPresetCatalog.all, hasLength(24));
    });

    test('uses unique, versioned references that round trip', () {
      final references = IdentityPresetCatalog.all
          .map((preset) => preset.value)
          .toList(growable: false);

      expect(references.toSet(), hasLength(references.length));
      for (final preset in IdentityPresetCatalog.all) {
        final parsed = IdentityPresetReference.tryParse(preset.value);
        expect(parsed, preset.reference, reason: preset.value);
        expect(IdentityPresetCatalog.findByReference(preset.value), preset);
      }
    });

    test('does not use earned-pride colors or forbidden symbols', () {
      const forbiddenWords = <String>['gold', 'star', 'crown'];

      for (final preset in IdentityPresetCatalog.all) {
        expect(preset.primaryColor, isNot(AppMediaColors.achievement));
        expect(preset.secondaryColor, isNot(AppMediaColors.achievement));
        for (final word in forbiddenWords) {
          expect(preset.reference.id, isNot(contains(word)));
          expect(preset.nameAr.toLowerCase(), isNot(contains(word)));
        }
      }
    });

    test('scopes team and tournament choices independently', () {
      expect(
        IdentityPresetCatalog.forScope(IdentityPresetScope.team),
        hasLength(18),
      );
      expect(
        IdentityPresetCatalog.forScope(IdentityPresetScope.tournament),
        hasLength(6),
      );
      expect(
        IdentityPresetCatalog.forScope(IdentityPresetScope.tournament).every(
          (preset) => preset.family == IdentityPresetFamily.tournamentEmblem,
        ),
        isTrue,
      );
    });
  });

  group('IdentityPresetReference.tryParse', () {
    test('rejects malformed or unsupported references', () {
      const invalid = <String?>[
        null,
        '',
        'https://v1/team_badge/street_bolt',
        'preset://v2/team_badge/street_bolt',
        'preset://v1/unknown/street_bolt',
        'preset://v1/team_badge/StreetBolt',
        'preset://v1/team_badge/street-bolt',
        'preset://v1/team_badge/street_bolt?color=red',
        'preset://v1/team_badge/street_bolt/extra',
        'preset://V1/team_badge/street_bolt',
        'preset://v1/team_badge/street_bolt/',
      ];

      for (final value in invalid) {
        expect(
          IdentityPresetReference.tryParse(value),
          isNull,
          reason: '$value',
        );
      }
    });

    test('parses an unknown but structurally valid future catalog item', () {
      const value = 'preset://v1/team_badge/future_mark';
      final parsed = IdentityPresetReference.tryParse(value);

      expect(parsed?.family, IdentityPresetFamily.teamBadge);
      expect(parsed?.id, 'future_mark');
      expect(IdentityPresetCatalog.findByReference(value), isNull);
    });
  });
}
