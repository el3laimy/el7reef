import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/enums/fantasy_league_phase.dart';
import '../../../../core/services/chip_manager_service.dart';
import '../../../../core/services/fantasy_lifecycle_service.dart';
import '../../../../core/services/fantasy_market_service.dart';
import '../../../../core/services/fantasy_transfer_policy_service.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_chip.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../../domain/entities/fantasy_slot.dart';
import '../../../../domain/entities/fantasy_team.dart';
import '../../../../domain/entities/transfer_record.dart';
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
  final FantasyTransferPolicyService _transferPolicyService;
  final ChipManagerService _chipManagerService;
  final AuthSession? _authSession;

  FantasyTeamController({
    required this.leagueId,
    FantasyRepositoryImpl? fantasyRepository,
    FantasyMarketService? marketService,
    FantasyLifecycleService? lifecycleService,
    FantasyTransferPolicyService? transferPolicyService,
    ChipManagerService? chipManagerService,
    AuthSession? authSession,
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
        _transferPolicyService =
            transferPolicyService ?? const FantasyTransferPolicyService(),
        _chipManagerService = chipManagerService ?? const ChipManagerService(),
        _authSession = authSession;

  final RxBool isLoading = false.obs;
  final RxBool isActivatingChip = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<FantasyLeagueLifecycle?> lifecycle = Rx<FantasyLeagueLifecycle?>(null);
  final Rx<FantasyTeam?> team = Rx<FantasyTeam?>(null);
  final RxList<FantasySquadMember> starters = <FantasySquadMember>[].obs;
  final RxList<FantasySquadMember> bench = <FantasySquadMember>[].obs;
  final RxList<TransferHistoryEntry> transferHistory = <TransferHistoryEntry>[].obs;

  bool get isJoinedLeague => team.value?.leagueIds.contains(leagueId) ?? false;
  bool get isRoundLocked => lifecycle.value?.isLocked ?? false;
  bool get isRoundLive => lifecycle.value?.phase == FantasyLeaguePhase.live;
  bool get isRoundSettled => lifecycle.value?.isSettled ?? false;
  bool get hasBenchBoostActive =>
      currentGameweek > 0 && isChipActive(ChipType.benchBoost);
  TransferPolicyDecision? get transferPolicyDecision {
    final currentTeam = team.value;
    final currentLifecycle = lifecycle.value;
    if (currentTeam == null || currentLifecycle == null) {
      return null;
    }

    return _transferPolicyService.evaluateTransfer(
      team: currentTeam,
      lifecycle: currentLifecycle,
    );
  }

  bool get canOpenTransfers => transferPolicyDecision?.isAllowed ?? false;
  String? get transferBlockedReason => transferPolicyDecision?.blockedReason;
  String get transferActionLabel =>
      canOpenTransfers ? 'افتح الانتقالات' : 'الانتقالات مغلقة';
  int get currentGameweek => lifecycle.value?.currentGameweek ?? 0;
  List<ChipType> get availableChipTypes => const [
        ChipType.tripleCaptain,
        ChipType.benchBoost,
        ChipType.wildcardGroups,
        ChipType.wildcardKnockout,
      ];
  List<ChipUsage> get chipHistory =>
      List<ChipUsage>.from(team.value?.chipUsages ?? const <ChipUsage>[])
        ..sort((a, b) => b.activatedAt.compareTo(a.activatedAt));
  List<ChipUsage> get activeChipsThisRound {
    final currentTeam = team.value;
    if (currentTeam == null || currentGameweek <= 0) {
      return const [];
    }

    return currentTeam.activeChipsForGameweek(currentGameweek);
  }

  String get roundStatusTitle {
    final phase = lifecycle.value?.phase;
    if (phase == null) {
      return 'حالة الجولة غير واضحة';
    }

    return switch (phase) {
      FantasyLeaguePhase.upcoming => 'الدوري لم يبدأ بعد',
      FantasyLeaguePhase.draft => 'التشكيلة قابلة للتعديل',
      FantasyLeaguePhase.transferWindow => 'نافذة الانتقالات مفتوحة',
      FantasyLeaguePhase.live => 'فريقك مباشر الآن',
      FantasyLeaguePhase.locked => 'التشكيلة مقفولة',
      FantasyLeaguePhase.settled => 'الجولة تم اعتمادها',
      FantasyLeaguePhase.completed => 'الدوري اكتمل',
      FantasyLeaguePhase.cancelled => 'الدوري أُلغي',
    };
  }

  String get roundStatusMessage {
    final currentTeam = team.value;
    final currentLifecycle = lifecycle.value;
    if (currentTeam == null || currentLifecycle == null) {
      return 'سيظهر شرح الجولة الحالية بمجرد اكتمال تحميل بيانات فريقك.';
    }

    final gameweekLabel = currentLifecycle.currentGameweek > 0
        ? 'الجولة ${currentLifecycle.currentGameweek}'
        : 'هذه الجولة';

    return switch (currentLifecycle.phase) {
      FantasyLeaguePhase.upcoming =>
        'الدوري لم ينطلق بعد. يمكنك تجهيز تشكيلتك مبكرًا قبل فتح الجولة الأولى.',
      FantasyLeaguePhase.draft =>
        '$gameweekLabel ما زالت مفتوحة. راجع الكابتن والبدلاء والخواص قبل الإغلاق.',
      FantasyLeaguePhase.transferWindow =>
        '$gameweekLabel التالية قيد التحضير الآن. لديك ${currentTeam.freeTransfers} تبديل مجاني ويمكنك فتح السوق قبل الموعد النهائي.',
      FantasyLeaguePhase.live =>
        '$gameweekLabel جارية الآن. نقاطك الحالية (${currentTeam.currentGameweekPoints}) ما زالت مباشرة وقابلة للتغير حتى اعتماد نتائج matchday.',
      FantasyLeaguePhase.locked =>
        'تم إغلاق $gameweekLabel. لا يمكن تعديل الكابتن أو التشكيلة الآن، والنقاط المعروضة تظل مؤقتة حتى التسوية.',
      FantasyLeaguePhase.settled =>
        'تم اعتماد $gameweekLabel بنتيجة نهائية ${currentTeam.currentGameweekPoints} نقطة. راجع أثر الانتقالات والخواص قبل الجولة التالية.',
      FantasyLeaguePhase.completed =>
        'تم إغلاق هذا الدوري نهائيًا. يمكنك فقط مراجعة النقاط والترتيب النهائيين.',
      FantasyLeaguePhase.cancelled =>
        'هذا الدوري لم يعد نشطًا، لذلك شاشة الفريق هنا متاحة للمراجعة فقط.',
    };
  }

  String describeSquadSlot(FantasySquadMember member) {
    if (member.slot.isStartingXI) {
      return 'أساسي';
    }
    return 'بديل ${member.slot.benchPriority}';
  }

  String describeSquadPoints(FantasySquadMember member) {
    return 'رصيد التشكيلة ${member.slot.pointsEarned}';
  }

  String? describeSquadAvailability(FantasySquadMember member) {
    if (member.slot.isEliminated) {
      return 'هذا اللاعب خرج من البطولة ويحتاج تبديلًا قبل الجولة القادمة.';
    }
    if (member.slot.isStartingXI && hasBenchBoostActive) {
      return 'Bench Boost نشطة الآن، لذلك احتساب النقاط يشمل البدلاء أيضًا.';
    }
    if (isRoundLive) {
      return 'الجولة مباشرة الآن، لذلك التغييرات على الأدوار والانتقالات متوقفة.';
    }
    if (isRoundLocked) {
      return 'التشكيلة الحالية مقفولة لهذه الجولة حتى انتهاء التسوية.';
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    loadTeam();
  }

  Future<void> loadTeam() async {
    final userId = _authSession?.currentUserId;
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

      final syncedTeam = await _syncTeamToLifecycle(
        loadedTeam,
        lifecycle.value,
      );
      team.value = syncedTeam;
      final loadedSlots = await _fantasyRepository.getTeamSlots(syncedTeam.id);
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

      final history = await _fantasyRepository.getTeamTransfers(syncedTeam.id);
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

  bool isChipActive(ChipType chipType) {
    final currentTeam = team.value;
    if (currentTeam == null || currentGameweek <= 0) {
      return false;
    }

    return currentTeam.hasActiveChip(
      chipType,
      gameweek: currentGameweek,
    );
  }

  bool isChipConsumed(ChipType chipType) {
    final currentTeam = team.value;
    if (currentTeam == null) {
      return false;
    }

    return ChipManagerService.isChipExhausted(chipType, currentTeam);
  }

  String? chipUnavailableReason(ChipType chipType) {
    final currentTeam = team.value;
    final currentLifecycle = lifecycle.value;
    if (currentTeam == null || currentLifecycle == null) {
      return 'بيانات الفريق غير مكتملة حالياً.';
    }

    return _chipManagerService.getUnavailableReason(
      currentTeam: currentTeam,
      targetChip: chipType,
      lifecycle: currentLifecycle,
    );
  }

  Future<void> activateChip(ChipType chipType) async {
    final currentTeam = team.value;
    final currentLifecycle = lifecycle.value;
    if (currentTeam == null || currentLifecycle == null) {
      return;
    }

    final unavailableReason = chipUnavailableReason(chipType);
    if (unavailableReason != null) {
      Get.snackbar(
        'تعذر التفعيل',
        unavailableReason,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isActivatingChip.value = true;
      final updatedTeam = _chipManagerService.activateChip(
        currentTeam: currentTeam,
        targetChip: chipType,
        lifecycle: currentLifecycle,
        now: DateTime.now(),
      );
      await _fantasyRepository.updateFantasyTeam(updatedTeam);
      team.value = updatedTeam;
      await loadTeam();
      Get.snackbar(
        'تم تفعيل ${chipType.displayName}',
        'سيتم تطبيقها على الجولة ${currentLifecycle.currentGameweek}.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.snackbar(
        'فشل التفعيل',
        error.toString().replaceAll('Exception:', '').trim(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isActivatingChip.value = false;
    }
  }

  void openTransfers() {
    if (!canOpenTransfers) {
      Get.snackbar(
        'الانتقالات غير متاحة',
        transferBlockedReason ?? 'سوق الانتقالات مغلق حالياً لهذه الجولة.',
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

  Future<FantasyTeam> _syncTeamToLifecycle(
    FantasyTeam loadedTeam,
    FantasyLeagueLifecycle? currentLifecycle,
  ) async {
    if (currentLifecycle == null) {
      return loadedTeam;
    }

    final syncResult = _transferPolicyService.syncTeamForLifecycle(
      team: loadedTeam,
      lifecycle: currentLifecycle,
    );
    if (!syncResult.changed) {
      return loadedTeam;
    }

    await _fantasyRepository.updateFantasyTeam(syncResult.team);
    return syncResult.team;
  }

  String describeTransferPolicyPhase(String policyPhase) {
    return _transferPolicyService.describePolicyPhase(policyPhase);
  }

  String describeTransferAudit(TransferRecord record) {
    if (record.blockedReason != null && record.blockedReason!.isNotEmpty) {
      return record.blockedReason!;
    }
    if (record.wildcardApplied) {
      return 'Wildcard فعّلت الانتقال دون خصم.';
    }
    if (record.usedFreeTransfer) {
      return 'تم استهلاك تبديل مجاني.';
    }
    if (record.hitApplied) {
      return 'تم تطبيق خصم ${record.cost.abs()} نقاط.';
    }
    return 'انتقال ناجح دون تفاصيل إضافية.';
  }
}
