import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../constants/firebase_paths.dart';
import '../../domain/entities/share_payload.dart';
import '../../features/shareables/models/pride_export.dart';
import '../utils/app_logger.dart';

class AnalyticsService {
  static const String prideCardViewedEvent = 'pride_card_viewed';
  static const String shareStartedEvent = 'share_started';
  static const String shareSheetReturnedEvent = 'share_sheet_returned';
  static const String prideExportFinishedEvent = 'pride_export_finished';
  static const String shareLinkOpenedEvent = 'share_link_opened';
  static const String claimStartedFromCardEvent = 'claim_started_from_card';
  static const String claimCompletedFromCardEvent = 'claim_completed_from_card';

  final FirebaseFirestore? _firestore;
  final Uuid _uuid;

  AnalyticsService({FirebaseFirestore? firestore, Uuid? uuid})
    : _firestore = firestore ?? _resolveFirestoreIfAvailable(),
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
      if (value == null || value is String || value is num || value is bool) {
        sanitizedParameters[entry.key] = value;
      } else {
        sanitizedParameters[entry.key] = value.toString();
      }
    }

    final eventData = <String, dynamic>{
      'eventName': eventName,
      'parameters': sanitizedParameters,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    final actorId = sanitizedParameters['actorId'];
    if (actorId is String && actorId.isNotEmpty) {
      eventData['actorId'] = actorId;
    }

    try {
      await firestore
          .collection(FirebasePaths.analyticsEvents)
          .doc(_uuid.v4())
          .set(eventData);
    } on FirebaseException catch (error) {
      developer.log(
        'Analytics persistence skipped: ${error.code}',
        name: 'AnalyticsService',
        error: error,
      );
    }
  }

  static FirebaseFirestore? _resolveFirestoreIfAvailable() {
    try {
      Firebase.app();
      return FirebaseFirestore.instance;
    } catch (error) {
      AppLogger.info('AnalyticsService.resolveFirestoreIfAvailable', error);
      return null;
    }
  }

  void trackInviteSent({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent(
      'invite_sent',
      parameters: {'type': type, 'targetId': targetId, 'actorId': actorId},
    );
  }

  void trackClaimOpen({required String type, required String targetId}) {
    trackEvent('claim_open', parameters: {'type': type, 'targetId': targetId});
  }

  void trackClaimCompletion({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent(
      'claim_completion',
      parameters: {'type': type, 'targetId': targetId, 'actorId': actorId},
    );
  }

  void trackJoinCompletion({
    required String type,
    required String targetId,
    required String actorId,
  }) {
    trackEvent(
      'join_completion',
      parameters: {'type': type, 'targetId': targetId, 'actorId': actorId},
    );
  }

  void trackPrideCardViewed(SharePayload payload) {
    _trackPrideFunnelEvent(prideCardViewedEvent, payload);
  }

  void trackShareStarted(SharePayload payload) {
    _trackPrideFunnelEvent(shareStartedEvent, payload);
  }

  void trackShareSheetReturned(SharePayload payload) {
    _trackPrideFunnelEvent(shareSheetReturnedEvent, payload);
  }

  void trackPrideExportFinished(PrideExportResult result) {
    trackEvent(
      prideExportFinishedEvent,
      parameters: {
        'cardType': result.request.cardType.name,
        'format': result.request.format.name,
        'mediaType': result.request.mediaType.name,
        'exportDurationMs': result.exportDuration.inMilliseconds,
        'fallbackUsed': result.fallbackUsed,
        if (result.failureCode != null) 'failureCode': result.failureCode,
      },
    );
  }

  void trackShareLinkOpened(SharePayload payload) {
    _trackPrideFunnelEvent(shareLinkOpenedEvent, payload);
  }

  void trackClaimStartedFromCard(SharePayload payload) {
    _trackPrideFunnelEvent(claimStartedFromCardEvent, payload);
  }

  void trackClaimCompletedFromCard(SharePayload payload) {
    _trackPrideFunnelEvent(claimCompletedFromCardEvent, payload);
  }

  void _trackPrideFunnelEvent(String eventName, SharePayload payload) {
    trackEvent(eventName, parameters: payload.analyticsParameters);
  }
}
