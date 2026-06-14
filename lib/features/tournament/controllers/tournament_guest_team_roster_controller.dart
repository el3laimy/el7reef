import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/enums/guest_claim_status.dart';
import '../../../core/services/guest_team_roster_service.dart';
import '../../../domain/entities/guest_player.dart';
import '../../../domain/entities/guest_team.dart';
import '../../../domain/entities/tournament.dart';
import '../../../domain/repositories/guest_team_repository.dart';
import '../../../domain/repositories/tournament_repository.dart';

class TournamentGuestTeamRosterController extends GetxController {
  final AuthSession _authSession;
  final GuestTeamRepository _guestTeamRepository;
  final TournamentRepository _tournamentRepository;
  final GuestTeamRosterService _rosterService;

  TournamentGuestTeamRosterController({
    required AuthSession authSession,
    required GuestTeamRepository guestTeamRepository,
    required TournamentRepository tournamentRepository,
    required GuestTeamRosterService rosterService,
  }) : _authSession = authSession,
       _guestTeamRepository = guestTeamRepository,
       _tournamentRepository = tournamentRepository,
       _rosterService = rosterService;

  final tournament = Rxn<Tournament>();
  final guestTeam = Rxn<GuestTeam>();
  final players = <GuestPlayer>[].obs;
  final editingPlayer = Rxn<GuestPlayer>();

  final isLoading = true.obs;
  final isSubmitting = false.obs;
  final errorMessage = ''.obs;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final jerseyController = TextEditingController();
  final positionController = TextEditingController();
  final notesController = TextEditingController();

  String? get tournamentId => Get.parameters['id'];
  String? get guestTeamId => Get.parameters['guestTeamId'];
  String? get actorId => _authSession.currentUserId;

  List<GuestPlayer> get activePlayers => players
      .where((player) => player.claimStatus != GuestClaimStatus.archived)
      .toList(growable: false);

  List<GuestPlayer> get archivedPlayers => players
      .where((player) => player.claimStatus == GuestClaimStatus.archived)
      .toList(growable: false);

  GuestPlayer? get captain {
    final captainId = guestTeam.value?.captainGuestPlayerId;
    if (captainId == null || captainId.isEmpty) {
      return null;
    }
    return players.firstWhereOrNull((player) => player.id == captainId);
  }

  bool isCaptain(GuestPlayer player) {
    return guestTeam.value?.captainGuestPlayerId == player.id;
  }

  @override
  void onInit() {
    super.onInit();
    loadRoster();
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    jerseyController.dispose();
    positionController.dispose();
    notesController.dispose();
    super.onClose();
  }

  Future<void> loadRoster() async {
    final targetTournamentId = tournamentId;
    final targetGuestTeamId = guestTeamId;
    final currentActorId = actorId;
    if (targetTournamentId == null || targetTournamentId.isEmpty) {
      errorMessage.value = 'لم يتم تحديد البطولة المطلوبة.';
      isLoading.value = false;
      return;
    }
    if (targetGuestTeamId == null || targetGuestTeamId.isEmpty) {
      errorMessage.value = 'لم يتم تحديد الفريق الضيف المطلوب.';
      isLoading.value = false;
      return;
    }
    if (currentActorId == null || currentActorId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول لإدارة لاعبي الفريق الضيف.';
      isLoading.value = false;
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final loadedTournament = await _tournamentRepository.getTournament(
        targetTournamentId,
      );
      final loadedGuestTeam = await _guestTeamRepository.getGuestTeam(
        targetGuestTeamId,
      );
      final loadedPlayers = await _rosterService.getGuestRoster(
        tournamentId: targetTournamentId,
        guestTeamId: targetGuestTeamId,
        actorId: currentActorId,
      );

      tournament.value = loadedTournament;
      guestTeam.value = loadedGuestTeam;
      players.assignAll(_sortPlayers(loadedPlayers));
    } catch (error) {
      errorMessage.value = _readableError(error);
    } finally {
      isLoading.value = false;
    }
  }

  void startCreate() {
    editingPlayer.value = null;
    _clearForm();
  }

  void startEdit(GuestPlayer player) {
    editingPlayer.value = player;
    nameController.text = player.displayName;
    phoneController.text = player.phoneNumber ?? '';
    jerseyController.text = player.jerseyNumber?.toString() ?? '';
    positionController.text = player.preferredPosition ?? '';
    notesController.text = player.notes ?? '';
  }

