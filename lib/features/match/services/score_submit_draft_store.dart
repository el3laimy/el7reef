import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/score_submit_draft.dart';

abstract interface class ScoreSubmitDraftStore {
  Future<ScoreSubmitDraft?> load(String matchId);

  Future<void> save(ScoreSubmitDraft draft);

  Future<void> clear(String matchId);
}

class SharedPreferencesScoreSubmitDraftStore implements ScoreSubmitDraftStore {
  static const _keyPrefix = 'score_submit_draft_v1_';

  final Future<SharedPreferences> Function() _preferencesLoader;

  SharedPreferencesScoreSubmitDraftStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  @override
  Future<ScoreSubmitDraft?> load(String matchId) async {
    final preferences = await _preferencesLoader();
    final encoded = preferences.getString(_key(matchId));
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return ScoreSubmitDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      await preferences.remove(_key(matchId));
      return null;
    }
  }

  @override
  Future<void> save(ScoreSubmitDraft draft) async {
    final preferences = await _preferencesLoader();
    await preferences.setString(
      _key(draft.matchId),
      jsonEncode(draft.toJson()),
    );
  }

  @override
  Future<void> clear(String matchId) async {
    final preferences = await _preferencesLoader();
    await preferences.remove(_key(matchId));
  }

  String _key(String matchId) => '$_keyPrefix$matchId';
}
