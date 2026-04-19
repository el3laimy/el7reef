import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../constants/firebase_paths.dart';

class AnalyticsService {
  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  AnalyticsService({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? _resolveFirestoreIfAvailable(),
        _uuid = uuid ?? const Uuid();

  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    developer.log(
      'Analytics Event: $eventName | params: ${parameters?.toString() ?? "{}"}',
      name: 'AnalyticsService',
    );
    unawaited(_persistEvent(eventName, parameters: parameters));
  }

  Future<void> _persistEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return;
    }

    final sanitizedParameters = <String, dynamic>{};
    for (final entry in (parameters ?? const <String, dynamic>{}).entries) {
      final value = entry.value;
      if (value == null ||
          value is String ||
          value is num ||
          value is bool) {
        sanitizedParameters[entry.key] = value;
      } else {
        sanitizedParameters[entry.key] = value.toString();
      }
    }

    await firestore
        .collection(FirebasePaths.analyticsEvents)
        .doc(_uuid.v4())
        .set({
      'eventName': eventName,
      'actorId': sanitizedParameters['actorId'],
      'parameters': sanitizedParameters,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static FirebaseFirestore? _resolveFirestoreIfAvailable() {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void trackInviteSent({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent('invite_sent', parameters: {
      'type': type,
      'targetId': targetId,
      'actorId': actorId,
    });
  }

  void trackClaimOpen({
    required String type,
    required String targetId,
  }) {
    trackEvent('claim_open', parameters: {
      'type': type,
      'targetId': targetId,
    });
  }

  void trackClaimCompletion({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent('claim_completion', parameters: {
      'type': type,
      'targetId': targetId,
      'actorId': actorId,
    });
  }

  void trackJoinCompletion({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent('join_completion', parameters: {
      'type': type,
      'targetId': targetId,
      'actorId': actorId,
    });
  }
}
