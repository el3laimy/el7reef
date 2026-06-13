import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'app/theme/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'core/auth/auth_service.dart';
import 'core/services/feature_flag_service.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';

void main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // ── تهيئة Firebase حسب المنصة ──
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _configureErrorReporting();

      // ── تسجيل الخدمات الأساسية ──
      await Get.putAsync(() => FeatureFlagService().init());
      await Get.putAsync(() => AuthService().init());

      // ── شاشة كاملة مع status bar شفاف ──
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF0A0E17),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );

      runApp(const El7reefApp());
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
