"use strict";

const fs = require("node:fs");
const path = require("node:path");

const {plainWikiText} = require("./build_world_cup_2026_squads");

function field(block, name) {
  return block.match(new RegExp(`^\\|${name}=(.*)$`, "m"))?.[1].trim() ?? null;
}

function parseTeamCode(rawTeam) {
  return rawTeam?.match(/\|([A-Z]{3})\}\}$/)?.[1] ?? null;
}

function parseScore(rawScore) {
  const match = rawScore?.match(/\|(\d+)[–-](\d+)(?:\||\}\})/);
  return match ? [Number(match[1]), Number(match[2])] : null;
}

function parseScheduledAt(rawDate, rawTime) {
  const date = rawDate?.match(/\{\{Start date\|(\d{4})\|(\d{1,2})\|(\d{1,2})\}\}/);
  const time = rawTime?.match(/(\d{1,2}):(\d{2}).*?([ap])\.m\..*?UTC[−-](\d{1,2})/);
  if (!date || !time) return null;
  let hour = Number(time[1]) % 12;
  if (time[3] === "p") hour += 12;
  const utcMilliseconds = Date.UTC(
    Number(date[1]),
    Number(date[2]) - 1,
    Number(date[3]),
    hour + Number(time[4]),
    Number(time[2]),
  );
  return new Date(utcMilliseconds).toISOString();
}

function extractFootballBoxBlocks(wikitext) {
  const blocks = [];
  const startPattern = /\{\{#invoke:football box\|main/gi;
  for (const match of wikitext.matchAll(startPattern)) {
    const remainder = wikitext.slice(match.index);
    const end = remainder.search(/^\}\}(?:<section end=.*)?$/m);
    if (end < 0) throw new Error("Unterminated football box.");
    blocks.push(remainder.slice(0, end + 2));
  }
  return blocks;
}

function parseMatchBlock(block) {
  const regularScore = parseScore(field(block, "score"));
  const penaltyScore = parseScore(`|${field(block, "penaltyscore") ?? ""}}}`);
  const reportMatchNumber = block.match(/PMSR-M(\d{2,3})\b/)?.[1];
  const pendingMatchNumber = field(block, "score")?.match(/\|Match (\d{3})(?:\||\}\})/)?.[1];
  const matchNumber = Number(reportMatchNumber ?? pendingMatchNumber);
  const teamA = parseTeamCode(field(block, "team1"));
  const teamB = parseTeamCode(field(block, "team2"));
  if (!Number.isInteger(matchNumber) || !teamA || !teamB) {
    throw new Error(`Incomplete match identity: #${matchNumber} ${teamA}-${teamB}.`);
  }
  const officialMatchCentreUrl = block.match(
    /https:\/\/www\.fifa\.com\/en\/match-centre\/match\/[^ "\]]+/,
  )?.[0] ?? null;
  return {
    matchNumber,
    teamA,
    teamB,
    scheduledAt: parseScheduledAt(field(block, "date"), field(block, "time")),
    venue: plainWikiText(field(block, "stadium") ?? ""),
    scoreTeamA: regularScore?.[0] ?? null,
    scoreTeamB: regularScore?.[1] ?? null,
    penaltyScoreTeamA: penaltyScore?.[0] ?? null,
    penaltyScoreTeamB: penaltyScore?.[1] ?? null,
    wentToExtraTime: field(block, "aet") === "yes",
    officialMatchCentreUrl,
  };
}

function withStage(
  match,
  stageType,
  roundIndex,
  groupCode = null,
  bracketRole = null,
) {
  const completed = match.scoreTeamA != null && match.scoreTeamB != null;
  const decidedByPenalties = match.penaltyScoreTeamA != null;
  return {
    ...match,
    stageType,
    groupCode,
    roundIndex,
    bracketRole,
    status: completed ? "settled" : "scheduled",
    resolutionType: completed
      ? decidedByPenalties
        ? "penalties"
        : "regularTime"
      : "pending",
  };
}

