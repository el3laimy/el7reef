import 'package:uuid/uuid.dart';

import '../../core/enums/audit_action.dart';
import '../../core/enums/dispute_enums.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/dispute.dart';
import '../../domain/repositories/dispute_repository.dart';
import '../../domain/repositories/match_repository.dart';
import 'audit_service.dart';

/// نتيجة فتح نزاع
class DisputeOpenResult {
  final Dispute dispute;
  final bool matchFrozen;

  const DisputeOpenResult({required this.dispute, required this.matchFrozen});
}

/// خدمة إدارة النزاعات — فتح / مراجعة / حل / رفض / تجميد
class DisputeService {
  final DisputeRepository _disputeRepository;
  final MatchRepository _matchRepository;
  final AuditService _auditService;
  final Uuid _uuid;

  /// المهلة الافتراضية للنزاع (24 ساعة)
  static const Duration defaultDeadline = Duration(hours: 24);

  DisputeService({
    required DisputeRepository disputeRepository,
    required MatchRepository matchRepository,
    required AuditService auditService,
    Uuid? uuid,
  })  : _disputeRepository = disputeRepository,
        _matchRepository = matchRepository,
        _auditService = auditService,
        _uuid = uuid ?? const Uuid();

  /// ── فتح نزاع جديد ──
  /// يُجمّد المباراة تلقائياً إذا كان النزاع على النتيجة
  Future<DisputeOpenResult> openDispute({
    required String matchId,
    String? tournamentId,
    required DisputeType type,
    required String raisedBy,
    required String description,
    List<String> evidenceUrls = const [],
    Duration? deadlineDuration,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    final deadline = createdAt.add(deadlineDuration ?? defaultDeadline);

    // التحقق من عدم وجود نزاع مفتوح على نفس المباراة من نفس النوع
    final existingDisputes = await _disputeRepository.getMatchDisputes(matchId);
    final hasOpenSameType = existingDisputes.any(
      (d) => d.type == type && d.isOpen,
    );
    if (hasOpenSameType) {
      throw Exception('يوجد نزاع مفتوح بالفعل من نفس النوع على هذه المباراة.');
    }

    final dispute = Dispute(
      id: _uuid.v4(),
      matchId: matchId,
      tournamentId: tournamentId,
      type: type,
      status: DisputeStatus.open,
      raisedBy: raisedBy,
      description: description,
      evidenceUrls: evidenceUrls,
      createdAt: createdAt,
      deadline: deadline,
    );

    await _disputeRepository.createDispute(dispute);

    // تجميد المباراة تلقائياً إذا كان النزاع على النتيجة
    bool matchFrozen = false;
    if (type == DisputeType.scoreDispute) {
      await _matchRepository.freezeMatch(matchId);
      matchFrozen = true;

      await _recordAuditSafely(
        context: 'DisputeService.openDispute.freezeAudit',
        operation: () => _auditService.recordMatchEvent(
          matchId: matchId,
          action: AuditAction.disputeFrozenMatch,
          actorId: raisedBy,
          metadata: {'disputeId': dispute.id, 'reason': description},
          now: createdAt,
        ),
      );
    }

    await _recordAuditSafely(
      context: 'DisputeService.openDispute.disputeAudit',
      operation: () => _auditService.recordDisputeEvent(
        disputeId: dispute.id,
        action: AuditAction.disputeOpened,
        actorId: raisedBy,
        metadata: {
          'matchId': matchId,
          'type': type.name,
          'description': description,
        },
        now: createdAt,
      ),
    );

    return DisputeOpenResult(dispute: dispute, matchFrozen: matchFrozen);
  }

  /// ── حل النزاع ──
  Future<Dispute> resolveDispute({
    required String disputeId,
    required String resolvedBy,
    required String resolutionNote,
    bool unfreezeMatch = true,
    DateTime? now,
  }) async {
    final resolvedAt = now ?? DateTime.now();
    final existing = await _disputeRepository.getDispute(disputeId);
    if (existing == null) {
      throw Exception('النزاع غير موجود.');
    }
    if (!existing.isOpen) {
      throw Exception('النزاع مغلق بالفعل ولا يمكن تعديله.');
    }

    final resolved = existing.copyWith(
      status: DisputeStatus.resolved,
      resolvedBy: resolvedBy,
      resolutionNote: resolutionNote,
      resolvedAt: resolvedAt,
    );

    await _disputeRepository.updateDispute(resolved);

    // رفع التجميد عن المباراة إذا مطلوب
    if (unfreezeMatch && existing.type == DisputeType.scoreDispute) {
      await _matchRepository.unfreezeMatch(existing.matchId);
      await _recordAuditSafely(
        context: 'DisputeService.resolveDispute.unfreezeAudit',
        operation: () => _auditService.recordMatchEvent(
          matchId: existing.matchId,
          action: AuditAction.matchUnfrozen,
          actorId: resolvedBy,
          metadata: {'disputeId': disputeId},
          now: resolvedAt,
        ),
      );
    }

    await _recordAuditSafely(
      context: 'DisputeService.resolveDispute.disputeAudit',
      operation: () => _auditService.recordDisputeEvent(
        disputeId: disputeId,
        action: AuditAction.disputeResolved,
        actorId: resolvedBy,
        metadata: {
          'matchId': existing.matchId,
          'resolutionNote': resolutionNote,
          'unfrozen': unfreezeMatch,
        },
        now: resolvedAt,
      ),
    );

    return resolved;
  }

  /// ── رفض النزاع ──
  Future<Dispute> rejectDispute({
    required String disputeId,
    required String rejectedBy,
    required String rejectionNote,
    bool unfreezeMatch = true,
    DateTime? now,
  }) async {
    final rejectedAt = now ?? DateTime.now();
    final existing = await _disputeRepository.getDispute(disputeId);
    if (existing == null) {
      throw Exception('النزاع غير موجود.');
    }
    if (!existing.isOpen) {
      throw Exception('النزاع مغلق بالفعل.');
    }

    final rejected = existing.copyWith(
      status: DisputeStatus.rejected,
      resolvedBy: rejectedBy,
      resolutionNote: rejectionNote,
      resolvedAt: rejectedAt,
    );

    await _disputeRepository.updateDispute(rejected);

    if (unfreezeMatch && existing.type == DisputeType.scoreDispute) {
      await _matchRepository.unfreezeMatch(existing.matchId);
      await _recordAuditSafely(
        context: 'DisputeService.rejectDispute.unfreezeAudit',
        operation: () => _auditService.recordMatchEvent(
          matchId: existing.matchId,
          action: AuditAction.matchUnfrozen,
          actorId: rejectedBy,
          metadata: {'disputeId': disputeId},
          now: rejectedAt,
        ),
      );
    }

    await _recordAuditSafely(
      context: 'DisputeService.rejectDispute.disputeAudit',
      operation: () => _auditService.recordDisputeEvent(
        disputeId: disputeId,
        action: AuditAction.disputeRejected,
        actorId: rejectedBy,
        metadata: {
          'matchId': existing.matchId,
          'rejectionNote': rejectionNote,
        },
        now: rejectedAt,
      ),
    );

    return rejected;
  }

  Future<void> _recordAuditSafely({
    required String context,
    required Future<void> Function() operation,
  }) async {
    try {
      await operation();
    } catch (error, stackTrace) {
      AppLogger.warning(context, error);
      AppLogger.error(context, error, stackTrace);
    }
  }

  /// ── التحقق من انتهاء مهلة النزاعات المفتوحة ──
  Future<List<Dispute>> expireOverdueDisputes({
    required String matchId,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final disputes = await _disputeRepository.getMatchDisputes(matchId);
    final expired = <Dispute>[];

    for (final dispute in disputes) {
      if (dispute.hasExpired(currentTime)) {
        final expiredDispute = dispute.copyWith(
          status: DisputeStatus.expired,
          resolvedAt: currentTime,
          resolutionNote: 'انتهت المهلة بدون حل.',
        );
        await _disputeRepository.updateDispute(expiredDispute);
        expired.add(expiredDispute);
      }
    }

    return expired;
  }

  // ── Query Helpers ──

  Future<List<Dispute>> getMatchDisputes(String matchId) {
    return _disputeRepository.getMatchDisputes(matchId);
  }

  Future<List<Dispute>> getTournamentDisputes(String tournamentId) {
    return _disputeRepository.getTournamentDisputes(tournamentId);
  }
}
