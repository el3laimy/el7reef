import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../utils/app_logger.dart';

/// بوابة خفيفة لنداءات Cloud Functions الخاصة بالعمليات الحساسة.
///
/// قد تعيد `null` لأخطاء التوفر المحددة فقط عندما يسمح المستدعي بذلك.
/// عمليات السلامة تعيد الخطأ ولا تنفذ أي كتابة عميلة بديلة.
class CloudSensitiveOpsService {
  static const Set<String> fallbackableFunctionErrorCodes = {
    'unavailable',
    'deadline-exceeded',
  };

  static bool shouldFallbackForFunctionCode(String code) {
    return fallbackableFunctionErrorCodes.contains(code);
  }

  FirebaseFunctions? get _functions {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFunctions.instance;
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

  Future<Map<String, dynamic>> issueGuestClaimCode({
    required String targetType,
    required String targetId,
    required String requestId,
    required int ttlMs,
    required bool requiresApproval,
  }) {
    return _invokeRequiredMap(
      functionName: 'issueGuestClaimCode',
      payload: {
        'targetType': targetType,
        'targetId': targetId,
        'requestId': requestId,
        'ttlMs': ttlMs,
        'requiresApproval': requiresApproval,
      },
    );
  }

  Future<Map<String, dynamic>> inspectGuestClaim({required String claimCode}) {
    return _invokeRequiredMap(
      functionName: 'inspectGuestClaim',
      payload: {'claimCode': claimCode},
    );
  }

  Future<Map<String, dynamic>> claimGuestPlayer({required String claimCode}) {
    return _invokeRequiredMap(
      functionName: 'claimGuestPlayer',
      payload: {'claimCode': claimCode},
    );
  }

  Future<Map<String, dynamic>> claimGuestTeam({
    required String claimCode,
    required String teamId,
  }) {
    return _invokeRequiredMap(
      functionName: 'claimGuestTeam',
      payload: {'claimCode': claimCode, 'teamId': teamId},
    );
  }

  Future<bool> deleteAccountData() async {
    final result = await _invokeMap(
      functionName: 'deleteAccountData',
      allowAvailabilityFallback: false,
      payload: const <String, dynamic>{},
    );
    return result?['accepted'] == true || result?['deleted'] == true;
  }

  Future<bool> reportUserContent({
    required String targetKind,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    final result = await _invokeMap(
      functionName: 'reportUserContent',
      allowAvailabilityFallback: false,
      payload: {
        'targetKind': targetKind,
        'targetId': targetId,
        'reason': reason,
        'details': details,
      },
    );
    return result?['accepted'] == true;
  }

  Future<bool> blockUser(String blockedId) async {
    final result = await _invokeMap(
      functionName: 'blockUser',
      allowAvailabilityFallback: false,
      payload: {'blockedId': blockedId},
    );
    return result?['blocked'] == true;
  }

  Future<bool> unblockUser(String blockedId) async {
    final result = await _invokeMap(
      functionName: 'unblockUser',
      allowAvailabilityFallback: false,
      payload: {'blockedId': blockedId},
    );
    return result?['unblocked'] == true;
  }

  Future<Map<String, dynamic>> _invokeRequiredMap({
    required String functionName,
    required Map<String, dynamic> payload,
  }) async {
    final result = await _invokeMap(
      functionName: functionName,
      payload: payload,
      allowAvailabilityFallback: false,
    );
    if (result == null) {
      throw StateError(
        'Cloud Function $functionName is unavailable; the sensitive '
        'operation was not executed.',
      );
    }
    return result;
  }

  Future<Map<String, dynamic>?> _invokeMap({
    required String functionName,
    required Map<String, dynamic> payload,
    bool allowAvailabilityFallback = true,
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
    } on FirebaseFunctionsException catch (error, stackTrace) {
      AppLogger.warning('CloudSensitiveOpsService.$functionName', error);
      AppLogger.error(
        'CloudSensitiveOpsService.$functionName',
        error,
        stackTrace,
      );
      if (allowAvailabilityFallback &&
          shouldFallbackForFunctionCode(error.code)) {
        return null;
      }
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.warning('CloudSensitiveOpsService.$functionName', error);
      AppLogger.error(
        'CloudSensitiveOpsService.$functionName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}
