"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const EXPECTED_PDF_SHA256 =
  "e1d1f2c385d35e5cea9f9079ccb5599a45a66e7ff840628745e1ff9b5e69ffac";

const TEAM_META = {
  "Czech Republic": ["CZE", "Czechia", "التشيك"],
  Mexico: ["MEX", "Mexico", "المكسيك"],
  "South Africa": ["RSA", "South Africa", "جنوب أفريقيا"],
  "South Korea": ["KOR", "Korea Republic", "كوريا الجنوبية"],
  "Bosnia and Herzegovina": ["BIH", "Bosnia And Herzegovina", "البوسنة والهرسك"],
  Canada: ["CAN", "Canada", "كندا"],
  Qatar: ["QAT", "Qatar", "قطر"],
  Switzerland: ["SUI", "Switzerland", "سويسرا"],
  Brazil: ["BRA", "Brazil", "البرازيل"],
  Haiti: ["HAI", "Haiti", "هايتي"],
  Morocco: ["MAR", "Morocco", "المغرب"],
  Scotland: ["SCO", "Scotland", "اسكتلندا"],
  Australia: ["AUS", "Australia", "أستراليا"],
  Paraguay: ["PAR", "Paraguay", "باراغواي"],
  Turkey: ["TUR", "Türkiye", "تركيا"],
  "United States": ["USA", "USA", "الولايات المتحدة"],
  "Curaçao": ["CUW", "Curaçao", "كوراساو"],
  Ecuador: ["ECU", "Ecuador", "الإكوادور"],
  Germany: ["GER", "Germany", "ألمانيا"],
  "Ivory Coast": ["CIV", "Côte D'Ivoire", "ساحل العاج"],
  Japan: ["JPN", "Japan", "اليابان"],
  Netherlands: ["NED", "Netherlands", "هولندا"],
  Sweden: ["SWE", "Sweden", "السويد"],
  Tunisia: ["TUN", "Tunisia", "تونس"],
  Belgium: ["BEL", "Belgium", "بلجيكا"],
  Egypt: ["EGY", "Egypt", "مصر"],
  Iran: ["IRN", "IR Iran", "إيران"],
  "New Zealand": ["NZL", "New Zealand", "نيوزيلندا"],
  "Cape Verde": ["CPV", "Cabo Verde", "الرأس الأخضر"],
  "Saudi Arabia": ["KSA", "Saudi Arabia", "السعودية"],
  Spain: ["ESP", "Spain", "إسبانيا"],
  Uruguay: ["URU", "Uruguay", "أوروغواي"],
  France: ["FRA", "France", "فرنسا"],
  Iraq: ["IRQ", "Iraq", "العراق"],
  Norway: ["NOR", "Norway", "النرويج"],
  Senegal: ["SEN", "Senegal", "السنغال"],
  Algeria: ["ALG", "Algeria", "الجزائر"],
  Argentina: ["ARG", "Argentina", "الأرجنتين"],
  Austria: ["AUT", "Austria", "النمسا"],
  Jordan: ["JOR", "Jordan", "الأردن"],
  Colombia: ["COL", "Colombia", "كولومبيا"],
  "DR Congo": ["COD", "Congo DR", "الكونغو الديمقراطية"],
  Portugal: ["POR", "Portugal", "البرتغال"],
  Uzbekistan: ["UZB", "Uzbekistan", "أوزبكستان"],
  Croatia: ["CRO", "Croatia", "كرواتيا"],
  England: ["ENG", "England", "إنجلترا"],
  Ghana: ["GHA", "Ghana", "غانا"],
  Panama: ["PAN", "Panama", "بنما"],
};

function plainWikiText(value) {
  return value
    .replace(/\[\[[^\]|]+\|([^\]]+)\]\]/g, "$1")
    .replace(/\[\[([^\]]+)\]\]/g, "$1")
    .replace(/''/g, "")
    .trim();
}

