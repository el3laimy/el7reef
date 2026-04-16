import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/enums/tournament_registration_mode.dart';
import '../../../core/services/tournament_registration_service.dart';
import '../../../domain/entities/guest_team.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';

class TournamentGuestTeamCreateController extends GetxController {
  final AuthSession _authSession;
  final TournamentRepository _tournamentRepository;
  final GuestTeamRepository _guestTeamRepository;
  final TournamentRegistrationService _registrationService;

  TournamentGuestTeamCreateController({
    required AuthSession authSession,
    required TournamentRepository tournamentRepository,
    required GuestTeamRepository guestTeamRepository,
    required TournamentRegistrationService registrationService,
  })  : _authSession = authSession,
        _tournamentRepository = tournamentRepository,
        _guestTeamRepository = guestTeamRepository,
        _registrationService = registrationService;

  final formKey = GlobalKey<FormState>();
  final teamNameController = TextEditingController();
  final contactNameController = TextEditingController();
  final contactPhoneController = TextEditingController();

  final tournament = Rxn<Tournament>();
  final selectedMode = TournamentRegistrationMode.quick.obs;
  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  String? get tournamentId => Get.parameters['id'];
  String? get currentUserId => _authSession.currentUserId;
  bool get isOrganizer => tournament.value?.organizerId == currentUserId;

  @override
  void onInit() {
    super.onInit();
    loadTournament();
  }

  Future<void> loadTournament() async {
    final id = tournamentId;
    if (id == null || id.isEmpty) {
      errorMessage.value = 'لم يتم تحديد البطولة المطلوبة.';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final loadedTournament = await _tournamentRepository.getTournament(id);
      if (loadedTournament == null) {
        errorMessage.value = 'تعذر العثور على البطولة المطلوبة.';
      } else {
        tournament.value = loadedTournament;
      }
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isLoading.value = false;
    }
  }

  void selectMode(TournamentRegistrationMode? mode) {
    if (mode != null) {
      selectedMode.value = mode;
    }
  }

  Future<void> submit() async {
    final userId = currentUserId;
    final loadedTournament = tournament.value;
    if (!formKey.currentState!.validate()) {
      return;
    }
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'سجّل الدخول أولًا حتى تتمكن من إنشاء فريق ضيف.';
      return;
    }
    if (loadedTournament == null) {
      errorMessage.value = 'تعذر تحميل البطولة المطلوبة.';
      return;
    }
    if (!isOrganizer) {
      errorMessage.value = 'هذه الشاشة مخصصة لمنظّم البطولة فقط.';
      return;
    }

    isSubmitting.value = true;
    errorMessage.value = '';
    try {
      final now = DateTime.now();
      final guestTeam = GuestTeam(
        id: const Uuid().v4(),
        name: teamNameController.text.trim(),
        normalizedName: teamNameController.text.trim().toLowerCase(),
        creatorId: userId,
        contactName: _nullableTrim(contactNameController.text),
        contactPhone: _nullableTrim(contactPhoneController.text),
        createdAt: now,
        updatedAt: now,
      );

      await _guestTeamRepository.createGuestTeam(guestTeam);
      final result = await _registrationService.registerGuestTeam(
        tournamentId: loadedTournament.id,
        guestTeamId: guestTeam.id,
        actorId: userId,
        mode: selectedMode.value,
      );

      if (result.outcome == TournamentRegistrationOutcome.pendingApproval) {
        Get.snackbar('تم', 'تم إنشاء الفريق الضيف وهو الآن بانتظار الاعتماد.');
        await Get.offNamed(
          AppRoutes.tournamentRegistrationReviewForTournament(
            loadedTournament.id,
            result.registration.id,
          ),
        );
        return;
      }

      Get.snackbar('تم', 'تم إنشاء الفريق الضيف وتسجيله في البطولة.');
      Get.back(result: true);
    } catch (error) {
      errorMessage.value = _normalizeError(error);
    } finally {
      isSubmitting.value = false;
    }
  }

  String? validateTeamName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'اسم الفريق مطلوب';
    }
    if (trimmed.length < 3) {
      return 'اسم الفريق يجب أن يكون 3 أحرف على الأقل';
    }
    return null;
  }

  String _normalizeError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  String? _nullableTrim(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void onClose() {
    teamNameController.dispose();
    contactNameController.dispose();
    contactPhoneController.dispose();
    super.onClose();
  }
}
