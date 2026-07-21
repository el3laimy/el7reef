enum TournamentParticipantSourceType { registeredTeam, guestTeam }

enum TournamentParticipantStatus { approved, finalized, withdrawn, replaced }

enum TournamentStageType { groupStage, knockoutStage }

enum FixtureStatus { draft, published, completed }

enum GroupStandingsMetric { points, goalDifference, goalsFor, randomDraw }

enum KnockoutFormat { singleElimination }

/// Whether a knockout fixture advances the championship or decides third place.
enum KnockoutMatchRole { championship, thirdPlace }

/// How the persisted knockout order was produced.
enum KnockoutSeedingMethod { ranked, draw, groupCrossPairing }

/// The side that advances from a knockout match.
enum KnockoutDecision { teamA, teamB }

/// How a knockout tie was resolved. Penalty goals never affect match goals.
enum KnockoutTieResolution { pending, regularTime, penalties, bye }
