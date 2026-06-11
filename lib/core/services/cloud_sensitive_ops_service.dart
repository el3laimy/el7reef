import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../utils/app_logger.dart';

/// بوابة خفيفة لنداءات Cloud Functions الخاصة بالعمليات الحساسة.
///
/// إذا كانت الدالة غير متاحة أو لم يتم نشرها بعد، تُرجع `null` بهدوء
/// كي يستمر المسار المحلي القديم كخطة احتياطية.
class CloudSensitiveOpsService {
  FirebaseFunctions? get _functions {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFunctions.instance;
  }

  Future<bool> recordAuditEvent(Map<String, dynamic> payload) async {
    final result = await _invokeMap(
      functionName: 'recordAuditEvent',
      payload: payload,
    );
    return result != null;
  }

  Future<Map<String, dynamic>?> submitMatchSettlement(
    Map<String, dynamic> payload,
  ) {
    return _invokeMap(functionName: 'submitMatchSettlement', payload: payload);
  }

  Future<Map<String, dynamic>?> approveMatchScore(
    Map<String, dynamic> payload,
  ) {
    return _invokeMap(functionName: 'approveMatchScore', payload: payload);
  }

  Future<Map<String, dynamic>?> applyRatings(Map<String, dynamic> payload) {
    return _invokeMap(functionName: 'applyMatchRatings', payload: payload);
  }

  Future<Map<String, dynamic>?> settleFantasyRound(
    Map<String, dynamic> payload,
  ) {
    return _invokeMap(functionName: 'settleFantasyRound', payload: payload);
  }

  Future<Map<String, dynamic>?> _invokeMap({
    required String functionName,
    required Map<String, dynamic> payload,
  }) async {
    final functions = _functions;
    if (functions == null) {
      return null;
    }

    try {
      final result = await functions.httpsCallable(functionName).call(payload);
      final data = result.data;
      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    } catch (error, stackTrace) {
      AppLogger.warning('CloudSensitiveOpsService.$functionName', error);
      AppLogger.error(
        'CloudSensitiveOpsService.$functionName',
        error,
        stackTrace,
      );
      return null;
    }
  }
}
