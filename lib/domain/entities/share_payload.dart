enum ShareCardType {
  matchResult,
  mvp,
  topScorers,
  lineup,
  champion,
  player,
  team,
  tournamentInvite,
  upcomingFixture,
  goalScorer,
  qualification,
  groupStandings,
  knockoutBracket,
  playerMilestone,
}

enum ShareEntityType { match, player, guestPlayer, team, tournament, lineup }

class SharePayload {
  static const int currentSchemaVersion = 1;

  static const Set<String> _allowedJsonKeys = {
    'cardType',
    'entityType',
    'entityId',
    'tournamentId',
    'matchId',
    'targetUrl',
    'campaignSource',
    'claimUrl',
    'schemaVersion',
  };

  static const Set<String> _forbiddenUrlQueryParameters = {
    'name',
    'displayname',
    'subjectname',
    'phone',
    'email',
    'photo',
    'photourl',
    'avatar',
    'image',
    'imageurl',
  };

  final ShareCardType cardType;
  final ShareEntityType entityType;
  final String entityId;
  final String? tournamentId;
  final String? matchId;
  final Uri targetUrl;
  final String campaignSource;
  final Uri? claimUrl;
  final int schemaVersion;

  factory SharePayload({
    required ShareCardType cardType,
    required ShareEntityType entityType,
    required String entityId,
    String? tournamentId,
    String? matchId,
    required Uri targetUrl,
    required String campaignSource,
    Uri? claimUrl,
    int schemaVersion = currentSchemaVersion,
  }) {
    _assertSupportedSchemaVersion(schemaVersion);
    return SharePayload._(
      cardType: cardType,
      entityType: entityType,
      entityId: _requiredIdentifier(entityId, 'entityId'),
      tournamentId: _optionalIdentifier(tournamentId),
      matchId: _optionalIdentifier(matchId),
      targetUrl: _safeHttpsUrl(targetUrl, 'targetUrl'),
      campaignSource: _campaignSource(campaignSource),
      claimUrl: claimUrl == null ? null : _safeHttpsUrl(claimUrl, 'claimUrl'),
      schemaVersion: schemaVersion,
    );
  }

  const SharePayload._({
    required this.cardType,
    required this.entityType,
    required this.entityId,
    required this.tournamentId,
    required this.matchId,
    required this.targetUrl,
    required this.campaignSource,
    required this.claimUrl,
    required this.schemaVersion,
  });

  Map<String, Object> toJson() {
    return {
      ...analyticsParameters,
      'targetUrl': targetUrl.toString(),
      if (claimUrl case final Uri claimUrl) 'claimUrl': claimUrl.toString(),
    };
  }

  Map<String, Object> get analyticsParameters {
    return {
      'cardType': cardType.name,
      'entityType': entityType.name,
      'entityId': entityId,
      if (tournamentId case final String tournamentId)
        'tournamentId': tournamentId,
      if (matchId case final String matchId) 'matchId': matchId,
      'campaignSource': campaignSource,
      'schemaVersion': schemaVersion,
    };
  }

  SharePayload withClaimUrl(Uri claimUrl) {
    return SharePayload(
      cardType: cardType,
      entityType: entityType,
      entityId: entityId,
      tournamentId: tournamentId,
      matchId: matchId,
      targetUrl: targetUrl,
      campaignSource: campaignSource,
      claimUrl: claimUrl,
      schemaVersion: schemaVersion,
    );
  }

  factory SharePayload.fromJson(Map<String, dynamic> json) {
    _assertAllowedKeys(json);
    final schemaVersion = _jsonInt(json, 'schemaVersion');
    return SharePayload(
      cardType: _cardType(_jsonString(json, 'cardType')),
      entityType: _entityType(_jsonString(json, 'entityType')),
      entityId: _jsonString(json, 'entityId'),
      tournamentId: _jsonOptionalString(json, 'tournamentId'),
      matchId: _jsonOptionalString(json, 'matchId'),
      targetUrl: _jsonUri(json, 'targetUrl'),
      campaignSource: _jsonString(json, 'campaignSource'),
      claimUrl: _jsonOptionalUri(json, 'claimUrl'),
      schemaVersion: schemaVersion,
    );
  }

  static void _assertAllowedKeys(Map<String, dynamic> json) {
    final unexpectedKeys = json.keys
        .where((key) => !_allowedJsonKeys.contains(key))
        .toList(growable: false);
    if (unexpectedKeys.isNotEmpty) {
      throw FormatException(
        'Share payload contains unsupported fields: ${unexpectedKeys.join(', ')}.',
      );
    }
  }

  static void _assertSupportedSchemaVersion(int schemaVersion) {
    if (schemaVersion != currentSchemaVersion) {
      throw UnsupportedError(
        'Unsupported share payload schema version: $schemaVersion.',
      );
    }
  }

  static ShareCardType _cardType(String rawValue) {
    for (final cardType in ShareCardType.values) {
      if (cardType.name == rawValue) return cardType;
    }
    throw FormatException('Unsupported share card type: $rawValue.');
  }

  static ShareEntityType _entityType(String rawValue) {
    for (final entityType in ShareEntityType.values) {
      if (entityType.name == rawValue) return entityType;
    }
    throw FormatException('Unsupported share entity type: $rawValue.');
  }

  static String _requiredIdentifier(String rawValue, String fieldName) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(rawValue, fieldName, 'Must not be empty.');
    }
    return value;
  }

  static String? _optionalIdentifier(String? rawValue) {
    final value = rawValue?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _campaignSource(String rawValue) {
    final value = rawValue.trim();
    final pattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
    if (!pattern.hasMatch(value)) {
      throw ArgumentError.value(
        rawValue,
        'campaignSource',
        'Must use lowercase analytics-safe characters.',
      );
    }
    return value;
  }

  static Uri _safeHttpsUrl(Uri uri, String fieldName) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value(
        uri,
        fieldName,
        'Must be an absolute HTTPS URL.',
      );
    }

    final containsPiiParameter = uri.queryParameters.keys.any(
      (parameterName) =>
          _forbiddenUrlQueryParameters.contains(parameterName.toLowerCase()),
    );
    if (containsPiiParameter) {
      throw ArgumentError.value(
        uri,
        fieldName,
        'Must not include personally identifiable query parameters.',
      );
    }
    return uri;
  }

  static int _jsonInt(Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value is int) return value;
    throw FormatException('Share payload field $fieldName must be an int.');
  }

  static String _jsonString(Map<String, dynamic> json, String fieldName) {
    final value = json[fieldName];
    if (value is String) return value;
    throw FormatException('Share payload field $fieldName must be a string.');
  }

  static String? _jsonOptionalString(
    Map<String, dynamic> json,
    String fieldName,
  ) {
    final value = json[fieldName];
    if (value == null || value is String) return value as String?;
    throw FormatException('Share payload field $fieldName must be a string.');
  }

  static Uri _jsonUri(Map<String, dynamic> json, String fieldName) {
    return _parseUri(_jsonString(json, fieldName), fieldName);
  }

  static Uri? _jsonOptionalUri(Map<String, dynamic> json, String fieldName) {
    final value = _jsonOptionalString(json, fieldName);
    return value == null ? null : _parseUri(value, fieldName);
  }

  static Uri _parseUri(String rawValue, String fieldName) {
    final uri = Uri.tryParse(rawValue);
    if (uri == null) {
      throw FormatException('Share payload field $fieldName must be a URL.');
    }
    return uri;
  }
}
