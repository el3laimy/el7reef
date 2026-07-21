import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/firebase/firebase_config_guard.dart';
import 'package:el7reef/firebase_options.dart';

void main() {
  test('accepts the current Android Firebase project in debug', () {
    final options = _options(
      projectId: FirebaseConfigGuard.androidProjectId,
      appId: FirebaseConfigGuard.androidAppId,
      messagingSenderId: FirebaseConfigGuard.androidSenderId,
    );

    final issue = FirebaseConfigGuard.findIssue(
      runtimeOptions: options,
      flutterOptions: options,
      platform: TargetPlatform.android,
      debugMode: true,
    );

    expect(issue, isNull);
  });

  test('generated Android options stay on the active Firebase project', () {
    expect(
      DefaultFirebaseOptions.android.projectId,
      FirebaseConfigGuard.androidProjectId,
    );
    expect(
      DefaultFirebaseOptions.android.appId,
      FirebaseConfigGuard.androidAppId,
    );
    expect(
      DefaultFirebaseOptions.android.messagingSenderId,
      FirebaseConfigGuard.androidSenderId,
    );
  });

  test(
    'generated iOS options are blocked until migrated to the active project',
    () {
      expect(
        () => DefaultFirebaseOptions.ios,
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            contains(FirebaseConfigGuard.iosProjectId),
          ),
        ),
      );
    },
  );

  test('flags stale Android FlutterFire project in debug', () {
    final runtimeOptions = _options(
      projectId: FirebaseConfigGuard.androidProjectId,
      appId: FirebaseConfigGuard.androidAppId,
      messagingSenderId: FirebaseConfigGuard.androidSenderId,
    );
    final staleFlutterOptions = _options(
      projectId: 'el7reef-app-2026',
      appId: '1:807857485912:android:stale',
      messagingSenderId: '807857485912',
    );

    final issue = FirebaseConfigGuard.findIssue(
      runtimeOptions: runtimeOptions,
      flutterOptions: staleFlutterOptions,
      platform: TargetPlatform.android,
      debugMode: true,
    );

    expect(issue, isNotNull);
    expect(issue!.message, contains('el7reef-app-2026'));
    expect(issue.message, contains(FirebaseConfigGuard.androidProjectId));
  });

  test('flags the old iOS project until it is migrated or scoped out', () {
    final staleIosOptions = _options(
      projectId: 'el7reef-app-2026',
      appId: '1:807857485912:ios:4068f942ababc771d8f22d',
      messagingSenderId: '807857485912',
    );

    final issue = FirebaseConfigGuard.findIssue(
      runtimeOptions: staleIosOptions,
      flutterOptions: staleIosOptions,
      platform: TargetPlatform.iOS,
      debugMode: true,
    );

    expect(issue, isNotNull);
    expect(issue!.message, contains('el7reef-app-2026'));
    expect(issue.message, contains(FirebaseConfigGuard.iosProjectId));
  });

  test('does not block release mode', () {
    final staleOptions = _options(
      projectId: 'el7reef-app-2026',
      appId: '1:807857485912:android:stale',
      messagingSenderId: '807857485912',
    );

    final issue = FirebaseConfigGuard.findIssue(
      runtimeOptions: staleOptions,
      flutterOptions: staleOptions,
      platform: TargetPlatform.android,
      debugMode: false,
    );

    expect(issue, isNull);
  });
}

FirebaseOptions _options({
  required String projectId,
  required String appId,
  required String messagingSenderId,
}) {
  return FirebaseOptions(
    apiKey: 'test-api-key',
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
  );
}
