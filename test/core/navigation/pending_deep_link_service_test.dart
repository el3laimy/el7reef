import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/navigation/pending_deep_link_service.dart';

void main() {
  test('stores one pending route and consumes it once', () {
    final service = PendingDeepLinkService();

    service.store('/guest-player/guest-1/claim?code=abc');

    expect(service.hasPendingRoute, isTrue);
    expect(service.take(), '/guest-player/guest-1/claim?code=abc');
    expect(service.hasPendingRoute, isFalse);
    expect(service.take(), isNull);
  });

  test('ignores empty routes and can clear a stored route', () {
    final service = PendingDeepLinkService();

    service.store('');
    service.store('   ');
    expect(service.hasPendingRoute, isFalse);

    service.store('/invite?code=abc&targetId=team-1');
    expect(service.hasPendingRoute, isTrue);

    service.clear();
    expect(service.hasPendingRoute, isFalse);
    expect(service.take(), isNull);
  });
}
