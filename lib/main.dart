import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'app/theme/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'core/auth/auth_service.dart';
import 'core/firebase/firebase_config_guard.dart';
import 'core/navigation/app_link_service.dart';
import 'core/navigation/pending_deep_link_service.dart';
import 'core/services/feature_flag_service.dart';
import 'core/utils/app_logger.dart';
import 'core/widgets/el7reef_brand_mark.dart';
import 'firebase_options.dart';

const bool _useFirestoreEmulator = bool.fromEnvironment(
  'USE_FIRESTORE_EMULATOR',
);
const String _firestoreEmulatorHost = String.fromEnvironment(
  'FIRESTORE_EMULATOR_HOST_NAME',
  defaultValue: '10.0.2.2',
);
const int _firestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);
const bool _useAuthEmulator = bool.fromEnvironment('USE_AUTH_EMULATOR');
const String _authEmulatorHost = String.fromEnvironment(
  'AUTH_EMULATOR_HOST_NAME',
  defaultValue: '10.0.2.2',
);
const int _authEmulatorPort = int.fromEnvironment(
  'AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const bool _useFunctionsEmulator = bool.fromEnvironment(
  'USE_FUNCTIONS_EMULATOR',
);
const String _functionsEmulatorHost = String.fromEnvironment(
  'FUNCTIONS_EMULATOR_HOST_NAME',
  defaultValue: '10.0.2.2',
);
const int _functionsEmulatorPort = int.fromEnvironment(
  'FUNCTIONS_EMULATOR_PORT',
  defaultValue: 5001,
);
const String _worldCupOrganizerEmail = 'world-cup-organizer@example.test';
const String _worldCupOrganizerPassword = 'WorldCup2026!';
bool _firestoreEmulatorConfigured = false;
bool _authEmulatorConfigured = false;
bool _functionsEmulatorConfigured = false;

void main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // ── شاشة كاملة مع status bar شفاف ──
      _configureSystemUi();

      runApp(const El7reefBootstrapApp());
    },
    (error, stackTrace) {
      AppLogger.error('runZonedGuarded', error, stackTrace);
      if (Firebase.apps.isNotEmpty) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            fatal: true,
          ),
        );
      }
    },
  );
}

void _configureSystemUi() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E17),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

Future<void> _bootstrapCoreServices() async {
  if (!Get.isRegistered<PendingDeepLinkService>()) {
    Get.put(PendingDeepLinkService(), permanent: true);
  }
  if (!Get.isRegistered<AppLinkService>()) {
    await Get.putAsync(() => AppLinkService().init(), permanent: true);
  }

  // Show the first Flutter frame before network-backed services can block.
  await _ensureFirebaseInitialized().timeout(const Duration(seconds: 15));
  _configureErrorReporting();

  if (!Get.isRegistered<FeatureFlagService>()) {
    await Get.putAsync(
      () => FeatureFlagService().init().timeout(const Duration(seconds: 15)),
      permanent: true,
    );
  }
  if (!Get.isRegistered<AuthService>()) {
    await Get.putAsync(
      () => AuthService().init().timeout(const Duration(seconds: 15)),
      permanent: true,
    );
  }
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    await _configureDebugFirebaseEmulators();
    _inspectFirebaseConfig(Firebase.app().options);
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  } finally {
    if (Firebase.apps.isNotEmpty) {
      await _configureDebugFirebaseEmulators();
      _inspectFirebaseConfig(Firebase.app().options);
    }
  }
}

Future<void> _configureDebugFirebaseEmulators() async {
  _configureDebugFirestoreEmulator();
  _configureDebugFunctionsEmulator();
  if (!kDebugMode || !_useAuthEmulator) {
    return;
  }

  final auth = FirebaseAuth.instance;
  if (!_authEmulatorConfigured) {
    await auth.useAuthEmulator(_authEmulatorHost, _authEmulatorPort);
    _authEmulatorConfigured = true;
    AppLogger.info(
      'Firebase.authEmulator',
      '$_authEmulatorHost:$_authEmulatorPort',
    );
  }

  await auth.signInWithEmailAndPassword(
    email: _worldCupOrganizerEmail,
    password: _worldCupOrganizerPassword,
  );
}

