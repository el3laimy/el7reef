import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'app/theme/app_theme.dart';
import 'app/routes/app_pages.dart';
import 'firebase_options.dart';
import 'core/auth/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    FirebaseOptions? options;
    try {
      options = DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      options = null;
    }
    await Firebase.initializeApp(options: options);
  }

  // ── تسجيل الخدمات الأساسية ──
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
