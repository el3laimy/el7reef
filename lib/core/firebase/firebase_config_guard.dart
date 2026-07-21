import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfigGuard {
  static const String androidProjectId = 'el7reef-app';
  static const String androidAppId =
      '1:876861689777:android:0d2a83f5ba8026f0c7f790';
  static const String androidSenderId = '876861689777';

  static const String iosProjectId = 'el7reef-app';

  const FirebaseConfigGuard._();

  static FirebaseConfigIssue? findIssue({
    required FirebaseOptions runtimeOptions,
    required FirebaseOptions flutterOptions,
    required TargetPlatform platform,
    bool debugMode = kDebugMode,
  }) {
    if (!debugMode) return null;

    final expected = _ExpectedFirebaseConfig.forPlatform(platform);
    if (expected == null) return null;

    final problems = <String>[];
    if (flutterOptions.projectId != expected.projectId) {
      problems.add(
        'FlutterFire projectId is "${flutterOptions.projectId}" but '
        'expected "${expected.projectId}".',
      );
    }
    if (runtimeOptions.projectId != flutterOptions.projectId) {
      problems.add(
        'Runtime Firebase projectId is "${runtimeOptions.projectId}" but '
        'FlutterFire projectId is "${flutterOptions.projectId}".',
      );
    }
    if (expected.appId != null && flutterOptions.appId != expected.appId) {
      problems.add(
        'FlutterFire appId is "${flutterOptions.appId}" but expected '
        '"${expected.appId}".',
      );
    }
    if (expected.messagingSenderId != null &&
        flutterOptions.messagingSenderId != expected.messagingSenderId) {
      problems.add(
        'FlutterFire messagingSenderId is '
        '"${flutterOptions.messagingSenderId}" but expected '
        '"${expected.messagingSenderId}".',
      );
    }

    if (problems.isEmpty) return null;
    return FirebaseConfigIssue(platform: platform, problems: problems);
  }

  static void assertValidDebugConfig({
    required FirebaseOptions runtimeOptions,
    required FirebaseOptions flutterOptions,
    required TargetPlatform platform,
  }) {
    final issue = findIssue(
      runtimeOptions: runtimeOptions,
      flutterOptions: flutterOptions,
      platform: platform,
    );
    if (issue != null) {
      throw StateError(issue.message);
    }
  }
}

class FirebaseConfigIssue {
  final TargetPlatform platform;
  final List<String> problems;

  const FirebaseConfigIssue({required this.platform, required this.problems});

  String get message {
    final platformName = platform.name;
    final details = problems.map((problem) => '- $problem').join('\n');
    return 'Firebase config mismatch for $platformName.\n$details';
  }
}

class _ExpectedFirebaseConfig {
  final String projectId;
  final String? appId;
  final String? messagingSenderId;

  const _ExpectedFirebaseConfig({
    required this.projectId,
    this.appId,
    this.messagingSenderId,
  });

  static _ExpectedFirebaseConfig? forPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return const _ExpectedFirebaseConfig(
          projectId: FirebaseConfigGuard.androidProjectId,
          appId: FirebaseConfigGuard.androidAppId,
          messagingSenderId: FirebaseConfigGuard.androidSenderId,
        );
      case TargetPlatform.iOS:
        return const _ExpectedFirebaseConfig(
          projectId: FirebaseConfigGuard.iosProjectId,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }
}
