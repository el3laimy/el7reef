import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_exceptions.dart';

/// ترجمة Firebase exceptions لأخطاء domain واضحة بالعربي.
class FirebaseErrorHandler {
  const FirebaseErrorHandler._();

  static String translate(Object error) {
    if (isNetworkError(error)) {
      return 'لا يوجد اتصال مستقر بالإنترنت. حاول مرة أخرى.';
    }
    if (isPermissionError(error)) {
      return 'لا تملك صلاحية تنفيذ هذه العملية.';
    }
    if (isNotFoundError(error)) {
      return 'البيانات المطلوبة غير موجودة.';
    }
    return 'تعذر إتمام العملية حالياً. حاول مرة أخرى.';
  }

  static bool isNetworkError(Object error) {
    return error is FirebaseException &&
        const {
          'aborted',
          'cancelled',
          'data-loss',
          'deadline-exceeded',
          'resource-exhausted',
          'unavailable',
        }.contains(error.code);
  }

  static bool isPermissionError(Object error) {
    return error is FirebaseException &&
        const {'permission-denied', 'unauthenticated'}.contains(error.code);
  }

  static bool isNotFoundError(Object error) {
    return error is FirebaseException && error.code == 'not-found';
  }

  static Exception toException(Object error) {
    final message = translate(error);
    if (isNetworkError(error)) {
      return NetworkException(message, error);
    }
    if (isPermissionError(error)) {
      return PermissionDeniedException(message, error);
    }
    if (isNotFoundError(error)) {
      return DocumentNotFoundException(message, error);
    }
    return FirebaseOperationException(message, error);
  }

  static Future<T> guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error) {
      throw toException(error);
    }
  }
}