function parseResultsPages(apiJson) {
  const parsed = JSON.parse(apiJson);
  const pages = parsed.query?.pages ?? [];
  const matches = [];
  const revisions = [];

  for (const page of pages) {
    const revision = page.revisions?.[0];
    const wikitext = revision?.slots?.main?.content ?? "";
    const blocks = extractFootballBoxBlocks(wikitext);
    revisions.push({title: page.title, revisionId: revision?.revid, timestamp: revision?.timestamp});

    const groupMatch = page.title.match(/^2026 FIFA World Cup Group ([A-L])$/);
    if (groupMatch) {
      if (blocks.length !== 6) throw new Error(`${page.title} has ${blocks.length} matches.`);
      blocks.forEach((block, index) => {
        matches.push(withStage(parseMatchBlock(block), "groupStage", Math.floor(index / 2), groupMatch[1]));
      });
      continue;
    }
    if (page.title === "2026 FIFA World Cup round of 32") {
      if (blocks.length !== 16) throw new Error(`Round of 32 has ${blocks.length} matches.`);
      blocks.forEach((block) =>
        matches.push(
          withStage(parseMatchBlock(block), "knockoutStage", 0, null, "championship"),
        ),
      );
      continue;
    }
    if (page.title === "2026 FIFA World Cup knockout stage") {
      const stageSizes = [8, 4, 2];
      if (blocks.length !== 15) throw new Error(`Later knockout page has ${blocks.length} matches.`);
      let offset = 0;
      stageSizes.forEach((size, stageOffset) => {
        blocks.slice(offset, offset + size).forEach((block) => {
          matches.push(
            withStage(
              parseMatchBlock(block),
              "knockoutStage",
              stageOffset + 1,
              null,
              "championship",
            ),
          );
        });
        offset += size;
      });
      matches.push(
        withStage(
          parseMatchBlock(blocks[14]),
          "knockoutStage",
          4,
          null,
          "thirdPlace",
        ),
      );
      continue;
    }
    if (page.title === "2026 FIFA World Cup final") {
      if (blocks.length !== 1) throw new Error(`Final page has ${blocks.length} matches.`);
      matches.push(
        withStage(
          parseMatchBlock(blocks[0]),
          "knockoutStage",
          4,
          null,
          "championship",
        ),
      );
    }
  }
  matches.sort((left, right) => left.matchNumber - right.matchNumber);
  return {matches, revisions};
}

function validateMatches(matches, validTeamCodes) {
  if (matches.length !== 104) throw new Error(`Expected 104 matches, got ${matches.length}.`);
  const numbers = new Set(matches.map((match) => match.matchNumber));
  if (numbers.size !== 104 || Math.min(...numbers) !== 1 || Math.max(...numbers) !== 104) {
    throw new Error("Match numbers are not exactly 1 through 104.");
  }
  const groupMatches = matches.filter((match) => match.stageType === "groupStage");
  const completed = matches.filter((match) => match.status === "settled");
  if (groupMatches.length !== 72 || completed.length !== 102) {
    throw new Error(`Expected 72 group and 102 completed matches, got ${groupMatches.length}/${completed.length}.`);
  }
  for (const match of matches) {
    if (!validTeamCodes.has(match.teamA) || !validTeamCodes.has(match.teamB)) {
      throw new Error(`Unknown team code in match ${match.matchNumber}.`);
    }
    if (!match.scheduledAt || !match.venue) {
      throw new Error(`Missing schedule metadata for match ${match.matchNumber}.`);
    }
    if (match.status === "settled" && !match.officialMatchCentreUrl) {
      throw new Error(`Completed match ${match.matchNumber} lacks its FIFA report URL.`);
    }
    if (match.resolutionType === "penalties" && match.penaltyScoreTeamA === match.penaltyScoreTeamB) {
      throw new Error(`Penalty match ${match.matchNumber} is still tied.`);
    }
  }
}

function buildMatchDataset({resultsApiJson, squadsJson}) {
  const squads = JSON.parse(squadsJson);
  const {matches, revisions} = parseResultsPages(resultsApiJson);
  validateMatches(matches, new Set(squads.teams.map((team) => team.code)));
  return {
    schemaVersion: 1,
    asOf: "2026-07-17",
    tournament: "FIFA World Cup 2026",
    sources: {
      officialResultsUrl:
        "https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/match-schedule-fixtures-results-teams-stadiums",
      extractionHelper: "Wikipedia MediaWiki revision wikitext",
      revisions,
    },
    counts: {
      matches: 104,
      groupMatches: 72,
      settledMatches: 102,
      scheduledMatches: 2,
    },
    matches,
  };
}

function main() {
  const [resultsPath, squadsPath, outputPath] = process.argv.slice(2);
  if (!resultsPath || !squadsPath || !outputPath) {
    throw new Error("Usage: node tool/build_world_cup_2026_matches.js <results-api.json> <squads.json> <output.json>");
  }
  const dataset = buildMatchDataset({
    resultsApiJson: fs.readFileSync(resultsPath, "utf8"),
    squadsJson: fs.readFileSync(squadsPath, "utf8"),
  });
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputPath, `${JSON.stringify(dataset, null, 2)}\n`);
  console.log(JSON.stringify(dataset.counts));
}

if (require.main === module) main();

module.exports = {
  buildMatchDataset,
  extractFootballBoxBlocks,
  parseMatchBlock,
  parseResultsPages,
  parseScheduledAt,
  validateMatches,
};
