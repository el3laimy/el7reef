import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/tournament_registration_status.dart';
import '../../../core/services/tournament_registration_service.dart';
import '../../../domain/entities/guest_team.dart';
import '../../../domain/entities/team.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/entities/tournament_registration.dart';
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/team_repository.dart';
import '../../../domain/repositories/tournament_registration_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';
import '../../../core/services/share_link_service.dart';
import 'package:share_plus/share_plus.dart';

class TournamentRegistrationReviewController extends GetxController {
  final AuthSession _authSession;
  final TournamentRegistrationRepository _registrationRepository;
  final TournamentRepository _tournamentRepository;
  final TeamRepository _teamRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TournamentRegistrationService _registrationService;
  final ShareLinkService _shareLinkService;

  TournamentRegistrationReviewController({
    required AuthSession authSession,
    required TournamentRegistrationRepository registrationRepository,
    required TournamentRepository tournamentRepository,
    required TeamRepository teamRepository,
    required GuestTeamRepository guestTeamRepository,
    required TournamentRegistrationService registrationService,
    required ShareLinkService shareLinkService,
  })  : _authSession = authSession,
        _registrationRepository = registrationRepository,
        _tournamentRepository = tournamentRepository,
        _teamRepository = teamRepository,
        _guestTeamRepository = guestTeamRepository,
        _registrationService = registrationService,
        _shareLinkService = shareLinkService;

  final rejectionNotesController = TextEditingController();

  final tournament = Rxn<Tournament>();
  final registration = Rxn<TournamentRegistration>();
  final team = Rxn<Team>();
  final guestTeam = Rxn<GuestTeam>();

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  String? get tournamentId => Get.parameters['id'];
  String? get registrationId => Get.parameters['registrationId'];
  String? get currentUserId => _authSession.currentUserId;
  bool get isOrganizer => tournament.value?.organizerId == currentUserId;
  bool get canApprove => registration.value?.status != TournamentRegistrationStatus.approved;
  bool get canReject => registration.value?.status == TournamentRegistrationStatus.pending;

  @override
  void onInit() {
    super.onInit();
    loadReview();
  }

  Future<void> loadReview() async {
    final regId = registrationId;
    if (regId == null || regId.isEmpty) {
      errorMessage.value = 'لم يتم تحديد التسجيل المطلوب.';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final loadedRegistration =
          await _registrationRepository.getRegistration(regId);
      if (loadedRegistration == null) {
        errorMessage.value = 'تعذر العثور على التسجيل المطلوب.';
        return;
      }

      final loadedTournament = await _tournamentRepository.getTournament(
        loadedRegistration.tournamentId,
      );
      if (loadedTournament == null) {
        errorMessage.value = 'تعذر العثور على البطولة المرتبطة بهذا التسجيل.';
        return;
      }

      registration.value = loadedRegistration;
      tournament.value = loadedTournament;

      if (loadedRegistration.teamId != null) {
        team.value = await _teamRepository.getTeam(loadedRegistration.teamId!);
        guestTeam.value = null;
      } else if (loadedRegistration.guestTeamId != null) {
        guestTeam.value =
            await _guestTeamRepository.getGuestTeam(loadedRegistration.guestTeamId!);
        team.value = null;
      }

      if (loadedRegistration.notes != null &&
          loadedRegistration.notes!.trim().isNotEmpty) {
        rejectionNotesController.text = loadedRegistration.notes!;
      }
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approve() async {
    final regId = registrationId;
    final userId = currentUserId;
    if (regId == null || regId.isEmpty) {
      errorMessage.value = 'لم يتم تحديد التسجيل المطلوب.';
      return;
    }
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'سجّل الدخول أولًا حتى تتمكن من اعتماد التسجيل.';
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      final result = await _registrationService.approveRegistration(
        registrationId: regId,
        actorId: userId,
      );
      await loadReview();
      Get.snackbar(
        'تم',
        switch (result.outcome) {
          TournamentRegistrationOutcome.approved =>
            'تم اعتماد التسجيل بنجاح.',
          TournamentRegistrationOutcome.alreadyApproved =>
            'هذا التسجيل معتمد بالفعل.',
          _ => 'تم تحديث حالة التسجيل.',
        },
      );
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> reject() async {
    final regId = registrationId;
    final userId = currentUserId;
    if (regId == null || regId.isEmpty) {
      errorMessage.value = 'لم يتم تحديد التسجيل المطلوب.';
      return;
    }
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'سجّل الدخول أولًا حتى تتمكن من رفض التسجيل.';
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      final result = await _registrationService.rejectRegistration(
        registrationId: regId,
        actorId: userId,
        notes: rejectionNotesController.text.trim().isEmpty
            ? null
            : rejectionNotesController.text.trim(),
      );
      await loadReview();
      Get.snackbar(
        'تم',
        switch (result.outcome) {
          TournamentRegistrationOutcome.rejected =>
            'تم رفض التسجيل وحفظ الملاحظات.',
          TournamentRegistrationOutcome.alreadyRejected =>
            'هذا التسجيل مرفوض بالفعل.',
          _ => 'تم تحديث حالة التسجيل.',
        },
      );
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  @override
  void onClose() {
    rejectionNotesController.dispose();
    super.onClose();
  }

  Future<void> shareGuestTeamClaimLink() async {
    final guestTeamId = registration.value?.guestTeamId;
    final actorId = currentUserId;

    if (guestTeamId == null || guestTeamId.isEmpty) {
      Get.snackbar('خطأ', 'الفريق ليس فريق ضيف.');
      return;
    }
    if (actorId == null || actorId.isEmpty) {
      Get.snackbar('خطأ', 'سجّل الدخول أولًا.');
      return;
    }

    try {
      isSubmitting.value = true;
      final shareLink = await _shareLinkService.createGuestTeamClaimLink(
        guestTeamId: guestTeamId,
        actorId: actorId,
      );
      await Share.share(shareLink.shareText);
    } catch (e) {
      Get.snackbar('خطأ', _normalizeError(e));
    } finally {
      isSubmitting.value = false;
    }
  }
}
