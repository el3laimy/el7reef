import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/navigation/app_link_service.dart';
import 'package:el7reef/core/navigation/pending_deep_link_service.dart';

void main() {
  group('AppLinkService', () {
    test('stores a cold-start link until Splash can route it', () async {
      final pendingDeepLinkService = PendingDeepLinkService();
      final incomingLinks = StreamController<Uri>();
      final service = AppLinkService(
        pendingDeepLinkService: pendingDeepLinkService,
        getInitialLink: () async => Uri.parse(
          'https://el7reef-app.web.app/claim?code=SAFE-CODE&type=guestPlayer&targetId=guest-1',
        ),
        uriLinkStream: incomingLinks.stream,
        canNavigate: () => false,
      );

      await service.init();
      await Future<void>.delayed(Duration.zero);

      final route = Uri.parse(pendingDeepLinkService.take()!);
      expect(route.path, '/claim');
      expect(route.queryParameters['code'], 'SAFE-CODE');
      await incomingLinks.close();
      service.onClose();
    });

    test(
      '2026-07-17 startup continues while the initial app link is stalled',
      () async {
        final pendingDeepLinkService = PendingDeepLinkService();
        final initialLink = Completer<Uri?>();
        final incomingLinks = StreamController<Uri>();
        final service = AppLinkService(
          pendingDeepLinkService: pendingDeepLinkService,
          getInitialLink: () => initialLink.future,
          uriLinkStream: incomingLinks.stream,
          canNavigate: () => false,
        );

        final initializedService = await service.init().timeout(
          const Duration(milliseconds: 100),
        );

        expect(identical(initializedService, service), isTrue);
        expect(pendingDeepLinkService.hasPendingRoute, isFalse);

        initialLink.complete(
          Uri.parse('https://el7reef-app.web.app/tournament/world-cup-2026'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(pendingDeepLinkService.take(), '/tournament/world-cup-2026');
        await incomingLinks.close();
        service.onClose();
      },
    );

    test('navigates a warm link after storing the sanitized route', () async {
      final pendingDeepLinkService = PendingDeepLinkService();
      final incomingLinks = StreamController<Uri>();
      final navigatedRoutes = <String>[];
      final service = AppLinkService(
        pendingDeepLinkService: pendingDeepLinkService,
        getInitialLink: () async => null,
        uriLinkStream: incomingLinks.stream,
        canNavigate: () => true,
        navigate: navigatedRoutes.add,
      );
      await service.init();

      incomingLinks.add(
        Uri.parse(
          'el7reef://invite?code=TEAM-CODE&type=teamInvite&targetId=team-1&subjectName=Team',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(navigatedRoutes, hasLength(1));
      final route = Uri.parse(navigatedRoutes.single);
      expect(route.path, '/invite');
      expect(route.queryParameters.containsKey('subjectName'), isFalse);
      expect(pendingDeepLinkService.hasPendingRoute, isFalse);
      await incomingLinks.close();
      service.onClose();
    });
  });
}
