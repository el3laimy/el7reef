import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/enums/tournament_enums.dart';
import '../../../../core/utils/app_logger.dart';
import '../../services/fantasy_lifecycle_service.dart';
import '../../services/fantasy_market_service.dart';
import '../../services/tier_system_engine.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../../domain/entities/fantasy_slot.dart';
import '../../../../domain/entities/fantasy_team.dart';
import '../../../../domain/entities/player_fantasy_value.dart';
import '../../../../features/fantasy/presentation/models/fantasy_market_player.dart';

class FantasyDraftSlot {
  final String key;
  final String requiredPosition;
  final String label;
  final bool isStarting;
  final int benchPriority;
  final FantasyMarketPlayer? selectedPlayer;

  const FantasyDraftSlot({
    required this.key,
    required this.requiredPosition,
    required this.label,
    required this.isStarting,
    required this.benchPriority,
    this.selectedPlayer,
  });

  FantasyDraftSlot copyWith({
    FantasyMarketPlayer? selectedPlayer,
    bool clearPlayer = false,
  }) {
    return FantasyDraftSlot(
      key: key,
      requiredPosition: requiredPosition,
      label: label,
      isStarting: isStarting,
      benchPriority: benchPriority,
      selectedPlayer: clearPlayer
          ? null
          : selectedPlayer ?? this.selectedPlayer,
    );
  }
}

class FantasyCreateTeamController extends GetxController {
  final String leagueId;
  final FantasyRepositoryImpl _fantasyRepository;
  final TournamentRepositoryImpl _tournamentRepository;
  final FantasyMarketService _marketService;
  final FantasyLifecycleService _lifecycleService;
  final AuthSession? _authSession;

  FantasyCreateTeamController({
    required this.leagueId,
    FantasyRepositoryImpl? fantasyRepository,
    TournamentRepositoryImpl? tournamentRepository,
    FantasyMarketService? marketService,
    FantasyLifecycleService? lifecycleService,
    AuthSession? authSession,
  }) : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
       _tournamentRepository =
           tournamentRepository ?? TournamentRepositoryImpl(),
       _marketService =
           marketService ??
           (Get.isRegistered<FantasyMarketService>()
               ? Get.find<FantasyMarketService>()
               : FantasyMarketService()),
       _lifecycleService =
           lifecycleService ??
           (Get.isRegistered<FantasyLifecycleService>()
               ? Get.find<FantasyLifecycleService>()
               : FantasyLifecycleService(
                   lifecycleRepository:
                       Get.isRegistered<FantasyLifecycleRepositoryImpl>()
                       ? Get.find<FantasyLifecycleRepositoryImpl>()
                       : null,
                   tournamentRepository:
                       tournamentRepository ?? TournamentRepositoryImpl(),
                 )),
       _authSession = authSession;

  final TextEditingController teamNameController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString leagueTitle = 'الدوري العالمي'.obs;
  final Rx<TournamentTeamSize> teamSize = TournamentTeamSize.fiveVsFive.obs;
  final Rx<FantasyLeagueLifecycle?> lifecycle = Rx<FantasyLeagueLifecycle?>(
    null,
  );
  final Rx<FantasyTeam?> existingTeam = Rx<FantasyTeam?>(null);
  final RxList<FantasyMarketPlayer> marketPlayers = <FantasyMarketPlayer>[].obs;
  final RxList<FantasyDraftSlot> slots = <FantasyDraftSlot>[].obs;

  bool get canEditDraft => lifecycle.value?.allowsDraftEdits ?? true;

  @override
  void onInit() {
    super.onInit();
    loadDraft();
  }

  @override
  void onClose() {
    teamNameController.dispose();
    super.onClose();
  }

  double get remainingBudget {
    final baseBudget = existingTeam.value?.budget ?? 100.0;
    final totalSpent = slots.fold<double>(
      0,
      (sum, slot) => sum + (slot.selectedPlayer?.value.currentPrice ?? 0),
    );
    return double.parse((baseBudget - totalSpent).toStringAsFixed(1));
  }

