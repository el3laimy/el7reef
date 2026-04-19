import '../../core/enums/tournament_enums.dart';
import '../../domain/entities/group_standing_snapshot.dart';
import '../../domain/entities/knockout_bracket.dart';
import '../../domain/entities/tournament.dart';

class TournamentCompletionPolicy {
  const TournamentCompletionPolicy();

  String determineWinnerParticipantId({
    required Tournament tournament,
    KnockoutBracket? bracket,
    List<GroupStandingSnapshot> standings = const [],
  }) {
    switch (tournament.format) {
      case TournamentFormat.knockoutOnly:
      case TournamentFormat.groupsThenKnockout:
        final winner = bracket?.championParticipantId;
        if (winner == null || winner.isEmpty) {
          throw Exception('لا يمكن إنهاء البطولة قبل تحديد الفائز النهائي.');
        }
        return winner;
      case TournamentFormat.groupsOnly:
        if (standings.isEmpty || standings.first.entries.isEmpty) {
          throw Exception('لا يمكن إنهاء بطولة المجموعات بدون ترتيب نهائي.');
        }
        return standings.first.entries.first.participantId;
    }
  }
}
