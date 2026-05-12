abstract class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'لا يوجد اتصال مستقر بالإنترنت. حاول مرة أخرى.',
    Object? cause,
  ]) : super(cause: cause);
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'لا تملك صلاحية تنفيذ هذه العملية.',
    Object? cause,
  ]) : super(cause: cause);
}

class DocumentNotFoundException extends AppException {
  const DocumentNotFoundException([
    super.message = 'البيانات المطلوبة غير موجودة.',
    Object? cause,
  ]) : super(cause: cause);
}

class FirebaseOperationException extends AppException {
  const FirebaseOperationException([
    super.message = 'تعذر إتمام العملية حالياً. حاول مرة أخرى.',
    Object? cause,
  ]) : super(cause: cause);
}
