import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/services/cloud_sensitive_ops_service.dart';

void main() {
  group('CloudSensitiveOpsService', () {
    test('classifies only availability errors as fallbackable', () {
      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode('unavailable'),
        isTrue,
      );
      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode('not-found'),
        isTrue,
      );
      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode(
          'deadline-exceeded',
        ),
        isTrue,
      );

      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode(
          'permission-denied',
        ),
        isFalse,
      );
      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode(
          'unauthenticated',
        ),
        isFalse,
      );
      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode(
          'invalid-argument',
        ),
        isFalse,
      );
      expect(
        CloudSensitiveOpsService.shouldFallbackForFunctionCode(
          'failed-precondition',
        ),
        isFalse,
      );
    });
  });
}
