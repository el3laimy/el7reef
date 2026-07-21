import '../../app/routes/app_routes.dart';
import '../../domain/entities/claim_payload.dart';
import '../services/pride_share_attribution.dart';

abstract class AppLinkRouteParser {
  static const String pilotWebHost = 'el7reef-app.web.app';
  static const String primaryWebHost = 'el7reef.app';
  static const String customScheme = 'el7reef';

  static const Set<String> _webHosts = {pilotWebHost, primaryWebHost};
  static final RegExp _identifierPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$',
  );

  static String? routeFor(Uri uri) {
    if (uri.scheme == 'https' && _webHosts.contains(uri.host.toLowerCase())) {
      return _routeFromWebPath(uri.pathSegments, uri.queryParameters);
    }
    if (uri.scheme != customScheme) return null;

    return _routeFromCustomScheme(uri);
  }

  static String? _routeFromCustomScheme(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'claim' || host == 'invite') {
      return _hasOnlyEmptyPath(uri.pathSegments)
          ? _routeForClaimOrInvite(host, uri.queryParameters)
          : null;
    }
    if (host == 'match') {
      return _routeForMatch(uri.pathSegments, uri.queryParameters);
    }
    if (host == 'tournament') {
      return _routeForTournament(uri.pathSegments);
    }
    if (host == 'player') {
      return _routeForPlayer(uri.pathSegments);
    }
    if (host == 'team') {
      return _routeForTeam(uri.pathSegments);
    }
    if (host.isEmpty) {
      return _routeFromWebPath(uri.pathSegments, uri.queryParameters);
    }
    return null;
  }

  static String? _routeFromWebPath(
    List<String> pathSegments,
    Map<String, String> queryParameters,
  ) {
    final segments = _nonEmptySegments(pathSegments);
    if (segments.length == 1 &&
        (segments.single == 'claim' || segments.single == 'invite')) {
      return _routeForClaimOrInvite(segments.single, queryParameters);
    }
    if (segments.length == 2 && segments.first == 'match') {
      return _routeForMatch([segments[1]], queryParameters);
    }
    if (segments.length == 2 && segments.first == 'tournament') {
      return _routeForTournament([segments[1]]);
    }
    if (segments.length == 3 && segments.first == 'player') {
      return _routeForPlayer([segments[1], segments[2]]);
    }
    if (segments.length == 3 && segments.first == 'team') {
      return _routeForTeam([segments[1], segments[2]]);
    }
    return null;
  }

  static String _routeForClaimOrInvite(
    String entry,
    Map<String, String> queryParameters,
  ) {
    final safeQueryParameters = <String, String?>{};
    for (final queryEntry in queryParameters.entries) {
      if ((ClaimPayload.publicQueryParameterNames.contains(queryEntry.key) ||
              PrideShareAttribution.publicQueryParameterNames.contains(
                queryEntry.key,
              )) &&
          queryEntry.value.trim().isNotEmpty) {
        safeQueryParameters[queryEntry.key] = queryEntry.value;
      }
    }
    return entry == 'claim'
        ? AppRoutes.claimEntryWithQuery(safeQueryParameters)
        : AppRoutes.inviteEntryWithQuery(safeQueryParameters);
  }

  static String? _routeForMatch(
    List<String> pathSegments,
    Map<String, String> queryParameters,
  ) {
    final segments = _nonEmptySegments(pathSegments);
    if (segments.length != 1 || !_isIdentifier(segments.single)) return null;

    return queryParameters['view'] == 'lineup'
        ? AppRoutes.matchResultLineupById(segments.single)
        : AppRoutes.matchDetailsById(segments.single);
  }

  static String? _routeForTournament(List<String> pathSegments) {
    final segments = _nonEmptySegments(pathSegments);
    if (segments.length != 1 || !_isIdentifier(segments.single)) return null;
    return AppRoutes.tournamentDetailById(segments.single);
  }

  static String? _routeForPlayer(List<String> pathSegments) {
    final segments = _nonEmptySegments(pathSegments);
    if (segments.length != 2 || !_isIdentifier(segments[1])) return null;

    final kind = switch (segments.first.toLowerCase()) {
      'player' => 'player',
      'guestplayer' => 'guestPlayer',
      _ => null,
    };
    if (kind == null) return null;
    return AppRoutes.playerProfileByKindAndId(kind: kind, id: segments[1]);
  }

  static String? _routeForTeam(List<String> pathSegments) {
    final segments = _nonEmptySegments(pathSegments);
    if (segments.length != 2 || !_isIdentifier(segments[1])) return null;
    final kind = switch (segments.first) {
      'registeredTeam' => 'registeredTeam',
      'guestTeam' => 'guestTeam',
      _ => null,
    };
    if (kind == null) return null;
    return AppRoutes.publicTeamProfileByKindAndId(kind: kind, id: segments[1]);
  }

  static List<String> _nonEmptySegments(List<String> pathSegments) {
    return pathSegments
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.trim())
        .toList(growable: false);
  }

  static bool _hasOnlyEmptyPath(List<String> pathSegments) {
    return pathSegments.every((segment) => segment.isEmpty);
  }

  static bool _isIdentifier(String value) => _identifierPattern.hasMatch(value);
}