void _configureDebugFunctionsEmulator() {
  if (!kDebugMode || !_useFunctionsEmulator || _functionsEmulatorConfigured) {
    return;
  }
  FirebaseFunctions.instance.useFunctionsEmulator(
    _functionsEmulatorHost,
    _functionsEmulatorPort,
  );
  _functionsEmulatorConfigured = true;
  AppLogger.info(
    'Firebase.functionsEmulator',
    '$_functionsEmulatorHost:$_functionsEmulatorPort',
  );
}

void _configureDebugFirestoreEmulator() {
  if (!kDebugMode || !_useFirestoreEmulator || _firestoreEmulatorConfigured) {
    return;
  }
  FirebaseFirestore.instance.useFirestoreEmulator(
    _firestoreEmulatorHost,
    _firestoreEmulatorPort,
  );
  _firestoreEmulatorConfigured = true;
  AppLogger.info(
    'Firebase.firestoreEmulator',
    '$_firestoreEmulatorHost:$_firestoreEmulatorPort',
  );
}

void _inspectFirebaseConfig(FirebaseOptions actualOptions) {
  _logFirebaseProjectMismatch(actualOptions);
  FirebaseConfigGuard.assertValidDebugConfig(
    runtimeOptions: actualOptions,
    flutterOptions: DefaultFirebaseOptions.currentPlatform,
    platform: defaultTargetPlatform,
  );
}

void _logFirebaseProjectMismatch(FirebaseOptions actualOptions) {
  final expectedOptions = DefaultFirebaseOptions.currentPlatform;
  if (actualOptions.projectId == expectedOptions.projectId) {
    return;
  }
  AppLogger.warning(
    'Firebase.config',
    'Native Firebase project "${actualOptions.projectId}" does not match '
        'FlutterFire project "${expectedOptions.projectId}".',
  );
}

void _configureErrorReporting() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error('FlutterError', details.exception, details.stack);
    unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error('PlatformDispatcher', error, stackTrace);
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true),
    );
    return true;
  };
}

class El7reefBootstrapApp extends StatefulWidget {
  const El7reefBootstrapApp({super.key});

  @override
  State<El7reefBootstrapApp> createState() => _El7reefBootstrapAppState();
}

class _El7reefBootstrapAppState extends State<El7reefBootstrapApp> {
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapCoreServices();
  }

  void _retry() {
    setState(() {
      _bootstrapFuture = _bootstrapCoreServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        final bootstrapped =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        if (bootstrapped) {
          return const El7reefApp();
        }

        return _BootstrapShell(
          error: snapshot.connectionState == ConnectionState.done
              ? snapshot.error
              : null,
          onRetry: _retry,
        );
      },
    );
  }
}

class _BootstrapShell extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _BootstrapShell({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return MaterialApp(
      title: 'الحريف',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF111827), Color(0xFF050807)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const El7reefBrandMark(size: 132),
                    const SizedBox(height: 28),
                    Text(
                      'الحريف',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF6EE15F),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasError
                          ? 'تعذر تجهيز التطبيق حالياً'
                          : 'بنجهز الملعب...',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                    if (hasError && kDebugMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        '$error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFFC4C4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (hasError)
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('إعادة المحاولة'),
                      )
                    else
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class El7reefApp extends StatelessWidget {
  const El7reefApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      // ── App Info ──
      title: 'الحريف',
      debugShowCheckedModeBanner: false,

      // ── RTL & Arabic ──
      locale: const Locale('ar', 'EG'),
      fallbackLocale: const Locale('ar', 'EG'),
      textDirection: TextDirection.rtl,

      // ── Theme ──
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,

      // ── Routing ──
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,

      // ── Default Transition ──
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 300),

      // ── Builder for RTL ──
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