  int get selectedCount =>
      slots.where((slot) => slot.selectedPlayer != null).length;

  int get totalSlotCount => slots.length;

  List<String> get selectedPlayerIds => slots
      .map((slot) => slot.selectedPlayer?.player.id)
      .whereType<String>()
      .toList();

  Future<void> loadDraft() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final tournament = leagueId == 'global'
          ? null
          : await _tournamentRepository.getTournament(leagueId);
      if (tournament != null) {
        leagueTitle.value = tournament.name;
        teamSize.value = tournament.teamSize;
      } else {
        leagueTitle.value = leagueId == 'global' ? 'الدوري العالمي' : leagueId;
        teamSize.value = TournamentTeamSize.fiveVsFive;
      }
      lifecycle.value = await _lifecycleService.resolveLifecycle(leagueId);

      marketPlayers.assignAll(await _marketService.getMarketPlayers());

      final userId = _authSession?.currentUserId;
      if (userId != null && userId.isNotEmpty) {
        final team = await _fantasyRepository.getFantasyTeam(userId);
        existingTeam.value = team;
        if (team != null) {
          teamNameController.text = team.teamName;
          final storedSlots = await _fantasyRepository.getTeamSlots(team.id);
          slots.assignAll(_hydrateExistingSlots(storedSlots));
          return;
        }
      }

