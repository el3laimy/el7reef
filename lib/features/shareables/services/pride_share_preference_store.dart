import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import '../models/pride_card_format.dart';
import '../models/pride_export.dart';

class PrideSharePreferenceStore {
  static const _formatKey = 'last_pride_card_format';
  static const _mediaTypeKey = 'last_pride_media_type';
  static const _includeAudioKey = 'last_pride_include_audio';

  final Future<SharedPreferences> Function() _preferencesLoader;

  PrideSharePreferenceStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  Future<PrideShareSelection> load({required bool videoAvailable}) async {
    try {
      final preferences = await _preferencesLoader();
      final storedFormat = preferences.getString(_formatKey);
      final storedMediaType = preferences.getString(_mediaTypeKey);
      final format =
          _enumByName(PrideCardFormat.values, storedFormat) ??
          PrideCardFormat.feed4x5;
      final preferredMediaType =
          _enumByName(PrideMediaType.values, storedMediaType) ??
          PrideMediaType.image;

      return PrideShareSelection(
        format: format,
        mediaType: videoAvailable ? preferredMediaType : PrideMediaType.image,
        includeAudio: preferences.getBool(_includeAudioKey) ?? true,
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.error('PrideSharePreferences.load', error, stackTrace);
      return const PrideShareSelection(
        format: PrideCardFormat.feed4x5,
        mediaType: PrideMediaType.image,
        includeAudio: true,
      );
    }
  }

  Future<void> save(PrideShareSelection selection) async {
    try {
      final preferences = await _preferencesLoader();
      await Future.wait([
        preferences.setString(_formatKey, selection.format.name),
        preferences.setString(_mediaTypeKey, selection.mediaType.name),
        preferences.setBool(_includeAudioKey, selection.includeAudio),
      ]);
    } on Exception catch (error, stackTrace) {
      AppLogger.error('PrideSharePreferences.save', error, stackTrace);
    }
  }

  T? _enumByName<T extends Enum>(List<T> candidates, String? storedName) {
    if (storedName == null) return null;
    for (final candidate in candidates) {
      if (candidate.name == storedName) return candidate;
    }
    return null;
  }
}