function parsePlayerLine(line) {
  const header = line.match(
    /^\{\{nat fs g player\|no=(\d+)\|pos=(GK|DF|MF|FW)\|name=(.*?)\|sortname=/,
  );
  const birthDate = line.match(
    /\|age=\{\{birth date and age2\|(?:df=y\|)?2026\|6\|11\|(\d{4})\|(\d{1,2})\|(\d{1,2})\}\}/,
  );
  const club = line.match(/\|club=(.*?)\|clubnat=([A-Z]{3})\}\}$/);
  if (!header || !birthDate || !club) {
    throw new Error(`Unsupported squad player row: ${line}`);
  }

  const [, shirtNumber, position, rawName] = header;
  const [, year, month, day] = birthDate;
  return {
    shirtNumber: Number(shirtNumber),
    position,
    displayName: plainWikiText(rawName),
    birthDate: [year, month.padStart(2, "0"), day.padStart(2, "0")].join("-"),
    clubName: plainWikiText(club[1]),
    clubCountryCode: club[2],
  };
}

function parseSquadWikitext(wikitext) {
  const teams = [];
  let group = null;
  let teamName = null;
  let currentTeam = null;

  for (const line of wikitext.split(/\r?\n/)) {
    const groupHeading = line.match(/^==Group ([A-L])==$/);
    if (groupHeading) {
      group = groupHeading[1];
      teamName = null;
      currentTeam = null;
      continue;
    }
    const teamHeading = line.match(/^===([^=]+)===$/);
    if (teamHeading && group) {
      teamName = teamHeading[1];
      currentTeam = null;
      continue;
    }
    if (!line.startsWith("{{nat fs g player|")) continue;
    if (!group || !teamName || !TEAM_META[teamName]) {
      throw new Error(`Unknown group team for player row: ${teamName ?? "none"}`);
    }
    if (!currentTeam) {
      const [code, officialName, displayNameAr] = TEAM_META[teamName];
      currentTeam = {
        group,
        code,
        sourceName: teamName,
        officialName,
        displayNameAr,
        players: [],
      };
      teams.push(currentTeam);
    }
    currentTeam.players.push(parsePlayerLine(line));
  }
  return teams;
}

function parseOfficialSquadText(officialText) {
  const teamsByCode = new Map();
  for (const page of officialText.split("\f")) {
    const teamHeading = page.match(/^\s*(.+?) \(([A-Z]{3})\)\s*$/m);
    if (!teamHeading) continue;
    const positionsByShirtNumber = new Map();
    for (const line of page.split(/\r?\n/)) {
      const playerRow = line.match(/^\s*(\d+)\s+(GK|DF|MF|FW)\s+/);
      if (playerRow) {
        positionsByShirtNumber.set(Number(playerRow[1]), playerRow[2]);
      }
    }
    teamsByCode.set(teamHeading[2], {
      officialName: teamHeading[1].trim(),
      positionsByShirtNumber,
    });
  }
  return teamsByCode;
}

function reconcileOfficialPositions(teams, officialTeamsByCode) {
  const corrections = [];
  for (const team of teams) {
    const officialTeam = officialTeamsByCode.get(team.code);
    if (!officialTeam) continue;
    for (const player of team.players) {
      const officialPosition = officialTeam.positionsByShirtNumber.get(
        player.shirtNumber,
      );
      if (officialPosition && officialPosition !== player.position) {
        corrections.push({
          teamCode: team.code,
          shirtNumber: player.shirtNumber,
          displayName: player.displayName,
          helperPosition: player.position,
          officialPosition,
        });
        player.position = officialPosition;
      }
    }
  }
  return corrections;
}

