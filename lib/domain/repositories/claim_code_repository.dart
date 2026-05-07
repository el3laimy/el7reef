import '../../core/enums/claim_target_type.dart';
import '../entities/claim_code.dart';

abstract class ClaimCodeRepository {
  Future<ClaimCode?> getClaimCode(String code);
  Future<void> createClaimCode(ClaimCode claimCode);
  Future<void> updateClaimCode(ClaimCode claimCode);
  Future<ClaimCode?> getActiveClaimCodeForTarget({
    required ClaimTargetType targetType,
    required String targetId,
    String? createdBy,
    String? tournamentId,
  });
}
