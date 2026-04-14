import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/services/fantasy_lifecycle_service.dart';
import '../../../../core/services/fantasy_market_service.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../../domain/entities/fantasy_slot.dart';
import '../../../../domain/entities/fantasy_team.dart';
import '../../../../domain/entities/transfer_record.dart';
import '../../../../services/auth_service.dart';
import '../models/fantasy_squad_member.dart';

class TransferHistoryEntry {
  final TransferRecord record;
  final String playerOutName;
  final String playerInName;

  const TransferHistoryEntry({
    required this.record,
    required this.playerOutName,
    required this.playerInName,
  });
}

class FantasyTeamController extends GetxController {
  final String leagueId;
  final FantasyRepositoryImpl _fantasyRepository;
  final FantasyMarketService _marketService;
  final FantasyLifecycleService _lifecycleService;
  final AuthService? _authService;

  FantasyTeamController({
    required this.leagueId,
    FantasyRepositoryImpl? fantasyRepository,
    FantasyMarketService? marketService,
    FantasyLifecycleService? lifecycleService,
    AuthService? authService,
  })  : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
        _marketService = marketService ??
            (Get.isRegistered<FantasyMarketService>()
                ? Get.find<FantasyMarketService>()
                : FantasyMarketService()),
        _lifecycleService = lifecycleService ??
            (Get.isRegistered<FantasyLifecycleService>()
                ? Get.find<FantasyLifecycleService>()
                : FantasyLifecycleService(
                    lifecycleRepository:
                        Get.isRegistered<FantasyLifecycleRepositoryImpl>()
                            ? Get.find<FantasyLifecycleRepositoryImpl>()
                            : null,
                    tournamentRepository:
                        Get.isRegistered<TournamentRepositoryImpl>()
                            ? Get.find<TournamentRepositoryImpl>()
                            : null,
                  )),
        _authService = authService ??
            (Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null);

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<FantasyLeagueLifecycle?> lifecycle = Rx<FantasyLeagueLifecycle?>(null);
  final Rx<FantasyTeam?> team = Rx<FantasyTeam?>(null);
  final RxList<FantasySquadMember> starters = <FantasySquadMember>[].obs;
  final RxList<FantasySquadMember> bench = <FantasySquadMember>[].obs;
  final RxList<TransferHistoryEntry> transferHistory = <TransferHistoryEntry>[].obs;

  bool get isJoinedLeague => team.value?.leagueIds.contains(leagueId) ?? false;
  bool get isRoundLocked => lifecycle.value?.isLocked ?? false;
  bool get canOpenTransfers => lifecycle.value?.allowsTransfers ?? true;

  @override
  void onInit() {
    super.onInit();
    loadTeam();
  }

  Future<void> loadTeam() async {
    final userId = _authService?.currentUserId;
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول لعرض فريق الفانتازي.';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      lifecycle.value = await _lifecycleService.resolveLifecycle(leagueId);

      final loadedTeam = await _fantasyRepository.getFantasyTeam(userId);
      if (loadedTeam == null) {
        team.value = null;
        starters.clear();
        bench.clear();
        transferHistory.clear();
        return;
      }

      team.value = loadedTeam;
      final loadedSlots = await _fantasyRepository.getTeamSlots(loadedTeam.id);
      final marketPlayers = await _marketService.getMarketPlayers(limit: 120);
      final marketById = {
        for (final player in marketPlayers) player.player.id: player,
      };

      final members = loadedSlots
          .where((slot) => marketById.containsKey(slot.playerId))
          .map(
            (slot) => FantasySquadMember(
              slot: slot,
              marketPlayer: marketById[slot.playerId]!,
            ),
          )
          .toList()
        ..sort((a, b) {
          if (a.slot.isStartingXI != b.slot.isStartingXI) {
            return a.slot.isStartingXI ? -1 : 1;
          }
          return a.slot.benchPriority.compareTo(b.slot.benchPriority);
        });

      starters.assignAll(members.where((member) => member.slot.isStartingXI));
      bench.assignAll(members.where((member) => !member.slot.isStartingXI));

      final history = await _fantasyRepository.getTeamTransfers(loadedTeam.id);
      transferHistory.assignAll(
        history.take(5).map(
          (record) => TransferHistoryEntry(
            record: record,
            playerOutName: marketById[record.playerOutId]?.displayName ??
                record.playerOutId,
            playerInName:
                marketById[record.playerInId]?.displayName ?? record.playerInId,
          ),
        ),
      );
    } catch (_) {
      errorMessage.value = 'تعذر تحميل تشكيلتك الآن.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setCaptain(String slotId) async {
    await _updateRole(slotId, FantasyPlayerRole.captain);
  }

  Future<void> setViceCaptain(String slotId) async {
    await _updateRole(slotId, FantasyPlayerRole.viceCaptain);
  }

  Future<void> _updateRole(String slotId, FantasyPlayerRole role) async {
    if (team.value == null) return;
    if (isRoundLocked) {
      Get.snackbar(
        'الجولة مغلقة',
        'لا يمكن تعديل الكابتن أو نائب الكابتن حالياً.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final squad = [...starters, ...bench];
    final target = squad.firstWhereOrNull((member) => member.slot.id == slotId);
    if (target == null) return;

    final updates = <FantasySlot>[];
    for (final member in squad) {
      if (member.slot.id == slotId) {
        updates.add(member.slot.copyWith(role: role));
      } else if (member.slot.role == role) {
        updates.add(member.slot.copyWith(role: FantasyPlayerRole.none));
      }
    }

    for (final slot in updates) {
      await _fantasyRepository.updateFantasySlot(slot);
    }

    await loadTeam();
    Get.snackbar(
      'تم التحديث',
      role == FantasyPlayerRole.captain
          ? 'تم تعيين الكابتن.'
          : 'تم تعيين نائب الكابتن.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void openTransfers() {
    if (!canOpenTransfers) {
      Get.snackbar(
        'الانتقالات غير متاحة',
        'سوق الانتقالات مغلق حالياً لهذه الجولة.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.toNamed(AppRoutes.fantasyTransfersForLeague(leagueId));
  }

  void openDraft() {
    if (!(lifecycle.value?.allowsDraftEdits ?? true)) {
      Get.snackbar(
        'الانضمام غير متاح',
        'التعديلات على التشكيلة مغلقة حالياً لهذه الجولة.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.toNamed(AppRoutes.fantasyPickTeamForLeague(leagueId));
  }
}
