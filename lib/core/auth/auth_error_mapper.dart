import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class AuthDisplayException implements Exception {
  final String message;

  const AuthDisplayException(this.message);

  @override
  String toString() => message;
}

class AuthErrorMapper {
  const AuthErrorMapper._();

  static String mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'الحساب مسجل بطريقة تانية';
      case 'invalid-credential':
        return 'بيانات الدخول غير صحيحة';
      case 'operation-not-allowed':
        return 'طريقة الدخول غير مفعّلة';
      case 'user-disabled':
        return 'الحساب معطّل';
      case 'too-many-requests':
        return 'محاولات كثيرة جداً، حاول لاحقاً';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت';
      default:
        return 'حدث خطأ غير متوقع: ${e.message}';
    }
  }

  static String mapPlatformSignInError(PlatformException e) {
    final raw = '${e.code} ${e.message} ${e.details}'.toLowerCase();
    if (raw.contains('10') || raw.contains('developer_error')) {
      return 'إعدادات Google لهذا الإصدار غير مكتملة. راجع Firebase وSHA ثم جرّب build جديد.';
    }
    if (e.code == 'missing_google_auth_token') {
      return 'لم يرجع Google بيانات دخول صالحة. راجع إعدادات OAuth ثم جرّب مرة أخرى.';
    }
    if (raw.contains('network') || raw.contains('service_not_available')) {
      return 'الاتصال غير مستقر. حاول مرة أخرى.';
    }
    if (e.code == 'sign_in_canceled') {
      return '';
    }
    return 'تعذر تسجيل الدخول بحساب Google حالياً. حاول مرة أخرى.';
  }

  static String mapUnexpectedSignInError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('api') && raw.contains('10')) {
      return 'إعدادات Google لهذا الإصدار غير مكتملة. راجع Firebase وSHA ثم جرّب build جديد.';
    }
    if (raw.contains('missing_google_auth_token')) {
      return 'لم يرجع Google بيانات دخول صالحة. راجع إعدادات OAuth ثم جرّب مرة أخرى.';
    }
    if (raw.contains('network') || raw.contains('service_not_available')) {
      return 'الاتصال غير مستقر. حاول مرة أخرى.';
    }
    return 'تعذر تسجيل الدخول حالياً. حاول مرة أخرى.';
  }

  static String mapProfileLoadError(Object error) {
    if (error is TimeoutException) {
      return 'تم تسجيل الدخول، لكن انتهت مهلة تجهيز حسابك. حاول مرة أخرى.';
    }
    final raw = error.toString().toLowerCase();
    if (raw.contains('permission') || raw.contains('صلاحية')) {
      return 'تم تسجيل الدخول، لكن لا يمكن تجهيز بيانات حسابك بسبب صلاحيات قاعدة البيانات.';
    }
    if (raw.contains('network') ||
        raw.contains('unavailable') ||
        raw.contains('deadline') ||
        raw.contains('timeout')) {
      return 'تم تسجيل الدخول، لكن الاتصال ضعيف أثناء تجهيز حسابك.';
    }
    return 'تم تسجيل الدخول، لكن تعذر تجهيز حسابك حالياً.';
  }
}