function validateSquads(teams, officialTeamsByCode) {
  if (teams.length !== 48) throw new Error(`Expected 48 teams, got ${teams.length}.`);
  const playerCount = teams.reduce((total, team) => total + team.players.length, 0);
  if (playerCount !== 1248) throw new Error(`Expected 1248 players, got ${playerCount}.`);
  if (officialTeamsByCode.size !== 48) {
    throw new Error(`Expected 48 official PDF teams, got ${officialTeamsByCode.size}.`);
  }

  for (const team of teams) {
    if (team.players.length !== 26) {
      throw new Error(`${team.code} has ${team.players.length} players instead of 26.`);
    }
    const officialTeam = officialTeamsByCode.get(team.code);
    if (!officialTeam || officialTeam.officialName !== team.officialName) {
      throw new Error(`Official team mismatch for ${team.code}.`);
    }
    for (const player of team.players) {
      if (officialTeam.positionsByShirtNumber.get(player.shirtNumber) !== player.position) {
        throw new Error(`${team.code} #${player.shirtNumber} position differs from FIFA PDF.`);
      }
    }
    const shirtNumbers = new Set(team.players.map((player) => player.shirtNumber));
    if (shirtNumbers.size !== 26 || Math.min(...shirtNumbers) !== 1 || Math.max(...shirtNumbers) !== 26) {
      throw new Error(`${team.code} shirt numbers are not exactly 1 through 26.`);
    }
    if (team.players.filter((player) => player.position === "GK").length < 3) {
      throw new Error(`${team.code} has fewer than three goalkeepers.`);
    }
  }
}

function buildSquadDataset({wikiJson, officialPdf, officialText}) {
  const pdfSha256 = crypto.createHash("sha256").update(officialPdf).digest("hex");
  if (pdfSha256 !== EXPECTED_PDF_SHA256) {
    throw new Error(`Unreviewed FIFA squad PDF digest: ${pdfSha256}.`);
  }
  const parsedWiki = JSON.parse(wikiJson);
  const teams = parseSquadWikitext(parsedWiki.parse?.wikitext ?? "");
  const officialTeamsByCode = parseOfficialSquadText(officialText);
  const positionCorrections = reconcileOfficialPositions(
    teams,
    officialTeamsByCode,
  );
  validateSquads(teams, officialTeamsByCode);
  return {
    schemaVersion: 1,
    asOf: "2026-07-17",
    tournament: "FIFA World Cup 2026",
    sources: {
      squadAuthorityUrl:
        "https://fdp.fifa.org/assetspublic/ce281/pdf/SquadLists-English.pdf",
      squadAuthorityVersion: "2026-07-15T21:14:00Z",
      squadAuthoritySha256: pdfSha256,
      playerNameHelperUrl:
        "https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_squads",
    },
    sourceReconciliation: {positionCorrections},
    counts: {groups: 12, teams: 48, players: 1248},
    teams,
  };
}

function parseOptions(argumentsList) {
  const options = {};
  for (let index = 0; index < argumentsList.length; index += 2) {
    const option = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!["--wiki-json", "--official-pdf", "--official-text", "--output"].includes(option) || !value) {
      throw new Error("Usage: node tool/build_world_cup_2026_squads.js --wiki-json <json> --official-pdf <pdf> --official-text <txt> --output <json>");
    }
    options[option.slice(2)] = value;
  }
  for (const required of ["wiki-json", "official-pdf", "official-text", "output"]) {
    if (!options[required]) throw new Error(`Missing --${required}.`);
  }
  return options;
}

function main() {
  const options = parseOptions(process.argv.slice(2));
  const dataset = buildSquadDataset({
    wikiJson: fs.readFileSync(options["wiki-json"], "utf8"),
    officialPdf: fs.readFileSync(options["official-pdf"]),
    officialText: fs.readFileSync(options["official-text"], "utf8"),
  });
  fs.mkdirSync(path.dirname(options.output), {recursive: true});
  fs.writeFileSync(options.output, `${JSON.stringify(dataset, null, 2)}\n`);
  console.log(JSON.stringify(dataset.counts));
}

if (require.main === module) main();

module.exports = {
  buildSquadDataset,
  parseOfficialSquadText,
  parsePlayerLine,
  parseSquadWikitext,
  plainWikiText,
  reconcileOfficialPositions,
  validateSquads,
};
