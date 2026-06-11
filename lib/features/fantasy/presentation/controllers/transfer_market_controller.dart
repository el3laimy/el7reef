import 'package:get/get.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/enums/fantasy_league_phase.dart';
import '../../../../core/utils/app_logger.dart';
import '../../services/fantasy_lifecycle_service.dart';
import '../../services/fantasy_market_service.dart';
import '../../services/fantasy_transfer_policy_service.dart';
import '../../services/transfer_engine.dart';
import '../../../../data/repositories/fantasy_lifecycle_repository_impl.dart';
import '../../../../data/repositories/fantasy_repository_impl.dart';
import '../../../../data/repositories/tournament_repository_impl.dart';
import '../../../../domain/entities/fantasy_chip.dart';
import '../../../../domain/entities/fantasy_league_lifecycle.dart';
import '../../../../domain/entities/fantasy_team.dart';
import '../../../../features/fantasy/presentation/models/fantasy_market_player.dart';
import '../../../../features/fantasy/presentation/models/fantasy_squad_member.dart';

class TransferMarketController extends GetxController {
  final String leagueId;
  final FantasyRepositoryImpl _fantasyRepository;
  final FantasyMarketService _marketService;
  final TournamentRepositoryImpl _tournamentRepository;
  final FantasyLifecycleService _lifecycleService;
  final FantasyTransferPolicyService _transferPolicyService;
  final AuthSession? _authSession;

  late final TransferEngine _transferEngine = TransferEngine(
    _fantasyRepository,
    transferPolicyService: _transferPolicyService,
  );

