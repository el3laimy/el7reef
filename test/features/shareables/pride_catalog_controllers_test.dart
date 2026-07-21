import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/core/enums/tournament_enums.dart';
import 'package:el7reef/core/enums/tournament_ops_enums.dart';
import 'package:el7reef/domain/entities/group_standing_snapshot.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/match_event.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/domain/entities/tournament.dart';
import 'package:el7reef/domain/entities/tournament_group.dart';
import 'package:el7reef/domain/entities/tournament_participant.dart';
import 'package:el7reef/features/profile/models/public_player_profile_data.dart';
import 'package:el7reef/features/shareables/controllers/player_moment_share_controller.dart';
import 'package:el7reef/features/shareables/controllers/qualification_share_controller.dart';
import 'package:el7reef/features/shareables/controllers/tournament_announcement_share_controller.dart';
import 'package:el7reef/features/shareables/models/player_moment_share_data.dart';
import 'package:el7reef/features/shareables/models/qualification_share_data.dart';

void main() {
  const announcementController = TournamentAnnouncementShareController();
  const momentController = PlayerMomentShareController();
  const qualificationController = QualificationShareController();

  test(
    'tournament invite exists only while real registration has capacity',
    () {
      final tournament = _tournament();

      final invite = announcementController.buildInviteIfEligible(
        tournament: tournament,
      );

      expect(invite, isNotNull);
      expect(invite!.tournamentName, 'كأس الحارة');
      expect(invite.teamSizeLabel, '5 ضد 5');
      expect(invite.sharePayload.cardType, ShareCardType.tournamentInvite);
      expect(
        announcementController.buildInviteIfEligible(
          tournament: tournament.copyWith(activeParticipantCount: 8),
        ),
        isNull,
      );
      expect(
        announcementController.buildInviteIfEligible(
          tournament: tournament.copyWith(status: TournamentStatus.groupStage),
        ),
        isNull,
      );
    },
  );

  test(
    'upcoming poster requires a future published fixture and real sides',
    () {
      final tournament = _tournament();
      final now = DateTime.utc(2026, 7, 16, 18);
      final fixture = Match(
        id: 'match-1',
        organizerId: 'organizer-1',
        teamAParticipantId: 'participant-a',
        teamBParticipantId: 'participant-b',
        tournamentId: tournament.id,
        stageType: TournamentStageType.groupStage,
        roundIndex: 1,
        scheduledAt: now.add(const Duration(days: 1)),
        venueId: 'ملعب الحارة 1',
        fixtureStatus: FixtureStatus.published,
        createdAt: now,
      );
      final teamA = _participant(
        id: 'participant-a',
        sourceId: 'team-a',
        name: 'نجوم الحارة',
      );
      final teamB = _participant(
        id: 'participant-b',
        sourceId: 'team-b',
        name: 'فرسان الميدان',
      );

      final poster = announcementController.buildUpcomingFixtureIfEligible(
        tournament: tournament,
        fixture: fixture,
        teamA: teamA,
        teamB: teamB,
        now: now,
      );

      expect(poster, isNotNull);
      expect(poster!.location, 'ملعب الحارة 1');
      expect(poster.stageLabel, contains('الجولة 2'));
      expect(poster.sharePayload.cardType, ShareCardType.upcomingFixture);
      expect(
        announcementController.buildUpcomingFixtureIfEligible(
          tournament: tournament,
          fixture: fixture.copyWith(fixtureStatus: FixtureStatus.draft),
          teamA: teamA,
          teamB: teamB,
          now: now,
        ),
        isNull,
      );
      expect(
        announcementController.buildUpcomingFixtureIfEligible(
          tournament: tournament,
          fixture: fixture.copyWith(scheduledAt: now),
          teamA: teamA,
          teamB: teamB,
          now: now,
        ),
        isNull,
      );
    },
  );

  test(
    'goal card counts active MatchEvents only after official settlement',
    () {
      const actor = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'أحمد الهداف',
      );
      final match = _settledMatch();
      final events = <MatchEvent>[
        _goalEvent('goal-1', actor),
        _goalEvent('goal-2', actor),
        _goalEvent('goal-3', actor),
        _goalEvent('voided-goal', actor, status: MatchEventStatus.voided),
        _goalEvent(
          'other-player-goal',
          actor.copyWith(id: 'guest-2', displayName: 'لاعب آخر'),
        ),
      ];

      final scorer = momentController.buildGoalScorerIfEligible(
        match: match,
        events: events,
        actor: actor,
        tournamentName: 'كأس الحارة',
        teamAName: 'نجوم الحارة',
        teamBName: 'فرسان الميدان',
      );

      expect(scorer, isNotNull);
      expect(scorer!.goalsInMatch, 3);
      expect(scorer.isHatTrick, isTrue);
      expect(scorer.sharePayload.cardType, ShareCardType.goalScorer);
      expect(
        momentController.buildGoalScorerIfEligible(
          match: Match(
            id: match.id,
            organizerId: match.organizerId,
            status: MatchStatus.pendingReview,
            scoreTeamA: 4,
            scoreTeamB: 2,
            tournamentId: match.tournamentId,
            createdAt: match.createdAt,
          ),
          events: events,
          actor: actor,
        ),
        isNull,
      );
    },
  );

  test('milestones expose only the highest earned threshold per metric', () {
    const profile = PublicPlayerProfileData(
      kind: ParticipantRefKind.player,
      id: 'player-1',
      displayName: 'أحمد الحريف',
      totalGoals: 16,
      totalMvps: 7,
    );

    final goals = momentController.buildMilestoneIfEligible(
      profile: profile,
      metric: PlayerMilestoneMetric.goals,
    );
    final mvps = momentController.buildMilestoneIfEligible(
      profile: profile,
      metric: PlayerMilestoneMetric.mvps,
    );

    expect(goals?.milestone, 10);
    expect(goals?.currentTotal, 16);
    expect(mvps?.milestone, 5);
    expect(mvps?.currentTotal, 7);
    expect(
      momentController.buildMilestoneIfEligible(
        profile: const PublicPlayerProfileData(
          kind: ParticipantRefKind.guestPlayer,
          id: 'guest-1',
          displayName: 'لاعب ضيف',
          totalGoals: 4,
          totalMvps: 2,
        ),
        metric: PlayerMilestoneMetric.goals,
      ),
      isNull,
    );
  });

  group('official qualification integrity', () {
    test(
      'uses the matching official snapshot instead of stale group qualifiers',
      () {
        final tournament = _tournament(status: TournamentStatus.groupStage);
        final now = DateTime.utc(2026, 7, 16);
        final group = TournamentGroup(
          id: 'group-a',
          tournamentId: tournament.id,
          groupStageId: 'group-stage-1',
          name: 'المجموعة أ',
          order: 0,
          participantIds: const ['participant-a'],
          qualifierParticipantIds: const [],
          createdAt: now,
          updatedAt: now,
        );
        final participant = _participant(
          id: 'participant-a',
          sourceId: 'guest-team-a',
          name: 'نجوم الحارة',
          sourceType: TournamentParticipantSourceType.guestTeam,
        );
        const entry = GroupStandingEntry(
          participantId: 'participant-a',
          displayName: 'نجوم الحارة',
          played: 3,
          wins: 3,
          goalsFor: 9,
          goalsAgainst: 2,
          rank: 1,
        );
        final snapshot = GroupStandingSnapshot(
          id: 'snapshot-a',
          tournamentId: tournament.id,
          groupStageId: group.groupStageId,
          groupId: group.id,
          entries: const [entry],
          qualifierParticipantIds: const ['participant-a'],
          createdAt: now,
          updatedAt: now,
        );

        final qualification = qualificationController.buildIfOfficial(
          tournament: tournament,
          group: group,
          snapshot: snapshot,
          entry: entry,
          participant: participant,
          qualificationIsOfficial: true,
        );

        expect(qualification, isNotNull);
        expect(qualification!.teamKindLabel, 'فريق ضيف');
        expect(qualification.points, 9);
        expect(
          qualification.sharePayload.cardType,
          ShareCardType.qualification,
        );
        expect(qualification.sharePayload.entityId, 'guest-team-a');
        expect(
          qualificationController.buildIfOfficial(
            tournament: tournament,
            group: group,
            snapshot: snapshot.copyWith(qualifierParticipantIds: const []),
            entry: entry,
            participant: participant,
            qualificationIsOfficial: true,
          ),
          isNull,
        );
      },
    );

    test('rejects mismatched tournament, group, participant, or standing', () {
      final tournament = _tournament(status: TournamentStatus.groupStage);
      final now = DateTime.utc(2026, 7, 16);
      final group = TournamentGroup(
        id: 'group-a',
        tournamentId: tournament.id,
        groupStageId: 'group-stage-1',
        name: 'المجموعة أ',
        order: 0,
        participantIds: const ['participant-a'],
        createdAt: now,
        updatedAt: now,
      );
      final participant = _participant(
        id: 'participant-a',
        sourceId: 'guest-team-a',
        name: 'نجوم الحارة',
      );
      const entry = GroupStandingEntry(
        participantId: 'participant-a',
        displayName: 'نجوم الحارة',
        played: 3,
        wins: 3,
        goalsFor: 9,
        goalsAgainst: 2,
        rank: 1,
      );
      final snapshot = GroupStandingSnapshot(
        id: 'snapshot-a',
        tournamentId: tournament.id,
        groupStageId: group.groupStageId,
        groupId: group.id,
        entries: const [entry],
        qualifierParticipantIds: const ['participant-a'],
        createdAt: now,
        updatedAt: now,
      );

      QualificationShareData? build({
        Tournament? candidateTournament,
        TournamentGroup? candidateGroup,
        GroupStandingSnapshot? candidateSnapshot,
        GroupStandingEntry? candidateEntry,
        TournamentParticipant? candidateParticipant,
        bool qualificationIsOfficial = true,
      }) {
        return qualificationController.buildIfOfficial(
          tournament: candidateTournament ?? tournament,
          group: candidateGroup ?? group,
          snapshot: candidateSnapshot ?? snapshot,
          entry: candidateEntry ?? entry,
          participant: candidateParticipant ?? participant,
          qualificationIsOfficial: qualificationIsOfficial,
        );
      }

      expect(
        build(candidateSnapshot: snapshot.copyWith(tournamentId: 'other')),
        isNull,
      );
      expect(
        build(candidateSnapshot: snapshot.copyWith(groupId: 'group-b')),
        isNull,
      );
      expect(
        build(
          candidateParticipant: participant.copyWith(tournamentId: 'other'),
        ),
        isNull,
      );
      expect(
        build(candidateParticipant: participant.copyWith(groupId: 'group-b')),
        isNull,
      );
      expect(
        build(candidateGroup: group.copyWith(participantIds: const ['other'])),
        isNull,
      );
      expect(build(candidateEntry: entry.copyWith(wins: 2)), isNull);
      expect(
        build(
          candidateParticipant: participant.copyWith(
            status: TournamentParticipantStatus.withdrawn,
          ),
        ),
        isNull,
      );
      expect(build(qualificationIsOfficial: false), isNull);
      expect(
        build(
          candidateTournament: tournament.copyWith(
            status: TournamentStatus.registration,
          ),
        ),
        isNull,
      );
    });
  });
}