  Future<void> submitPlayerForm() async {
    final targetTournamentId = tournamentId;
    final targetGuestTeamId = guestTeamId;
    final currentActorId = actorId;
    if (targetTournamentId == null ||
        targetGuestTeamId == null ||
        currentActorId == null) {
      Get.snackbar('خطأ', 'يجب تسجيل الدخول وتحديد الفريق قبل الحفظ.');
      return;
    }

    final displayName = nameController.text.trim();
    if (displayName.isEmpty) {
      Get.snackbar('خطأ', 'اسم اللاعب الضيف مطلوب.');
      return;
    }

    final jerseyNumber = _parseJerseyNumber();
    if (jerseyController.text.trim().isNotEmpty && jerseyNumber == null) {
      Get.snackbar('خطأ', 'رقم القميص يجب أن يكون رقمًا صحيحًا.');
      return;
    }

    try {
      isSubmitting.value = true;
      final currentEditingPlayer = editingPlayer.value;
      if (currentEditingPlayer == null) {
        await _rosterService.createGuestPlayer(
          tournamentId: targetTournamentId,
          guestTeamId: targetGuestTeamId,
          actorId: currentActorId,
          displayName: displayName,
          phoneNumber: phoneController.text,
          jerseyNumber: jerseyNumber,
          preferredPosition: positionController.text,
          notes: notesController.text,
        );
        Get.back();
        Get.snackbar('تم', 'تمت إضافة اللاعب الضيف.');
      } else {
        await _rosterService.updateGuestPlayer(
          tournamentId: targetTournamentId,
          guestTeamId: targetGuestTeamId,
          actorId: currentActorId,
          guestPlayerId: currentEditingPlayer.id,
          displayName: displayName,
          phoneNumber: phoneController.text,
          jerseyNumber: jerseyNumber,
          preferredPosition: positionController.text,
          notes: notesController.text,
        );
        Get.back();
        Get.snackbar('تم', 'تم تحديث بيانات اللاعب الضيف.');
      }
      _clearForm();
      await loadRoster();
    } catch (error) {
      Get.snackbar('خطأ', _readableError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> setCaptain(GuestPlayer player) async {
    final targetTournamentId = tournamentId;
    final targetGuestTeamId = guestTeamId;
    final currentActorId = actorId;
    if (targetTournamentId == null ||
        targetGuestTeamId == null ||
        currentActorId == null) {
      return;
    }
    try {
      isSubmitting.value = true;
      final updatedTeam = await _rosterService.setCaptain(
        tournamentId: targetTournamentId,
        guestTeamId: targetGuestTeamId,
        actorId: currentActorId,
        guestPlayerId: player.id,
      );
      guestTeam.value = updatedTeam;
      await loadRoster();
      Get.snackbar('تم', 'تم تعيين ${player.displayName} قائدًا للفريق.');
    } catch (error) {
      Get.snackbar('خطأ', _readableError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> archivePlayer(GuestPlayer player) async {
    final targetTournamentId = tournamentId;
    final targetGuestTeamId = guestTeamId;
    final currentActorId = actorId;
    if (targetTournamentId == null ||
        targetGuestTeamId == null ||
        currentActorId == null) {
      return;
    }
    try {
      isSubmitting.value = true;
      await _rosterService.archiveGuestPlayer(
        tournamentId: targetTournamentId,
        guestTeamId: targetGuestTeamId,
        actorId: currentActorId,
        guestPlayerId: player.id,
      );
      await loadRoster();
      Get.snackbar('تم', 'تمت أرشفة ${player.displayName}.');
    } catch (error) {
      Get.snackbar('خطأ', _readableError(error));
    } finally {
      isSubmitting.value = false;
    }
  }

  int? _parseJerseyNumber() {
    final raw = jerseyController.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  void _clearForm() {
    nameController.clear();
    phoneController.clear();
    jerseyController.clear();
    positionController.clear();
    notesController.clear();
  }

  List<GuestPlayer> _sortPlayers(List<GuestPlayer> entries) {
    final sorted = List<GuestPlayer>.from(entries)
      ..sort((left, right) {
        final leftArchived = left.claimStatus == GuestClaimStatus.archived;
        final rightArchived = right.claimStatus == GuestClaimStatus.archived;
        if (leftArchived != rightArchived) {
          return leftArchived ? 1 : -1;
        }
        final leftCaptain = isCaptain(left);
        final rightCaptain = isCaptain(right);
        if (leftCaptain != rightCaptain) {
          return leftCaptain ? -1 : 1;
        }
        final leftNumber = left.jerseyNumber ?? 999;
        final rightNumber = right.jerseyNumber ?? 999;
        if (leftNumber != rightNumber) {
          return leftNumber.compareTo(rightNumber);
        }
        return left.displayName.compareTo(right.displayName);
      });
    return sorted;
  }

  String _readableError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }
}
