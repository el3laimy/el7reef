import '../../../core/enums/match_status.dart';
import '../../../core/enums/tournament_ops_enums.dart';
import '../../../domain/entities/match.dart';

enum TournamentOpsNextActionKind {
  recordLiveScore,
  reviewPendingScore,
  prepareUpcomingFixture,
  addParticipant,
  finalizeParticipants,
  startGroupStage,
  publishFixtures,
  startKnockout,
  completeTournament,
}

class TournamentOpsNextAction {
  final TournamentOpsNextActionKind kind;
  final String label;
  final String detail;
  final List<String> requirements;
  final bool needsConfirmation;
  final String? confirmTitle;
  final String? confirmMessage;
  final String? matchId;

  const TournamentOpsNextAction({
    required this.kind,
    required this.label,
    required this.detail,
    required this.requirements,
    this.needsConfirmation = false,
    this.confirmTitle,
    this.confirmMessage,
    this.matchId,
  });
}

class TournamentOperationsReadModel {
  final List<Match> fixtures;

  const TournamentOperationsReadModel({required this.fixtures});

  int get draftFixturesCount => fixtures
      .where((fixture) => fixture.fixtureStatus == FixtureStatus.draft)
      .length;

  int get publishedFixturesCount => fixtures
      .where((fixture) => fixture.fixtureStatus == FixtureStatus.published)
      .length;

  int get releasedFixturesCount => fixtures
      .where((fixture) => fixture.fixtureStatus != FixtureStatus.draft)
      .length;

  int get scheduledFixturesCount =>
      fixtures.where((fixture) => fixture.scheduledAt != null).length;

  int get officialResultsCount =>
      fixtures.where((fixture) => fixture.isOfficialTournamentResult).length;

  Match? get urgentFixture {
    for (final fixture in fixtures) {
      if (fixture.status == MatchStatus.live) return fixture;
    }
    for (final fixture in fixtures) {
      if (fixture.status == MatchStatus.pendingReview) return fixture;
    }
    return null;
  }