Tournament _tournament({
  TournamentStatus status = TournamentStatus.registration,
}) {
  return Tournament(
    id: 'tournament-1',
    organizerId: 'organizer-1',
    name: 'كأس الحارة',
    location: 'ملعب الحارة',
    format: TournamentFormat.groupsThenKnockout,
    teamSize: TournamentTeamSize.fiveVsFive,
    maxTeams: 8,
    status: status,
    activeParticipantCount: 2,
    startDate: DateTime.utc(2026, 7, 20),
    createdAt: DateTime.utc(2026, 7, 16),
  );
}

TournamentParticipant _participant({
  required String id,
  required String sourceId,
  required String name,
  TournamentParticipantSourceType sourceType =
      TournamentParticipantSourceType.registeredTeam,
}) {
  final now = DateTime.utc(2026, 7, 16);
  return TournamentParticipant(
    id: id,
    tournamentId: 'tournament-1',
    sourceType: sourceType,
    sourceEntityId: sourceId,
    displayName: name,
    createdAt: now,
    updatedAt: now,
  );
}

Match _settledMatch() {
  return Match(
    id: 'match-1',
    organizerId: 'organizer-1',
    status: MatchStatus.settled,
    scoreTeamA: 4,
    scoreTeamB: 2,
    tournamentId: 'tournament-1',
    createdAt: DateTime.utc(2026, 7, 16),
  );
}

MatchEvent _goalEvent(
  String id,
  ParticipantRef actor, {
  MatchEventStatus status = MatchEventStatus.active,
}) {
  return MatchEvent(
    id: id,
    matchId: 'match-1',
    tournamentId: 'tournament-1',
    eventType: MatchEventType.goal,
    sideKey: 'A',
    actor: actor,
    createdBy: 'organizer-1',
    createdAt: DateTime.utc(2026, 7, 16),
    status: status,
  );
}
