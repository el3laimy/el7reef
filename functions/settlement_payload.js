const {SettlementError} = require("./settlement_error");

const MAX_ACTOR_ID_LENGTH = 128;
const MAX_DISPLAY_NAME_LENGTH = 100;
const MAX_GOAL_DRAFTS = 50;
const MAX_STAT_COUNT = 100;
const MAX_STATS_ENTRIES = 50;
const MAX_MINUTE = 300;
const VALID_MATCH_POSITIONS = new Set([
  "goalkeeper",
  "defender",
  "midfielder",
  "forward",
  "mixed",
]);
const VALID_ACTOR_KINDS = new Set(["player", "guestPlayer", "matchSidePlayer"]);
const VALID_SIDE_KEYS = new Set(["A", "B"]);
const VALID_STATS_FIELDS = new Set([
  "playerId",
  "matchId",
  "teamId",
  "played",
  "position",
  "goals",
  "assists",
  "saves",
  "tackles",
  "cleanSheet",
  "yellowCard",
  "redCard",
  "rating",
]);

class SettlementPayloadError extends SettlementError {
  constructor(message) {
    super("invalid-argument", message);
    this.name = "SettlementPayloadError";
  }
}

function normalizeSideKey(sideKey) {
  const normalized = String(sideKey || "").trim().toUpperCase();
  if (!VALID_SIDE_KEYS.has(normalized)) {
    throw new SettlementPayloadError("sideKey must be A or B");
  }
  return normalized;
}

function normalizeParticipantRef(actor) {
  if (!actor || typeof actor !== "object") {
    throw new SettlementPayloadError("actor is required");
  }
  const kind = String(actor.kind || "").trim();
  const id = String(actor.id || "").trim();
  const displayName = String(actor.displayName || "").trim();
  if (!VALID_ACTOR_KINDS.has(kind)) {
    throw new SettlementPayloadError("actor.kind is invalid");
  }
  if (!id || !displayName) {
    throw new SettlementPayloadError(
      "actor.id and actor.displayName are required",
    );
  }
  if (id.length > MAX_ACTOR_ID_LENGTH) {
    throw new SettlementPayloadError("actor.id is too long");
  }
  if (displayName.length > MAX_DISPLAY_NAME_LENGTH) {
    throw new SettlementPayloadError("actor.displayName is too long");
  }
  const linkedPlayerId = typeof actor.linkedPlayerId === "string"
    ? actor.linkedPlayerId.trim()
    : "";
  if (linkedPlayerId.length > MAX_ACTOR_ID_LENGTH) {
    throw new SettlementPayloadError("actor.linkedPlayerId is too long");
  }
  return {
    kind,
    id,
    displayName,
    linkedPlayerId: linkedPlayerId || null,
  };
}

function participantKey(actor) {
  const normalized = normalizeParticipantRef(actor);
  return `${normalized.kind}:${normalized.id}`;
}

function safeEventIdSegment(value) {
  const encoded = encodeURIComponent(String(value || "").trim());
  return encoded || "unknown";
}

function mvpEventId(matchId) {
  return `mvp-${matchId}`;
}

function goalEventId({matchId, sideKey, actor, index}) {
  const normalizedActor = normalizeParticipantRef(actor);
  return [
    "goal",
    safeEventIdSegment(matchId),
    normalizeSideKey(sideKey),
    normalizedActor.kind,
    safeEventIdSegment(normalizedActor.id),
    String(index),
  ].join("-");
}

