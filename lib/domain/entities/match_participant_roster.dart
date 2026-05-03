import 'match.dart';
import 'participant_ref.dart';

class MatchParticipantRoster {
  final Match match;
  final List<ParticipantRef> sideA;
  final List<ParticipantRef> sideB;

  const MatchParticipantRoster({
    required this.match,
    required this.sideA,
    required this.sideB,
  });

  List<ParticipantRef> get allParticipants {
    final participants = <ParticipantRef>[];
    final seen = <String>{};
    for (final participant in [...sideA, ...sideB]) {
      final key = participantRosterKey(participant);
      if (seen.add(key)) {
        participants.add(participant);
      }
    }
    return participants;
  }

  List<ParticipantRef> participantsForSide(String sideKey) {
    switch (sideKey.trim().toUpperCase()) {
      case 'A':
        return sideA;
      case 'B':
        return sideB;
      default:
        return const <ParticipantRef>[];
    }
  }

  bool isParticipantOnSide({
    required ParticipantRef participant,
    required String sideKey,
  }) {
    final key = participantRosterKey(participant);
    return participantsForSide(
      sideKey,
    ).any((candidate) => participantRosterKey(candidate) == key);
  }

  String? sideKeyFor(ParticipantRef participant) {
    if (isParticipantOnSide(participant: participant, sideKey: 'A')) {
      return 'A';
    }
    if (isParticipantOnSide(participant: participant, sideKey: 'B')) {
      return 'B';
    }
    return null;
  }
}

String participantRosterKey(ParticipantRef participant) {
  return '${participant.kind.name}:${participant.id}';
}