  TransferMarketController({
    required this.leagueId,
    FantasyRepositoryImpl? fantasyRepository,
    FantasyMarketService? marketService,
    TournamentRepositoryImpl? tournamentRepository,
    FantasyLifecycleService? lifecycleService,
    FantasyTransferPolicyService? transferPolicyService,
    AuthSession? authSession,
  }) : _fantasyRepository = fantasyRepository ?? FantasyRepositoryImpl(),
       _marketService =
           marketService ??
           (Get.isRegistered<FantasyMarketService>()
               ? Get.find<FantasyMarketService>()
               : FantasyMarketService()),
       _tournamentRepository =
           tournamentRepository ?? TournamentRepositoryImpl(),
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
       _transferPolicyService =
           transferPolicyService ?? const FantasyTransferPolicyService(),
       _authSession = authSession;

  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString leagueTitle = 'سوق الانتقالات'.obs;
  final Rx<FantasyLeagueLifecycle?> lifecycle = Rx<FantasyLeagueLifecycle?>(
    null,
  );
  final Rx<FantasyTeam?> team = Rx<FantasyTeam?>(null);
  final Rx<TransferPolicyDecision?> transferDecision =
      Rx<TransferPolicyDecision?>(null);
  final RxList<FantasySquadMember> squad = <FantasySquadMember>[].obs;
  final RxList<FantasyMarketPlayer> marketPlayers = <FantasyMarketPlayer>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    final userId = _authSession?.currentUserId;
    if (userId == null || userId.isEmpty) {
      errorMessage.value = 'يجب تسجيل الدخول أولاً.';
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';
      lifecycle.value = await _lifecycleService.resolveLifecycle(leagueId);

      if (leagueId != 'global') {
        final tournament = await _tournamentRepository.getTournament(leagueId);
        if (tournament != null) {
          leagueTitle.value = tournament.name;
        }
      }

      final loadedTeam = await _fantasyRepository.getFantasyTeam(userId);
      if (loadedTeam == null) {
        team.value = null;
        transferDecision.value = null;
        squad.clear();
        return;
      }

      final syncedTeam = await _syncTeamToLifecycle(
        loadedTeam,
        lifecycle.value,
      );
      team.value = syncedTeam;
      transferDecision.value = _buildTransferDecision(
        syncedTeam,
        lifecycle.value,
      );
      final slots = await _fantasyRepository.getTeamSlots(syncedTeam.id);
      final market = await _marketService.getMarketPlayers(limit: 120);
      marketPlayers.assignAll(market);
      final marketById = {
        for (final player in market) player.player.id: player,
      };

      squad.assignAll(
        slots
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
          }),
      );
    } catch (error, stackTrace) {
      AppLogger.error('TransferMarketController.loadMarket', error, stackTrace);
      errorMessage.value = 'تعذر تحميل سوق الانتقالات.';
    } finally {
      isLoading.value = false;
    }
  }

  double get budget => team.value?.budget ?? 0;
  int get freeTransfers => team.value?.freeTransfers ?? 0;
  bool get canTransfer => transferDecision.value?.isAllowed ?? false;
  bool get isRoundLocked => lifecycle.value?.isLocked ?? false;
  bool get isRoundSettled => lifecycle.value?.isSettled ?? false;
  String get policyPhaseLabel => transferDecision.value == null
      ? 'غير متاح'
      : _transferPolicyService.describePolicyPhase(
          transferDecision.value!.policyPhase,
        );
  String get transferStatusMessage =>
      transferDecision.value?.executionLabelAr ??
      'بيانات الانتقالات غير مكتملة حالياً.';
  String? get blockedTransferReason => transferDecision.value?.blockedReason;
  int get projectedFreeTransfersAfterMove =>
      transferDecision.value?.freeTransfersAfter ?? freeTransfers;
  int get projectedPointsDelta => transferDecision.value?.pointsDelta ?? 0;
  bool get wildcardActive {
    final currentTeam = team.value;
    final currentLifecycle = lifecycle.value;
    if (currentTeam == null || currentLifecycle == null) {
      return false;
    }

    return currentTeam.hasActiveChip(
          ChipType.wildcardGroups,
          gameweek: currentLifecycle.currentGameweek,
        ) ||
        currentTeam.hasActiveChip(
          ChipType.wildcardKnockout,
          gameweek: currentLifecycle.currentGameweek,
        );
  }

  String get transferWindowTitle {
    final phase = lifecycle.value?.phase;
    if (phase == null) {
      return 'حالة السوق غير واضحة';
    }

    return switch (phase) {
      FantasyLeaguePhase.upcoming => 'السوق لم يفتح بعد',
      FantasyLeaguePhase.draft => 'سوق التشكيل الأول',
      FantasyLeaguePhase.transferWindow => 'السوق مفتوح الآن',
      FantasyLeaguePhase.live => 'الجولة تُلعب الآن',
      FantasyLeaguePhase.locked => 'السوق مقفول مؤقتًا',
      FantasyLeaguePhase.settled => 'بانتظار الجولة التالية',
      FantasyLeaguePhase.completed => 'الدوري اكتمل',
      FantasyLeaguePhase.cancelled => 'الدوري أُلغي',
    };
  }

  String get transferWindowSubtitle {
    final currentTeam = team.value;
    final currentLifecycle = lifecycle.value;
    final decision = transferDecision.value;
    if (currentTeam == null || currentLifecycle == null) {
      return 'سيظهر سبب فتح أو إغلاق السوق بمجرد اكتمال بيانات الجولة.';
    }

    final gameweekLabel = currentLifecycle.currentGameweek > 0
        ? 'الجولة ${currentLifecycle.currentGameweek}'
        : 'هذه الجولة';

    if (decision == null) {
      return 'سيتم احتساب رصيد الانتقالات وسياسة الجولة الحالية بعد تحميل بيانات الفريق.';
    }

    if (!decision.isAllowed) {
      return decision.blockedReason ??
          '$gameweekLabel لا تسمح بإجراء انتقالات جديدة في الوقت الحالي.';
    }

    if (decision.wildcardApplied) {
      return '$gameweekLabel تسمح بانتقالات إضافية دون خصومات لأن Wildcard نشطة على فريقك.';
    }

    if (decision.usedFreeTransfer) {
      return '$gameweekLabel تسمح بانتقال مجاني الآن. بعد الصفقة سيبقى لديك ${decision.freeTransfersAfter} تبديل مجاني.';
    }

    if (decision.hitApplied) {
      return '$gameweekLabel تسمح بالانتقالات، لكن الصفقة التالية ستكلّفك ${decision.pointsDelta.abs()} نقاط بسبب نفاد التبديلات المجانية.';
    }

    return 'السوق متاح الآن ويمكنك تعديل تشكيلتك وفق سياسة الجولة الحالية.';
  }

  String get nextTransferImpactTitle {
    final decision = transferDecision.value;
    if (decision == null) {
      return 'تأثير الصفقة التالية';
    }
    if (!decision.isAllowed) {
      return 'سبب الإيقاف';
    }
    if (decision.wildcardApplied) {
      return 'الصفقة التالية محمية';
    }
    if (decision.hitApplied) {
      return 'الصفقة التالية بخصم';
    }
    return 'الصفقة التالية';
  }

  String get nextTransferImpactMessage {
    final decision = transferDecision.value;
    if (decision == null) {
      return 'لا يمكن احتساب أثر الصفقة التالية قبل اكتمال حالة الجولة الحالية.';
    }
    if (!decision.isAllowed) {
      return decision.blockedReason ??
          'السوق مغلق حاليًا، لذلك لا يوجد أثر متوقع لصفقة جديدة.';
    }

    final costLabel = decision.pointsDelta == 0
        ? 'بدون خصم نقاط'
        : 'مع خصم ${decision.pointsDelta.abs()} نقاط';
    return 'الحالة الحالية: $costLabel. بعد الصفقة سيصبح رصيدك ${decision.freeTransfersAfter} تبديل مجاني.';
  }

  String describeSquadSlot(FantasySquadMember member) {
    if (member.slot.isStartingXI) {
      return 'أساسي';
    }
    return 'بديل ${member.slot.benchPriority}';
  }

  Future<void> replacePlayer({
    required FantasySquadMember member,
    required FantasyMarketPlayer replacement,
  }) async {
    final currentTeam = team.value;
    if (currentTeam == null) {
      return;
    }

    final currentLifecycle = await _lifecycleService.resolveLifecycle(leagueId);
    lifecycle.value = currentLifecycle;
    final syncedTeam = await _syncTeamToLifecycle(
      currentTeam,
      currentLifecycle,
    );
    team.value = syncedTeam;
    transferDecision.value = _buildTransferDecision(
      syncedTeam,
      currentLifecycle,
    );

    if (!(transferDecision.value?.isAllowed ?? false)) {
      Get.snackbar(
        'سوق الانتقالات مغلق',
        transferDecision.value?.blockedReason ??
            'لا يمكن تنفيذ انتقالات في هذه المرحلة من الجولة.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currentValues = squad
        .map((member) => member.marketPlayer.value)
        .toList(growable: false);

    try {
      isSubmitting.value = true;
      await _transferEngine.executeTransfer(
        currentTeam: syncedTeam,
        lifecycle: currentLifecycle,
        slotToReplace: member.slot,
        playerOutValue: member.marketPlayer.value,
        playerInValue: replacement.value,
        fullTeamValues: currentValues,
      );
      Get.snackbar(
        'تمت الصفقة',
        'تم استبدال ${member.marketPlayer.displayName} بـ ${replacement.displayName}.',
        snackPosition: SnackPosition.BOTTOM,
      );
      await loadData();
    } catch (error) {
      Get.snackbar(
        'تعذر تنفيذ الصفقة',
        error.toString().replaceAll('Exception:', '').trim(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  List<String> selectedIdsExcluding(String currentPlayerId) {
    return squad
        .map((member) => member.marketPlayer.player.id)
        .where((id) => id != currentPlayerId)
        .toList();
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

  TransferPolicyDecision? _buildTransferDecision(
    FantasyTeam? currentTeam,
    FantasyLeagueLifecycle? currentLifecycle,
  ) {
    if (currentTeam == null || currentLifecycle == null) {
      return null;
    }

    return _transferPolicyService.evaluateTransfer(
      team: currentTeam,
      lifecycle: currentLifecycle,
    );
  }
}