function normalizeGoalDrafts(rawGoals) {
  if (rawGoals == null) {
    return [];
  }
  if (!Array.isArray(rawGoals)) {
    throw new SettlementPayloadError("goals must be an array");
  }
  if (rawGoals.length > MAX_GOAL_DRAFTS) {
    throw new SettlementPayloadError("too many goal drafts");
  }
  const normalizedGoals = rawGoals.map((draft) => {
    const goals = draft && draft.goals;
    if (!Number.isInteger(goals) || goals <= 0 || goals > MAX_STAT_COUNT) {
      throw new SettlementPayloadError(
        `goal count must be between 1 and ${MAX_STAT_COUNT}`,
      );
    }
    return {
      sideKey: normalizeSideKey(draft.sideKey),
      actor: normalizeParticipantRef(draft.actor),
      goals,
      minute: normalizeMinute(draft.minute),
    };
  });
  const identityKeys = new Set();
  for (const goal of normalizedGoals) {
    const identityKey = `${goal.sideKey}:${participantKey(goal.actor)}`;
    if (identityKeys.has(identityKey)) {
      throw new SettlementPayloadError("duplicate goal actor for match side");
    }
    identityKeys.add(identityKey);
  }
  return normalizedGoals;
}

function normalizeMvpDraft(rawMvp) {
  if (rawMvp == null) {
    return null;
  }
  if (typeof rawMvp !== "object" || Array.isArray(rawMvp)) {
    throw new SettlementPayloadError("mvp must be an object");
  }
  return {
    sideKey: normalizeSideKey(rawMvp.sideKey),
    actor: normalizeParticipantRef(rawMvp.actor),
  };
}

function normalizeDetailedStats(rawStats, matchId) {
  if (rawStats == null) {
    return [];
  }
  if (!Array.isArray(rawStats)) {
    throw new SettlementPayloadError("detailedStats must be an array");
  }
  if (rawStats.length > MAX_STATS_ENTRIES) {
    throw new SettlementPayloadError("too many detailed stats entries");
  }
  const playerIds = new Set();
  return rawStats.map((rawEntry) => normalizeDetailedStatsEntry({
    rawEntry,
    matchId,
    playerIds,
  }));
}

function normalizeDetailedStatsEntry({rawEntry, matchId, playerIds}) {
  assertValidStatsObject(rawEntry);
  const playerId = requiredStatsString(rawEntry.playerId, "playerId");
  assertUniqueStatsPlayer(playerIds, playerId);
  const encodedMatchId = optionalStatsString(rawEntry.matchId, "matchId");
  if (encodedMatchId && encodedMatchId !== matchId) {
    throw new SettlementPayloadError("detailed stats matchId is invalid");
  }
  const position = normalizedPosition(rawEntry.position);
  return {
    playerId,
    played: optionalBoolean(rawEntry.played, false, "played"),
    position,
    goals: optionalStatCount(rawEntry.goals, "goals"),
    assists: optionalStatCount(rawEntry.assists, "assists"),
    saves: optionalStatCount(rawEntry.saves, "saves"),
    tackles: optionalStatCount(rawEntry.tackles, "tackles"),
    cleanSheet: optionalBoolean(rawEntry.cleanSheet, false, "cleanSheet"),
    yellowCard: optionalBoolean(rawEntry.yellowCard, false, "yellowCard"),
    redCard: optionalBoolean(rawEntry.redCard, false, "redCard"),
    rating: optionalRating(rawEntry.rating),
  };
}

function assertUniqueStatsPlayer(playerIds, playerId) {
  if (playerIds.has(playerId)) {
    throw new SettlementPayloadError("duplicate detailed stats playerId");
  }
  playerIds.add(playerId);
}

function normalizedPosition(rawPosition) {
  const position = rawPosition == null ? "mixed" : rawPosition;
  if (typeof position !== "string" || !VALID_MATCH_POSITIONS.has(position)) {
    throw new SettlementPayloadError("detailed stats position is invalid");
  }
  return position;
}

function normalizeMinute(rawMinute) {
  if (rawMinute == null) {
    return null;
  }
  if (
    !Number.isInteger(rawMinute) ||
    rawMinute < 0 ||
    rawMinute > MAX_MINUTE
  ) {
    throw new SettlementPayloadError(
      `goal minute must be between 0 and ${MAX_MINUTE}`,
    );
  }
  return rawMinute;
}

