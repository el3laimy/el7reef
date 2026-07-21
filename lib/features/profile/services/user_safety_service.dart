import '../../../core/auth/auth_service.dart';
import '../../../core/services/cloud_sensitive_ops_service.dart';
import '../../../domain/entities/participant_ref.dart';
import '../models/public_player_profile_data.dart';

enum UserReportReason {
  harassment('harassment', 'مضايقة أو تنمر'),
  impersonation('impersonation', 'انتحال شخصية'),
  inappropriate('inappropriate', 'محتوى غير لائق'),
  spam('spam', 'رسائل أو بيانات مزعجة'),
  other('other', 'سبب آخر');

  final String value;
  final String label;

  const UserReportReason(this.value, this.label);
}

class UserSafetyService {
  final AuthService _authService;
  final CloudSensitiveOpsService _cloudService;

  UserSafetyService({
    required AuthService authService,
    CloudSensitiveOpsService? cloudService,
  }) : _authService = authService,
       _cloudService = cloudService ?? CloudSensitiveOpsService();

  String? get currentUserId => _authService.currentUserId;

  bool canReport(PublicPlayerProfileData profile) {
    final userId = currentUserId;
    if (userId == null) return false;
    return profile.kind != ParticipantRefKind.player || profile.id != userId;
  }

  bool canBlock(PublicPlayerProfileData profile) {
    return currentUserId != null &&
        profile.kind == ParticipantRefKind.player &&
        profile.id != currentUserId;
  }

  Future<bool> reportProfile({
    required PublicPlayerProfileData profile,
    required UserReportReason reason,
    String details = '',
  }) {
    return _cloudService.reportUserContent(
      targetKind: profile.kind == ParticipantRefKind.player
          ? 'registeredPlayer'
          : 'guestPlayer',
      targetId: profile.id,
      reason: reason.value,
      details: details.trim(),
    );
  }

  Future<bool> blockPlayer(PublicPlayerProfileData profile) {
    if (!canBlock(profile)) return Future.value(false);
    return _cloudService.blockUser(profile.id);
  }
}
