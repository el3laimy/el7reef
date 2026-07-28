import 'package:flutter/material.dart';

/// Stable families used in persisted identity preset references.
enum IdentityPresetFamily {
  teamBadge('team_badge'),
  teamPennant('team_pennant'),
  tournamentEmblem('tournament_emblem');

  const IdentityPresetFamily(this.pathSegment);

  final String pathSegment;

  static IdentityPresetFamily? fromPathSegment(String value) {
    for (final family in values) {
      if (family.pathSegment == value) return family;
    }
    return null;
  }
}

/// The surfaces that can open the preset picker.
enum IdentityPresetScope { team, tournament }

/// A small visual vocabulary shared by the code-native preset renderer.
enum IdentityPresetMotif {
  bolt,
  wing,
  gate,
  flame,
  bridge,
  stripes,
  panther,
  goalNet,
  sunrise,
  crossedLines,
  floodlights,
  cityBlocks,
  diagonal,
  chevron,
  split,
  horizon,
  sash,
  channels,
  centerCircle,
  whistle,
  matchBall,
}

/// A versioned, storage-safe reference such as:
/// `preset://v1/team_badge/street_bolt`.
@immutable
class IdentityPresetReference {
  const IdentityPresetReference({required this.family, required this.id})
    : assert(id != '');

  static const String scheme = 'preset';
  static const String version = 'v1';
  static final RegExp _validId = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');

  final IdentityPresetFamily family;
  final String id;

  String get value => '$scheme://$version/${family.pathSegment}/$id';

  bool get isValid => _validId.hasMatch(id);

  static IdentityPresetReference? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != scheme ||
        uri.host != version ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.length != 2) {
      return null;
    }

    final family = IdentityPresetFamily.fromPathSegment(uri.pathSegments.first);
    final id = uri.pathSegments.last;
    if (family == null || !_validId.hasMatch(id)) return null;

    final reference = IdentityPresetReference(family: family, id: id);
    return reference.value == value ? reference : null;
  }

  @override
  bool operator ==(Object other) {
    return other is IdentityPresetReference &&
        other.family == family &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(family, id);

  @override
  String toString() => value;
}

/// One original, built-in visual identity option.
@immutable
class IdentityPreset {
  const IdentityPreset({
    required this.reference,
    required this.nameAr,
    required this.motif,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final IdentityPresetReference reference;
  final String nameAr;
  final IdentityPresetMotif motif;
  final Color primaryColor;
  final Color secondaryColor;

  IdentityPresetFamily get family => reference.family;
  String get value => reference.value;
}

/// Explicit result so clearing a logo is distinguishable from closing a picker.
@immutable
class IdentityPresetSelection {
  const IdentityPresetSelection._({
    required this.reference,
    required this.isCleared,
  });

  const IdentityPresetSelection.use(String reference)
    : this._(reference: reference, isCleared: false);

  const IdentityPresetSelection.clear()
    : this._(reference: null, isCleared: true);

  final String? reference;
  final bool isCleared;
}