function assertValidStatsObject(rawEntry) {
  if (!rawEntry || typeof rawEntry !== "object" || Array.isArray(rawEntry)) {
    throw new SettlementPayloadError("detailed stats entry must be an object");
  }
  const unknownFields = Object.keys(rawEntry).filter(
    (field) => !VALID_STATS_FIELDS.has(field),
  );
  if (unknownFields.length > 0) {
    throw new SettlementPayloadError("detailed stats contains unknown fields");
  }
}

function requiredStatsString(rawValue, fieldName) {
  const normalized = optionalStatsString(rawValue, fieldName);
  if (!normalized) {
    throw new SettlementPayloadError(`detailed stats ${fieldName} is required`);
  }
  return normalized;
}

function optionalStatsString(rawValue, fieldName) {
  if (rawValue == null) {
    return null;
  }
  if (typeof rawValue !== "string") {
    throw new SettlementPayloadError(`detailed stats ${fieldName} is invalid`);
  }
  const normalized = rawValue.trim();
  if (normalized.length > MAX_ACTOR_ID_LENGTH) {
    throw new SettlementPayloadError(`detailed stats ${fieldName} is too long`);
  }
  return normalized || null;
}

function optionalBoolean(rawValue, fallback, fieldName) {
  if (rawValue == null) {
    return fallback;
  }
  if (typeof rawValue !== "boolean") {
    throw new SettlementPayloadError(`detailed stats ${fieldName} is invalid`);
  }
  return rawValue;
}

function optionalStatCount(rawValue, fieldName) {
  if (rawValue == null) {
    return 0;
  }
  if (
    !Number.isInteger(rawValue) ||
    rawValue < 0 ||
    rawValue > MAX_STAT_COUNT
  ) {
    throw new SettlementPayloadError(
      `detailed stats ${fieldName} must be between 0 and ${MAX_STAT_COUNT}`,
    );
  }
  return rawValue;
}

function optionalRating(rawRating) {
  if (rawRating == null) {
    return 0;
  }
  if (
    typeof rawRating !== "number" ||
    !Number.isFinite(rawRating) ||
    rawRating < 0 ||
    rawRating > 10
  ) {
    throw new SettlementPayloadError(
      "detailed stats rating must be between 0 and 10",
    );
  }
  return rawRating;
}

function assertSettlementParticipantsInRoster({
  goals = [],
  mvp = null,
  mvpPlayerId = null,
  detailedStats = [],
  roster,
}) {
  const keysBySide = roster && roster.keysBySide;
  const allKeys = roster && roster.allKeys;
  if (!keysBySide || !allKeys) {
    throw new SettlementPayloadError("match roster is unavailable");
  }

  for (const goal of goals) {
    if (!keysBySide[goal.sideKey].has(participantKey(goal.actor))) {
      throw new SettlementPayloadError(
        "goal actor is outside the submitted match side roster",
      );
    }
  }
  if (mvp && !keysBySide[mvp.sideKey].has(participantKey(mvp.actor))) {
    throw new SettlementPayloadError(
      "mvp actor is outside the submitted match side roster",
    );
  }

  const normalizedLegacyMvpId = String(mvpPlayerId || "").trim();
  if (normalizedLegacyMvpId) {
    const matchesRosterIdentity = [...allKeys].some(
      (key) => key.substring(key.indexOf(":") + 1) === normalizedLegacyMvpId,
    );
    if (!matchesRosterIdentity) {
      throw new SettlementPayloadError("mvp player is outside match roster");
    }
  }

  for (const stats of detailedStats) {
    const playerId = String((stats && stats.playerId) || "").trim();
    if (playerId && !allKeys.has(`player:${playerId}`)) {
      throw new SettlementPayloadError(
        "detailed stats player is outside match roster",
      );
    }
  }
}

module.exports = {
  SettlementPayloadError,
  assertSettlementParticipantsInRoster,
  goalEventId,
  mvpEventId,
  normalizeGoalDrafts,
  normalizeDetailedStats,
  normalizeMvpDraft,
  normalizeParticipantRef,
  normalizeSideKey,
  participantKey,
};
