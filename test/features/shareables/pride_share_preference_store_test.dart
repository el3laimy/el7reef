import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el7reef/features/shareables/models/pride_card_format.dart';
import 'package:el7reef/features/shareables/models/pride_export.dart';
import 'package:el7reef/features/shareables/services/pride_share_preference_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'last format, media type and sound choice survive the next share',
    () async {
      final store = PrideSharePreferenceStore();
      const selection = PrideShareSelection(
        format: PrideCardFormat.story9x16,
        mediaType: PrideMediaType.video,
        includeAudio: false,
      );

      await store.save(selection);
      final restored = await store.load(videoAvailable: true);

      expect(restored.format, PrideCardFormat.story9x16);
      expect(restored.mediaType, PrideMediaType.video);
      expect(restored.includeAudio, isFalse);
    },
  );

  test('stored video choice becomes image when video is unavailable', () async {
    SharedPreferences.setMockInitialValues({
      'last_pride_card_format': PrideCardFormat.landscape16x9.name,
      'last_pride_media_type': PrideMediaType.video.name,
      'last_pride_include_audio': false,
    });

    final restored = await PrideSharePreferenceStore().load(
      videoAvailable: false,
    );

    expect(restored.format, PrideCardFormat.landscape16x9);
    expect(restored.mediaType, PrideMediaType.image);
    expect(restored.includeAudio, isFalse);
  });

  test('storage failure falls back to safe defaults', () async {
    final store = PrideSharePreferenceStore(
      preferencesLoader: () => Future.error(Exception('storage unavailable')),
    );

    final restored = await store.load(videoAvailable: true);

    expect(restored.format, PrideCardFormat.feed4x5);
    expect(restored.mediaType, PrideMediaType.image);
    expect(restored.includeAudio, isTrue);
  });

  test('storage failure never blocks saving a share choice', () async {
    final store = PrideSharePreferenceStore(
      preferencesLoader: () => Future.error(Exception('storage unavailable')),
    );

    await expectLater(
      store.save(
        const PrideShareSelection(
          format: PrideCardFormat.square1x1,
          mediaType: PrideMediaType.image,
          includeAudio: true,
        ),
      ),
      completes,
    );
  });
}