  Match? get nextPublishedFixture {
    final candidates =
        fixtures
            .where(
              (fixture) =>
                  fixture.fixtureStatus == FixtureStatus.published &&
                  (fixture.status == MatchStatus.open ||
                      fixture.status == MatchStatus.full),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final leftSchedule = left.scheduledAt;
            final rightSchedule = right.scheduledAt;
            if (leftSchedule != null && rightSchedule != null) {
              final scheduledComparison = leftSchedule.compareTo(rightSchedule);
              if (scheduledComparison != 0) return scheduledComparison;
            } else if (leftSchedule != null) {
              return -1;
            } else if (rightSchedule != null) {
              return 1;
            }
            return left.createdAt.compareTo(right.createdAt);
          });
    return candidates.firstOrNull;
  }

  TournamentOpsNextAction? nextAction({
    required int activeParticipantsCount,
    bool canAddParticipants = false,
    required bool canFinalizeParticipants,
    required bool canStartGroupStage,
    required bool canPublishFixtures,
    required bool canStartKnockout,
    required bool canCompleteTournament,
    required String Function(Match fixture, {required bool isHome})
    fixtureTeamLabel,
  }) {
    final urgent = urgentFixture;
    if (urgent != null) {
      final isLive = urgent.status == MatchStatus.live;
      return TournamentOpsNextAction(
        kind: isLive
            ? TournamentOpsNextActionKind.recordLiveScore
            : TournamentOpsNextActionKind.reviewPendingScore,
        label: isLive ? 'سجّل النتيجة الآن' : 'راجع النتيجة المعلقة',
        detail:
            '${fixtureTeamLabel(urgent, isHome: true)} ضد ${fixtureTeamLabel(urgent, isHome: false)} هي أهم إجراء تشغيلي الآن.',
        requirements: const [
          'مراجعة النتيجة والهدافين وMVP.',
          'اعتماد أحداث المباراة قبل الانتقال للمرحلة التالية.',
        ],
        matchId: urgent.id,
      );
    }
    if (canAddParticipants && activeParticipantsCount < 2) {
      final firstTeam = activeParticipantsCount == 0;
      return TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.addParticipant,
        label: firstTeam ? 'أضف أول فريق' : 'أضف الفريق الثاني',
        detail: firstTeam
            ? 'ابدأ بإضافة فريق مسجل أو فريق ضيف. الفريق الضيف له نفس مسار البطولة والإحصائيات.'
            : 'أضف فريقًا ثانيًا حتى يصبح توليد مباريات البطولة متاحًا.',
        requirements: const [
          'يمكن إضافة فريق مسجل أو فريق ضيف.',
          'يمكن إضافة اللاعبين مباشرة بعد إنشاء الفريق.',
        ],
      );
    }
    if (canFinalizeParticipants) {
      return TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.finalizeParticipants,
        label: 'قفل قائمة الفرق',
        detail:
            'لدينا الآن $activeParticipantsCount فرق جاهزة ومكتملة، قم بقفل القائمة لبدء الجدول.',
        requirements: const [
          'وجود فريقين نشطين على الأقل.',
          'عدم بدء أي مرحلة تشغيل بعد.',
          'مراجعة التسجيلات قبل القفل.',
        ],
        needsConfirmation: true,
        confirmTitle: 'تأكيد قفل قائمة الفرق',
        confirmMessage:
            'بعد القفل، لن تتمكن من إضافة أي فرق جديدة لهذه الدورة كمنظم. هل تريد المتابعة قفل القائمة؟',
      );
    }
    if (canStartGroupStage) {
      return const TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.startGroupStage,
        label: 'بدء دور المجموعات',
        detail:
            'تم قفل المشاركين بنجاح. الخطوة الحالية هي توليد المجموعات والمباريات الدورية لبدء اللعب.',
        requirements: [
          'قائمة الفرق مقفلة.',
          'لم يتم إنشاء دور مجموعات من قبل.',
          'عدد الفرق يسمح بتوليد المباريات.',
        ],
        needsConfirmation: true,
        confirmTitle: 'توليد مباريات ومجموعات البطولة',
        confirmMessage:
            'سيقوم النظام بتوزيع الفرق آلياً على المجموعات وتوليد جدول المباريات الكامل. هل تريد البدء؟',
      );
    }
    if (canPublishFixtures) {
      return TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.publishFixtures,
        label: 'نشر جدول المباريات',
        detail:
            'جدول المباريات جاهز كمسودة للتحقق الفني. انشره الآن لتظهر المباريات في حسابات اللاعبين على التطبيق.',
        requirements: [
          'وجود $draftFixturesCount مباراة مسودة.',
          'مراجعة المواعيد والفرق قبل النشر.',
        ],
        needsConfirmation: true,
        confirmTitle: 'نشر المباريات رسمياً للاعبين',
        confirmMessage:
            'سيتم تحويل $draftFixturesCount مباراة من مسودة إلى منشورة لتظهر رسمياً للفرق. هل تؤكد؟',
      );
    }
    if (canStartKnockout) {
      return const TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.startKnockout,
        label: 'بدء الإقصائيات',
        detail:
            'انتهت مباريات دور المجموعات وتم تحديد الترتيب. ابدأ مرحلة خروج المغلوب لمعرفة بطل الحواري.',
        requirements: [
          'اكتمال النتائج الرسمية للمرحلة السابقة.',
          'عدم وجود شجرة إقصاء منشأة مسبقًا.',
          'تثبيت المؤهلين قبل التوليد.',
        ],
        needsConfirmation: true,
        confirmTitle: 'بدء التصفيات والإقصائيات خروج المغلوب',
        confirmMessage:
            'سيقوم النظام بفرز المجموعات وتحديد المتأهلين تلقائياً لتوليد شجرة الإقصاء. هل تريد الاستمرار؟',
      );
    }
    if (canCompleteTournament) {
      return const TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.completeTournament,
        label: 'تتويج البطولة',
        detail:
            'تم حسم النهائي وتحديد البطل. حان وقت إغلاق البطولة رسمياً للاحتفال وتوليد بطاقة فخر البطل.',
        requirements: [
          'تحديد بطل البطولة.',
          'اعتماد آخر نتيجة رسمية.',
          'التأكد من جاهزية لحظة المشاركة.',
        ],
        needsConfirmation: true,
        confirmTitle: 'تتويج بطل الحواري وإغلاق الدورة',
        confirmMessage:
            'سيتم توثيق البطل الحقيقي وتوزيع ميداليات الشرف وتثبيت الإحصائيات نهائياً. هل تؤكد؟',
      );
    }
    final upcoming = nextPublishedFixture;
    if (upcoming != null) {
      return TournamentOpsNextAction(
        kind: TournamentOpsNextActionKind.prepareUpcomingFixture,
        label: 'جهّز المباراة القادمة',
        detail:
            '${fixtureTeamLabel(upcoming, isHome: true)} ضد ${fixtureTeamLabel(upcoming, isHome: false)} هي أقرب مباراة تنتظر التشغيل.',
        requirements: const [
          'راجع الموعد وطرفي المباراة.',
          'التشكيلة اختيارية، ويمكن بدء المباراة بدونها.',
        ],
        matchId: upcoming.id,
      );
    }
    return null;
  }
}
