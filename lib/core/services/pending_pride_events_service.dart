import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/participant_ref_model.dart';
import '../../domain/entities/participant_ref.dart';
import '../constants/firebase_paths.dart';

class PendingPrideGoalDraft {
  final String sideKey;
  final ParticipantRef actor;
  final int goals;
  final int? minute;

  const PendingPrideGoalDraft({
    required this.sideKey,
    required this.actor,
    required this.goals,
    this.minute,
  });
}

class PendingPrideMvpDraft {
  final String sideKey;
  final ParticipantRef actor;

  const PendingPrideMvpDraft({required this.sideKey, required this.actor});
}

class PendingPrideEventsPayload {
  static const int currentVersion = 1;

  final int version;
  final String matchId;
  final int scoreTeamA;
  final int scoreTeamB;
  final List<PendingPrideGoalDraft> goals;
  final PendingPrideMvpDraft? mvp;
  final String createdBy;
  final DateTime createdAt;

  const PendingPrideEventsPayload({
    this.version = currentVersion,
    required this.matchId,
    required this.scoreTeamA,
    required this.scoreTeamB,
    required this.goals,
    required this.createdBy,
    required this.createdAt,
    this.mvp,
  });
}

class PendingPrideEventsService {
  static const String collectionName = 'pendingPrideEvents';
  static const String currentDocumentId = 'current';

  final FirebaseFirestore _firestore;

  PendingPrideEventsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _payloadRef(String matchId) {
    return _firestore
        .collection(FirebasePaths.matches)
        .doc(matchId)
        .collection(collectionName)
        .doc(currentDocumentId);
  }

  Future<void> savePayload(PendingPrideEventsPayload payload) {
    return _payloadRef(payload.matchId).set(_toJson(payload));
  }

  Future<PendingPrideEventsPayload?> loadPayload(String matchId) async {
    final snapshot = await _payloadRef(matchId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return _fromJson(data);
  }

  Future<void> clearPayload(String matchId) {
    return _payloadRef(matchId).delete();
  }

  Map<String, dynamic> _toJson(PendingPrideEventsPayload payload) {
    return {
      'version': payload.version,
      'matchId': payload.matchId,
      'scoreTeamA': payload.scoreTeamA,
      'scoreTeamB': payload.scoreTeamB,
      'goals': payload.goals.map(_goalToJson).toList(growable: false),
      'mvp': payload.mvp == null ? null : _mvpToJson(payload.mvp!),
      'createdBy': payload.createdBy,
      'createdAt': payload.createdAt.millisecondsSinceEpoch,
    };
  }

  PendingPrideEventsPayload _fromJson(Map<String, dynamic> json) {
    return PendingPrideEventsPayload(
      version: (json['version'] as num?)?.toInt() ?? 1,
      matchId: json['matchId'] as String? ?? '',
      scoreTeamA: (json['scoreTeamA'] as num?)?.toInt() ?? 0,
      scoreTeamB: (json['scoreTeamB'] as num?)?.toInt() ?? 0,
      goals: (json['goals'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((item) => _goalFromJson(Map<String, dynamic>.from(item)))
          .whereType<PendingPrideGoalDraft>()
          .toList(growable: false),
      mvp: json['mvp'] is Map
          ? _mvpFromJson(Map<String, dynamic>.from(json['mvp'] as Map))
          : null,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> _goalToJson(PendingPrideGoalDraft draft) {
    return {
      'sideKey': draft.sideKey,
      'actor': ParticipantRefModel.fromEntity(draft.actor).toJson(),
      'goals': draft.goals,
      'minute': draft.minute,
    };
  }

  PendingPrideGoalDraft? _goalFromJson(Map<String, dynamic> json) {
    final actor = _actorFromJson(json['actor']);
    final sideKey = json['sideKey'] as String?;
    final goals = (json['goals'] as num?)?.toInt();
    if (actor == null || sideKey == null || sideKey.isEmpty || goals == null) {
      return null;
    }
    return PendingPrideGoalDraft(
      sideKey: sideKey,
      actor: actor,
      goals: goals,
      minute: (json['minute'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> _mvpToJson(PendingPrideMvpDraft draft) {
    return {
      'sideKey': draft.sideKey,
      'actor': ParticipantRefModel.fromEntity(draft.actor).toJson(),
    };
  }

  PendingPrideMvpDraft? _mvpFromJson(Map<String, dynamic> json) {
    final actor = _actorFromJson(json['actor']);
    final sideKey = json['sideKey'] as String?;
    if (actor == null || sideKey == null || sideKey.isEmpty) {
      return null;
    }
    return PendingPrideMvpDraft(sideKey: sideKey, actor: actor);
  }

  ParticipantRef? _actorFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ParticipantRefModel.fromJson(
        Map<String, dynamic>.from(value),
      ).toEntity();
    } on FormatException {
      return null;
    }
  }
}
