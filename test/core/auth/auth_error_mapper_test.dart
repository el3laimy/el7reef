import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/auth/auth_error_mapper.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps Google ApiException 10 to Firebase SHA setup guidance', () {
      final message = AuthErrorMapper.mapUnexpectedSignInError(
        'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)',
      );

      expect(message, contains('Firebase وSHA'));
    });

    test('maps developer error platform failures to setup guidance', () {
      final message = AuthErrorMapper.mapPlatformSignInError(
        PlatformException(code: 'sign_in_failed', message: 'DEVELOPER_ERROR'),
      );

      expect(message, contains('Firebase وSHA'));
    });

    test('keeps Google cancellation silent', () {
      final message = AuthErrorMapper.mapPlatformSignInError(
        PlatformException(code: 'sign_in_canceled'),
      );

      expect(message, isEmpty);
    });

    test('maps sign-in network failures to retry guidance', () {
      final message = AuthErrorMapper.mapPlatformSignInError(
        PlatformException(
          code: 'network_error',
          message: 'service_not_available',
        ),
      );

      expect(message, 'الاتصال غير مستقر. حاول مرة أخرى.');
    });

    for (final (:name, :error, :expectedText) in [
      (
        name: 'permission failures',
        error: 'PERMISSION_DENIED: Missing or insufficient permissions.',
        expectedText: 'صلاحيات قاعدة البيانات',
      ),
      (
        name: 'network failures',
        error: 'FirebaseException: unavailable network',
        expectedText: 'الاتصال ضعيف',
      ),
      (
        name: 'timeouts',
        error: TimeoutException('profile load timed out'),
        expectedText: 'انتهت مهلة',
      ),
    ]) {
      test('maps profile $name without asking for sign out', () {
        final message = AuthErrorMapper.mapProfileLoadError(error);

        expect(message, contains(expectedText));
      });
    }
  });
}
