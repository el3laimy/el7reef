import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// أداة تسجيل أخطاء بسيطة — تعرض الأخطاء في Debug mode فقط
/// تمنع ابتلاع الأخطاء بصمت في catch(_) blocks
class AppLogger {
  AppLogger._();

  /// تسجيل خطأ مع السياق
  static void error(String context, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('❌ [$context] $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
    if (error != null) {
      _recordNonFatal(context, error, stackTrace);
    }
  }

  /// تسجيل تحذير
  static void warning(String context, [dynamic message]) {
    debugPrint('⚠️ [$context] $message');
  }

  /// تسجيل معلومة (debug فقط)
  static void info(String context, [dynamic message]) {
    if (kDebugMode) {
      debugPrint('ℹ️ [$context] $message');
    }
  }

  static void _recordNonFatal(
    String context,
    dynamic error,
    StackTrace? stackTrace,
  ) {
    if (kIsWeb || Firebase.apps.isEmpty) {
      return;
    }
    unawaited(
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: context,
        fatal: false,
      ),
    );
  }
}
