import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/navigation/app_link_route_parser.dart';

void main() {
  group('AppLinkRouteParser', () {
    test('maps an HTTPS claim link and removes unapproved query fields', () {
      final route = AppLinkRouteParser.routeFor(
        Uri.parse(
          'https://el7reef-app.web.app/claim?code=SAFE-CODE&type=guestPlayer&targetId=guest-1&subjectName=Guest&utm_source=chat',
        ),
      );

      final routeUri = Uri.parse(route!);
      expect(routeUri.path, '/claim');
      expect(routeUri.queryParameters['code'], 'SAFE-CODE');
      expect(routeUri.queryParameters['type'], 'guestPlayer');
      expect(routeUri.queryParameters['targetId'], 'guest-1');
      expect(routeUri.queryParameters.containsKey('subjectName'), isFalse);
      expect(routeUri.queryParameters.containsKey('utm_source'), isFalse);
    });

    test('preserves only safe pride attribution on a claim link', () {
      final route = AppLinkRouteParser.routeFor(
        Uri.parse(
          'https://el7reef-app.web.app/claim?code=SAFE-CODE&type=guestPlayer&targetId=guest-1&shareCardType=mvp&shareEntityType=guestPlayer&shareEntityId=guest-1&shareMatchId=match-1&shareCampaignSource=mvp_card&shareSchemaVersion=1&displayName=Guest',
        ),
      );

      final routeUri = Uri.parse(route!);
      expect(routeUri.queryParameters['shareCardType'], 'mvp');
      expect(routeUri.queryParameters['shareEntityType'], 'guestPlayer');
      expect(routeUri.queryParameters['shareEntityId'], 'guest-1');
      expect(routeUri.queryParameters['shareMatchId'], 'match-1');
      expect(routeUri.queryParameters['shareCampaignSource'], 'mvp_card');
      expect(routeUri.queryParameters['shareSchemaVersion'], '1');
      expect(routeUri.queryParameters.containsKey('displayName'), isFalse);
    });

    test('maps custom-scheme invite links', () {
      final route = AppLinkRouteParser.routeFor(
        Uri.parse(
          'el7reef://invite?code=TEAM-CODE&type=teamInvite&targetId=team-1',
        ),
      );

      final routeUri = Uri.parse(route!);
      expect(routeUri.path, '/invite');
      expect(routeUri.queryParameters['code'], 'TEAM-CODE');
      expect(routeUri.queryParameters['type'], 'teamInvite');
      expect(routeUri.queryParameters['targetId'], 'team-1');
    });

    test('maps current pride-card URLs to their public app routes', () {
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('https://el7reef-app.web.app/match/match-1'),
        ),
        '/match/details/match-1',
      );
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse(
            'https://el7reef-app.web.app/match/match-1?view=lineup&utm_source=chat',
          ),
        ),
        '/match/match-1/lineup/result',
      );
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('el7reef://tournament/tournament-1'),
        ),
        '/tournament/tournament-1',
      );
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('el7reef://player/guestPlayer/guest-1'),
        ),
        '/player/guestPlayer/guest-1',
      );
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('https://el7reef-app.web.app/team/guestTeam/guest-team-1'),
        ),
        '/team/public/guestTeam/guest-team-1',
      );
    });

    test('rejects unsupported hosts and paths', () {
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('https://example.com/claim?code=SAFE-CODE'),
        ),
        isNull,
      );
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('https://el7reef-app.web.app/unknown?code=SAFE-CODE'),
        ),
        isNull,
      );
      expect(
        AppLinkRouteParser.routeFor(
          Uri.parse('https://el7reef-app.web.app/match/not%20safe'),
        ),
        isNull,
      );
    });
  });
}
