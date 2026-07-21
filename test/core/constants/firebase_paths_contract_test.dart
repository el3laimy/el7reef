import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:el7reef/core/constants/firebase_paths.dart';

void main() {
  test('Functions and Flutter share settlement collection names', () {
    final rawContract = File(
      'functions/firestore_collections.json',
    ).readAsStringSync();
    final contract = jsonDecode(rawContract) as Map<String, dynamic>;
    const flutterPaths = <String, String>{
      'players': FirebasePaths.players,
      'guestPlayers': FirebasePaths.guestPlayers,
      'teamMemberships': FirebasePaths.teamMemberships,
      'matches': FirebasePaths.matches,
      'matchEvents': FirebasePaths.matchEvents,
      'matchSides': FirebasePaths.matchSides,
      'matchSidePlayers': FirebasePaths.matchSidePlayers,
      'matchLineupSnapshots': FirebasePaths.matchLineupSnapshots,
      'tournaments': FirebasePaths.tournaments,
      'tournamentParticipants': FirebasePaths.tournamentParticipants,
      'tournamentGroups': FirebasePaths.tournamentGroups,
      'groupStandingSnapshots': FirebasePaths.groupStandingSnapshots,
      'knockoutBrackets': FirebasePaths.knockoutBrackets,
      'knockoutTies': FirebasePaths.knockoutTies,
      'auditEvents': FirebasePaths.auditEvents,
      'fanVotingSessions': FirebasePaths.fanVotingSessions,
      'playerStats': FirebasePaths.playerStats,
    };

    expect(contract, flutterPaths);
  });
}
