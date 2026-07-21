import '../../domain/entities/share_payload.dart';

abstract class PrideShareAttribution {
  static const String cardTypeKey = 'shareCardType';
  static const String entityTypeKey = 'shareEntityType';
  static const String entityIdKey = 'shareEntityId';
  static const String tournamentIdKey = 'shareTournamentId';
  static const String matchIdKey = 'shareMatchId';
  static const String campaignSourceKey = 'shareCampaignSource';
  static const String schemaVersionKey = 'shareSchemaVersion';

  static const Set<String> publicQueryParameterNames = {
    cardTypeKey,
    entityTypeKey,
    entityIdKey,
    tournamentIdKey,
    matchIdKey,
    campaignSourceKey,
    schemaVersionKey,
  };

  static Uri attributedPublicUri(SharePayload payload) {
    return appendToUri(payload.claimUrl ?? payload.targetUrl, payload);
  }

  static Uri appendToUri(Uri uri, SharePayload payload) {
    final queryParameters = <String, String>{
      ...uri.queryParameters,
      cardTypeKey: payload.cardType.name,
      entityTypeKey: payload.entityType.name,
      entityIdKey: payload.entityId,
      if (payload.tournamentId case final String tournamentId)
        tournamentIdKey: tournamentId,
      if (payload.matchId case final String matchId) matchIdKey: matchId,
      campaignSourceKey: payload.campaignSource,
      schemaVersionKey: payload.schemaVersion.toString(),
    };
    return uri.replace(queryParameters: queryParameters);
  }

  static SharePayload? fromQueryParameters(
    Map<String, String?> queryParameters, {
    required Uri targetUrl,
  }) {
    try {
      final cardType = _cardType(queryParameters[cardTypeKey]);
      final entityType = _entityType(queryParameters[entityTypeKey]);
      final entityId = queryParameters[entityIdKey];
      final campaignSource = queryParameters[campaignSourceKey];
      final schemaVersion = int.tryParse(
        queryParameters[schemaVersionKey] ?? '',
      );
      if (cardType == null ||
          entityType == null ||
          entityId == null ||
          campaignSource == null ||
          schemaVersion == null) {
        return null;
      }

      return SharePayload(
        cardType: cardType,
        entityType: entityType,
        entityId: entityId,
        tournamentId: queryParameters[tournamentIdKey],
        matchId: queryParameters[matchIdKey],
        targetUrl: targetUrl,
        campaignSource: campaignSource,
        schemaVersion: schemaVersion,
      );
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  static ShareCardType? _cardType(String? rawValue) {
    if (rawValue == null) return null;
    for (final value in ShareCardType.values) {
      if (value.name == rawValue) return value;
    }
    return null;
  }

  static ShareEntityType? _entityType(String? rawValue) {
    if (rawValue == null) return null;
    for (final value in ShareEntityType.values) {
      if (value.name == rawValue) return value;
    }
    return null;
  }
}
