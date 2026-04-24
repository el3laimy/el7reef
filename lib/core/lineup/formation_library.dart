class FormationSet {
  final String defaultFormation;
  final List<String> options;

  const FormationSet({required this.defaultFormation, required this.options});
}

const Map<int, FormationSet> formationsByPlayerCount = {
  5: FormationSet(
    defaultFormation: '1-2-1',
    options: ['1-2-1', '2-1-1', '1-1-2', '2-2'],
  ),
  6: FormationSet(
    defaultFormation: '2-2-1',
    options: ['2-2-1', '2-1-2', '1-2-2', '3-1-1'],
  ),
  7: FormationSet(
    defaultFormation: '2-3-1',
    options: ['2-3-1', '3-2-1', '2-2-2', '3-1-2'],
  ),
  8: FormationSet(
    defaultFormation: '3-3-1',
    options: ['3-3-1', '2-3-2', '3-2-2', '2-4-1'],
  ),
  9: FormationSet(
    defaultFormation: '3-3-2',
    options: ['3-3-2', '3-4-1', '4-3-1', '2-3-3'],
  ),
  10: FormationSet(
    defaultFormation: '3-4-2',
    options: ['3-4-2', '4-3-2', '3-3-3', '4-2-3'],
  ),
  11: FormationSet(
    defaultFormation: '4-2-3-1',
    options: [
      '4-2-3-1',
      '4-3-3',
      '4-4-2',
      '3-5-2',
      '3-4-3',
      '5-4-1',
      '4-1-4-1',
    ],
  ),
};

const List<int> supportedPlayerCounts = [5, 6, 7, 8, 9, 10, 11];

int clampSupportedPlayerCount(int playerCount) {
  return playerCount.clamp(5, 11).toInt();
}

int normalizeMatchTeamSize(int? teamSize) {
  if (teamSize == null || !formationsByPlayerCount.containsKey(teamSize)) {
    return 5;
  }
  return teamSize;
}

String getDefaultFormation(int playerCount) {
  final supportedCount = clampSupportedPlayerCount(playerCount);
  return formationsByPlayerCount[supportedCount]!.defaultFormation;
}

List<String> getAvailableFormations(int playerCount) {
  final supportedCount = clampSupportedPlayerCount(playerCount);
  return formationsByPlayerCount[supportedCount]!.options;
}

bool isValidFormationForPlayerCount(int playerCount, String formationCode) {
  final supportedCount = clampSupportedPlayerCount(playerCount);
  return formationsByPlayerCount[supportedCount]!.options.contains(
        formationCode,
      ) &&
      getTotalPlayersForFormation(formationCode) == supportedCount;
}

List<int> parseFormationCode(String formationCode) {
  final parts = formationCode
      .split('-')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toList(growable: false);
  if (parts.isEmpty || parts.any((part) => part <= 0)) {
    return const [];
  }
  return parts;
}

int getTotalPlayersForFormation(String formationCode) {
  final outfieldPlayers = parseFormationCode(
    formationCode,
  ).fold<int>(0, (sum, lineCount) => sum + lineCount);
  return outfieldPlayers + 1;
}

String formationStyleLabel(String formationCode) {
  final lines = parseFormationCode(formationCode);
  if (lines.isEmpty) {
    return 'خطة';
  }
  final defenders = lines.first;
  final attackers = lines.last;
  if (attackers > defenders) {
    return 'هجومي';
  }
  if (defenders > attackers + 1) {
    return 'دفاعي';
  }
  if (lines.length >= 4) {
    return 'منظم';
  }
  return 'متوازن';
}