      teamNameController.text = _authSession?.currentPlayer?.name != null
          ? 'فريق ${_authSession!.currentPlayer!.name}'
          : 'فريقي';
      slots.assignAll(_buildDefaultSlots(teamSize.value));
    } catch (error, stackTrace) {
      AppLogger.error(
        'FantasyCreateTeamController.loadDraft',
        error,
        stackTrace,
      );
      errorMessage.value = 'تعذر تحميل بناء التشكيلة حالياً.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> autoPick() async {
    if (!canEditDraft) {
      _showDraftLockedMessage();
      return;
    }

    final selected = <FantasyDraftSlot>[];
    final usedIds = <String>{};
    var remaining = existingTeam.value?.budget ?? 100.0;

    for (final slot in _buildDefaultSlots(teamSize.value)) {
      final candidates =
          marketPlayers.where((player) {
            if (usedIds.contains(player.player.id)) {
              return false;
            }
            if (!_matchesPosition(slot.requiredPosition, player.positionCode)) {
              return false;
            }
            if (player.value.currentPrice > remaining) {
              return false;
            }
            final virtual = <PlayerFantasyValue>[
              ...selected
                  .map((item) => item.selectedPlayer?.value)
                  .whereType<PlayerFantasyValue>(),
              player.value,
            ];
            return TierSystemEngine.validateTeamTiers(virtual) == null;
          }).toList()..sort(
            (a, b) => b.value.totalFantasyPoints.compareTo(
              a.value.totalFantasyPoints,
            ),
          );

      if (candidates.isEmpty) {
        Get.snackbar(
          'التشكيل التلقائي تعثر',
          'لا توجد تشكيلة كاملة ضمن القيود الحالية واللاعبين المتاحين.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final picked = candidates.first;
      usedIds.add(picked.player.id);
      remaining -= picked.value.currentPrice;
      selected.add(slot.copyWith(selectedPlayer: picked));
    }

    slots.assignAll(selected);
  }

  void assignPlayerToSlot(int index, FantasyMarketPlayer player) {
    if (!canEditDraft) {
      _showDraftLockedMessage();
      return;
    }

    if (selectedPlayerIds.contains(player.player.id) &&
        slots[index].selectedPlayer?.player.id != player.player.id) {
      Get.snackbar(
        'لا يمكن التكرار',
        'هذا اللاعب موجود بالفعل داخل تشكيلتك.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final slot = slots[index];
    if (!_matchesPosition(slot.requiredPosition, player.positionCode)) {
      Get.snackbar(
        'مركز غير مناسب',
        'هذه الخانة مخصصة لمركز ${slot.requiredPosition}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final previousPrice = slot.selectedPlayer?.value.currentPrice ?? 0;
    final projectedBudget =
        remainingBudget + previousPrice - player.value.currentPrice;
    if (projectedBudget < 0) {
      Get.snackbar(
        'الميزانية لا تكفي',
        'لا يمكن اختيار هذا اللاعب داخل الميزانية الحالية.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final virtualValues = <PlayerFantasyValue>[
      ...slots
          .where((item) => item.key != slot.key)
          .map((item) => item.selectedPlayer?.value)
          .whereType<PlayerFantasyValue>(),
      player.value,
    ];
    final tierValidation = TierSystemEngine.validateTeamTiers(virtualValues);
    if (tierValidation != null) {
      Get.snackbar(
        'قيد الفئات',
        tierValidation,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final updated = [...slots];
    updated[index] = slot.copyWith(selectedPlayer: player);
    slots.assignAll(updated);
  }

  void clearSlot(int index) {
    if (!canEditDraft) {
      _showDraftLockedMessage();
      return;
    }

    final updated = [...slots];
    updated[index] = updated[index].copyWith(clearPlayer: true);
    slots.assignAll(updated);
  }

  Future<void> saveTeam() async {
    if (!canEditDraft) {
      _showDraftLockedMessage();
      return;
    }

    final userId = _authSession?.currentUserId;
    if (userId == null || userId.isEmpty) {
      Get.snackbar(
        'تسجيل الدخول مطلوب',
        'يجب تسجيل الدخول قبل حفظ فريق الفانتازي.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (slots.any((slot) => slot.selectedPlayer == null)) {
      Get.snackbar(
        'التشكيلة غير مكتملة',
        'اختر لاعباً لكل خانة قبل الحفظ.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final values = slots
        .map((slot) => slot.selectedPlayer!.value)
        .toList(growable: false);
    final tierValidation = TierSystemEngine.validateTeamTiers(values);
    if (tierValidation != null) {
      Get.snackbar(
        'قيد الفئات',
        tierValidation,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final name = teamNameController.text.trim().isEmpty
        ? 'فريقي'
        : teamNameController.text.trim();

    try {
      isSaving.value = true;
      final now = DateTime.now();
      final existing = existingTeam.value;
      final leagueIds = <String>{
        'global',
        ...(existing?.leagueIds ?? const <String>[]),
        leagueId,
      }.toList();

      final team = FantasyTeam(
        id: userId,
        ownerPlayerId: userId,
        teamName: name,
        leagueIds: leagueIds,
        budget: remainingBudget,
        totalPoints: existing?.totalPoints ?? 0,
        currentGameweekPoints: existing?.currentGameweekPoints ?? 0,
        freeTransfers: existing?.freeTransfers ?? 1,
        freeTransfersGameweek:
            existing != null && existing.freeTransfersGameweek > 0
            ? existing.freeTransfersGameweek
            : (lifecycle.value?.currentGameweek ?? 1),
        totalTransfers: existing?.totalTransfers ?? 0,
        formation: _formationLabel(teamSize.value),
        chipUsages: existing?.chipUsages ?? const [],
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final builtSlots = slots.map((slot) {
        return FantasySlot(
          id: '${userId}_${slot.key}',
          fantasyTeamId: userId,
          playerId: slot.selectedPlayer!.player.id,
          isStartingXI: slot.isStarting,
          benchPriority: slot.benchPriority,
        );
      }).toList();

      await _fantasyRepository.createFantasyTeam(team, builtSlots);
      existingTeam.value = team;
      Get.snackbar(
        'تم الحفظ',
        'تم حفظ فريق الفانتازي وربطه بالدوري الحالي.',
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.offNamed(AppRoutes.fantasyTeamForLeague(leagueId));
    } catch (error, stackTrace) {
      AppLogger.error(
        'FantasyCreateTeamController.saveTeam',
        error,
        stackTrace,
      );
      Get.snackbar(
        'فشل الحفظ',
        'تعذر حفظ التشكيلة حالياً.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSaving.value = false;
    }
  }

  List<FantasyDraftSlot> _hydrateExistingSlots(List<FantasySlot> storedSlots) {
    final template = _buildDefaultSlots(teamSize.value);
    final sortedStored = [...storedSlots]
      ..sort((a, b) {
        if (a.isStartingXI != b.isStartingXI) {
          return a.isStartingXI ? -1 : 1;
        }
        return a.benchPriority.compareTo(b.benchPriority);
      });

    return List.generate(template.length, (index) {
      final base = template[index];
      if (index >= sortedStored.length) {
        return base;
      }
      final stored = sortedStored[index];
      final selected = marketPlayers.firstWhereOrNull(
        (player) => player.player.id == stored.playerId,
      );
      return base.copyWith(selectedPlayer: selected);
    });
  }

  List<FantasyDraftSlot> _buildDefaultSlots(TournamentTeamSize size) {
    final starters = switch (size) {
      TournamentTeamSize.fiveVsFive => ['GK', 'DEF', 'MID', 'MID', 'FWD'],
      TournamentTeamSize.sixVsSix => ['GK', 'DEF', 'DEF', 'MID', 'MID', 'FWD'],
      TournamentTeamSize.sevenVsSeven => [
        'GK',
        'DEF',
        'DEF',
        'MID',
        'MID',
        'MID',
        'FWD',
      ],
      TournamentTeamSize.eightVsEight => [
        'GK',
        'DEF',
        'DEF',
        'DEF',
        'MID',
        'MID',
        'MID',
        'FWD',
      ],
      TournamentTeamSize.nineVsNine => [
        'GK',
        'DEF',
        'DEF',
        'DEF',
        'MID',
        'MID',
        'MID',
        'FWD',
        'FWD',
      ],
      TournamentTeamSize.tenVsTen => [
        'GK',
        'DEF',
        'DEF',
        'DEF',
        'MID',
        'MID',
        'MID',
        'MID',
        'FWD',
        'FWD',
      ],
      TournamentTeamSize.elevenVsEleven => [
        'GK',
        'DEF',
        'DEF',
        'DEF',
        'DEF',
        'MID',
        'MID',
        'MID',
        'MID',
        'FWD',
        'FWD',
      ],
    };

    final starterSlots = List.generate(starters.length, (index) {
      final position = starters[index];
      return FantasyDraftSlot(
        key: 'starter_$index',
        requiredPosition: position,
        label: 'أساسي ${index + 1}',
        isStarting: true,
        benchPriority: 0,
      );
    });

    final benchSlots = List.generate(size.fantasyBenchCount, (index) {
      return FantasyDraftSlot(
        key: 'bench_$index',
        requiredPosition: 'SUB',
        label: 'بديل ${index + 1}',
        isStarting: false,
        benchPriority: index + 1,
      );
    });

    return [...starterSlots, ...benchSlots];
  }

  String _formationLabel(TournamentTeamSize size) => switch (size) {
    TournamentTeamSize.fiveVsFive => '1-2-1',
    TournamentTeamSize.sixVsSix => '2-2-1',
    TournamentTeamSize.sevenVsSeven => '2-3-1',
    TournamentTeamSize.eightVsEight => '3-3-1',
    TournamentTeamSize.nineVsNine => '3-3-2',
    TournamentTeamSize.tenVsTen => '3-4-2',
    TournamentTeamSize.elevenVsEleven => '4-4-2',
  };

  bool _matchesPosition(String slotPosition, String playerPosition) {
    if (slotPosition == 'SUB') {
      return true;
    }
    return slotPosition == playerPosition;
  }

  void _showDraftLockedMessage() {
    Get.snackbar(
      'التشكيلة مغلقة',
      'لا يمكن تعديل أو حفظ التشكيلة حالياً لأن الجولة مقفولة.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
