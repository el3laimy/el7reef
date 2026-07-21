"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  parseOfficialSquadText,
  parsePlayerLine,
} = require("../../tool/build_world_cup_2026_squads");
const {
  parseMatchBlock,
  parseScheduledAt,
} = require("../../tool/build_world_cup_2026_matches");

test("player row preserves the public name and official squad attributes", () => {
  const player = parsePlayerLine(
    "{{nat fs g player|no=10|pos=FW|name=[[Lionel Messi]]|sortname=Messi, Lionel|other=[[Captain (association football)|captain]]|age={{birth date and age2|df=y|2026|6|11|1987|6|24}}|caps=206|goals=125|club=[[Inter Miami CF]]|clubnat=USA}}",
  );

  assert.deepEqual(player, {
    shirtNumber: 10,
    position: "FW",
    displayName: "Lionel Messi",
    birthDate: "1987-06-24",
    clubName: "Inter Miami CF",
    clubCountryCode: "USA",
  });
});

test("official PDF text parser indexes positions by team code and shirt number", () => {
  const officialTeams = parseOfficialSquadText(`
    Argentina (ARG)
# POS PLAYER NAME
1  GK  MUSSO Juan
2  DF  SENESI Marcos
`);

  assert.equal(officialTeams.get("ARG").officialName, "Argentina");
  assert.equal(officialTeams.get("ARG").positionsByShirtNumber.get(1), "GK");
  assert.equal(officialTeams.get("ARG").positionsByShirtNumber.get(2), "DF");
});

test("match parser preserves regular and penalty scores as separate decisions", () => {
  const match = parseMatchBlock(`{{#invoke:football box|main
|date={{Start date|2026|7|7}}
|time=1:00&nbsp;p.m. [[UTC−07:00|UTC−7]]
|team1={{#invoke:flag|fb-rt|SUI}}
|score={{score link|anchor|0–0}}
|aet=yes
|team2={{#invoke:flag|fb|COL}}
|stadium=[[BC Place]], [[Vancouver]]
|penaltyscore=4–3
|report=[https://www.fifa.com/en/match-centre/match/17/1 "Report"] PMSR-M96-SUI
}}`);

  assert.equal(match.matchNumber, 96);
  assert.equal(match.scoreTeamA, 0);
  assert.equal(match.scoreTeamB, 0);
  assert.equal(match.penaltyScoreTeamA, 4);
  assert.equal(match.penaltyScoreTeamB, 3);
  assert.equal(match.scheduledAt, "2026-07-07T20:00:00.000Z");
});

test("local host time converts to UTC without changing the advertised date", () => {
  assert.equal(
    parseScheduledAt(
      "{{Start date|2026|6|11}}",
      "1:00&nbsp;p.m. [[UTC−06:00|UTC−6]]",
    ),
    "2026-06-11T19:00:00.000Z",
  );
});

test("reviewed World Cup dataset contains 12 groups, 48 teams, and 1248 real squad slots", () => {
  const datasetPath = path.join(
    __dirname,
    "../../functions/data/world_cup_2026_squads.json",
  );
  const dataset = JSON.parse(fs.readFileSync(datasetPath, "utf8"));

  assert.deepEqual(dataset.counts, {groups: 12, teams: 48, players: 1248});
  assert.equal(dataset.teams.length, 48);
  assert.equal(new Set(dataset.teams.map((team) => team.code)).size, 48);
  assert.equal(
    dataset.teams.reduce((count, team) => count + team.players.length, 0),
    1248,
  );
  for (const team of dataset.teams) {
    assert.equal(team.players.length, 26, team.code);
    assert.ok(
      team.players.filter((player) => player.position === "GK").length >= 3,
      `${team.code} must include at least three goalkeepers`,
    );
  }
});

test("reviewed World Cup results contain 104 fixtures with only the last two pending", () => {
  const datasetPath = path.join(
    __dirname,
    "../../functions/data/world_cup_2026_matches.json",
  );
  const dataset = JSON.parse(fs.readFileSync(datasetPath, "utf8"));

  assert.deepEqual(dataset.counts, {
    matches: 104,
    groupMatches: 72,
    settledMatches: 102,
    scheduledMatches: 2,
  });
  assert.deepEqual(
    dataset.matches
      .filter((match) => match.status === "scheduled")
      .map((match) => match.matchNumber),
    [103, 104],
  );
  assert.equal(
    dataset.matches.filter((match) => match.resolutionType === "penalties").length,
    4,
  );
});
