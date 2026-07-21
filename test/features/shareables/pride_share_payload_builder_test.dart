import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/enums/match_status.dart';
import 'package:el7reef/domain/entities/match.dart';
import 'package:el7reef/domain/entities/participant_ref.dart';
import 'package:el7reef/domain/entities/share_payload.dart';
import 'package:el7reef/features/shareables/services/pride_share_payload_builder.dart';
import 'package:el7reef/features/shareables/services/pride_share_text_builder.dart';

void main() {
  const payloadBuilder = PrideSharePayloadBuilder();

  test('builds safe target URLs for all four existing pride cards', () {
    final match = _match();
    final result = payloadBuilder.matchResult(match: match);
    final mvp = payloadBuilder.mvp(
      match: match,
      actor: const ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-1',
        displayName: 'لا يظهر في الرابط',
      ),
    );
    final scorers = payloadBuilder.topScorers(tournamentId: 'tournament-1');
    final lineup = payloadBuilder.lineup(
      matchId: 'match-1',
      lineupId: 'lineup-1',
      tournamentId: 'tournament-1',
    );

    expect(result.cardType, ShareCardType.matchResult);
    expect(
      result.targetUrl.toString(),
      'https://el7reef-app.web.app/match/match-1',
    );
    expect(mvp.entityType, ShareEntityType.guestPlayer);
    expect(
      mvp.targetUrl.toString(),
      'https://el7reef-app.web.app/player/guestPlayer/guest-1',
    );
    expect(
      scorers.targetUrl.toString(),
      'https://el7reef-app.web.app/tournament/tournament-1',
    );
    expect(
      lineup.targetUrl.toString(),
      'https://el7reef-app.web.app/match/match-1?view=lineup',
    );
    expect(mvp.targetUrl.queryParameters.containsKey('displayName'), isFalse);
    expect(mvp.analyticsParameters.containsKey('targetUrl'), isFalse);
  });

  test('uses the match result as the MVP target without a public profile', () {
    final payload = payloadBuilder.mvp(
      match: _match(),
      actor: const ParticipantRef(
        kind: ParticipantRefKind.matchSidePlayer,
        id: 'side-player-1',
        displayName: 'لاعب مؤقت',
      ),
    );

    expect(payload.entityType, ShareEntityType.match);
    expect(payload.entityId, 'match-1');
    expect(payload.targetUrl.path, '/match/match-1');
  });

  test(
    'builds safe attributed targets for every Pride V2 catalog addition',
    () {
      final match = _match();
      const guestScorer = ParticipantRef(
        kind: ParticipantRefKind.guestPlayer,
        id: 'guest-scorer-1',
        displayName: 'اسم لا يدخل الرابط',
      );

      final invite = payloadBuilder.tournamentInvite(
        tournamentId: 'tournament-1',
      );
      final upcoming = payloadBuilder.upcomingFixture(match: match);
      final scorer = payloadBuilder.goalScorer(
        match: match,
        actor: guestScorer,
      );
      final qualification = payloadBuilder.qualification(
        tournamentId: 'tournament-1',
        teamId: 'guest-team-1',
        teamKind: 'guestTeam',
        matchId: match.id,
      );
      final milestone = payloadBuilder.playerMilestone(
        actor: guestScorer,
        tournamentId: 'tournament-1',
        matchId: match.id,
      );

      expect(invite.cardType, ShareCardType.tournamentInvite);
      expect(invite.targetUrl.path, '/tournament/tournament-1');
      expect(upcoming.cardType, ShareCardType.upcomingFixture);
      expect(upcoming.targetUrl.path, '/match/match-1');
      expect(scorer.entityType, ShareEntityType.guestPlayer);
      expect(scorer.targetUrl.path, '/player/guestPlayer/guest-scorer-1');
      expect(qualification.cardType, ShareCardType.qualification);
      expect(qualification.targetUrl.path, '/team/guestTeam/guest-team-1');
      expect(milestone.cardType, ShareCardType.playerMilestone);
      expect(milestone.targetUrl.path, scorer.targetUrl.path);

      for (final payload in <SharePayload>[
        invite,
        upcoming,
        scorer,
        qualification,
        milestone,
      ]) {
        expect(payload.targetUrl.scheme, 'https');
        expect(payload.targetUrl.queryParameters.containsKey('name'), isFalse);
        expect(
          payload.targetUrl.toString().contains(Uri.encodeComponent('اسم')),
          isFalse,
        );
        expect(payload.schemaVersion, SharePayload.currentSchemaVersion);
      }
    },
  );

  test('keeps image sharing intact when growth links are disabled', () {
    final payload = payloadBuilder.matchResult(match: _match());
    const textBuilder = PrideShareTextBuilder();

    expect(
      textBuilder.build(
        baseText: 'نتيجة المباراة على الحريف',
        payload: payload,
        includeGrowthLink: false,
      ),
      'نتيجة المباراة على الحريف',
    );
    expect(
      textBuilder.build(
        baseText: 'نتيجة المباراة على الحريف',
        payload: payload,
        includeGrowthLink: true,
      ),
      allOf(
        startsWith(
          'نتيجة المباراة على الحريف\n'
          'https://el7reef-app.web.app/match/match-1?',
        ),
        contains('shareCardType=matchResult'),
        contains('shareCampaignSource=match_result_card'),
        contains('shareSchemaVersion=1'),
      ),
    );
  });
}

Match _match() {
  return Match(
    id: 'match-1',
    organizerId: 'organizer-1',
    status: MatchStatus.settled,
    tournamentId: 'tournament-1',
    createdAt: DateTime(2026, 7, 11),
  );
}
