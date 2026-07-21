"use strict";

const DEFAULT_PAGE_SIZE = 100;
const MAX_PAGE_SIZE = 500;
const SAMPLE_LIMIT = 20;

function normalizeNonEmptyString(value) {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

function normalizeTimestamp(value, fallbackTimestamp) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (Number.isSafeInteger(parsed) && parsed >= 0) {
    return {value: parsed, usedFallback: false};
  }

  return {value: fallbackTimestamp, usedFallback: true};
}

function buildOrganizerMembershipCandidate({
  tournamentId,
  tournament,
  fallbackTimestamp,
}) {
  const normalizedTournamentId = normalizeNonEmptyString(tournamentId);
  if (normalizedTournamentId == null) {
    return {kind: "invalid", reason: "missing-tournament-id"};
  }

  if (tournament == null || typeof tournament !== "object") {
    return {kind: "invalid", reason: "missing-tournament-data"};
  }

  const organizerId = normalizeNonEmptyString(tournament.organizerId);
  if (organizerId == null) {
    return {kind: "invalid", reason: "missing-organizer-id"};
  }

  const createdAt = normalizeTimestamp(tournament.createdAt, fallbackTimestamp);
  const membershipId = `${organizerId}_${normalizedTournamentId}`;

  return {
    kind: "candidate",
    tournamentId: normalizedTournamentId,
    membershipId,
    usedFallbackCreatedAt: createdAt.usedFallback,
    data: {
      tournamentId: normalizedTournamentId,
      userId: organizerId,
      role: "organizer",
      createdAt: createdAt.value,
    },
  };
}

function classifyExistingMembership(existingMembership, candidate) {
  if (existingMembership == null) {
    return "missing";
  }

  const createdAt = existingMembership.createdAt;
  const hasValidCreatedAt =
    Number.isSafeInteger(createdAt) && createdAt >= 0;
  const isCompatible =
    existingMembership.tournamentId === candidate.data.tournamentId &&
    existingMembership.userId === candidate.data.userId &&
    existingMembership.role === candidate.data.role &&
    hasValidCreatedAt;

  return isCompatible ? "compatible" : "conflict";
}

function normalizePositiveInteger(value, optionName) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${optionName} must be a positive integer.`);
  }
  return parsed;
}

function createSummary({dryRun, pageSize, maxDocuments}) {
  return {
    dryRun,
    pageSize,
    maxDocuments,
    scanned: 0,
    eligible: 0,
    wouldCreate: 0,
    created: 0,
    existingCompatible: 0,
    conflicts: 0,
    invalidSources: 0,
    sourceChanged: 0,
    fallbackCreatedAt: 0,
    truncated: false,
    conflictSamples: [],
    invalidSourceSamples: [],
    sourceChangedSamples: [],
  };
}

function appendSample(samples, sample) {
  if (samples.length < SAMPLE_LIMIT) {
    samples.push(sample);
  }
}

function recordExistingMembership(summary, classification, candidate) {
  if (classification === "compatible") {
    summary.existingCompatible += 1;
    return;
  }

  summary.conflicts += 1;
  appendSample(summary.conflictSamples, {
    tournamentId: candidate.tournamentId,
    membershipId: candidate.membershipId,
  });
}

function assertStore(store) {
  const requiredMethods = [
    "listTournaments",
    "getMembership",
    "createMembershipIfMissing",
  ];
  for (const methodName of requiredMethods) {
    if (typeof store?.[methodName] !== "function") {
      throw new Error(`Migration store must implement ${methodName}().`);
    }
  }
}

async function runTournamentMembershipMigration({
  store,
  dryRun = true,
  pageSize = DEFAULT_PAGE_SIZE,
  maxDocuments = null,
  now = () => Date.now(),
}) {
  assertStore(store);
  const normalizedPageSize = normalizePositiveInteger(pageSize, "pageSize");
  if (normalizedPageSize > MAX_PAGE_SIZE) {
    throw new Error(`pageSize must not exceed ${MAX_PAGE_SIZE}.`);
  }

  const normalizedMaxDocuments =
    maxDocuments == null
      ? null
      : normalizePositiveInteger(maxDocuments, "maxDocuments");
  const fallbackTimestamp = normalizeTimestamp(now(), Date.now()).value;
  const summary = createSummary({
    dryRun,
    pageSize: normalizedPageSize,
    maxDocuments: normalizedMaxDocuments,
  });
  let cursor = null;

  while (normalizedMaxDocuments == null || summary.scanned < normalizedMaxDocuments) {
    const remainingDocuments =
      normalizedMaxDocuments == null
        ? normalizedPageSize
        : Math.min(
            normalizedPageSize,
            normalizedMaxDocuments - summary.scanned,
          );
    const page = await store.listTournaments({
      after: cursor,
      limit: remainingDocuments,
    });
    const documents = Array.isArray(page?.documents) ? page.documents : null;

    if (documents == null) {
      throw new Error("Migration store returned an invalid tournament page.");
    }
    if (documents.length === 0) {
      break;
    }

    for (const document of documents) {
      summary.scanned += 1;
      const candidate = buildOrganizerMembershipCandidate({
        tournamentId: document?.id,
        tournament: document?.data,
        fallbackTimestamp,
      });

      if (candidate.kind === "invalid") {
        summary.invalidSources += 1;
        appendSample(summary.invalidSourceSamples, {
          tournamentId: normalizeNonEmptyString(document?.id),
          reason: candidate.reason,
        });
        continue;
      }

      summary.eligible += 1;
      if (candidate.usedFallbackCreatedAt) {
        summary.fallbackCreatedAt += 1;
      }

      const existingMembership = await store.getMembership(candidate.membershipId);
      const existingClassification = classifyExistingMembership(
        existingMembership,
        candidate,
      );
      if (existingClassification !== "missing") {
        recordExistingMembership(summary, existingClassification, candidate);
        continue;
      }

      if (dryRun) {
        summary.wouldCreate += 1;
        continue;
      }

      const writeResult = await store.createMembershipIfMissing(candidate);
      if (writeResult?.status === "created") {
        summary.created += 1;
        continue;
      }
      if (writeResult?.status === "existing") {
        recordExistingMembership(
          summary,
          classifyExistingMembership(writeResult.data, candidate),
          candidate,
        );
        continue;
      }
      if (writeResult?.status === "sourceChanged") {
        summary.sourceChanged += 1;
        appendSample(summary.sourceChangedSamples, {
          tournamentId: candidate.tournamentId,
        });
        continue;
      }

      throw new Error("Migration store returned an invalid write result.");
    }

    if (normalizedMaxDocuments != null && summary.scanned >= normalizedMaxDocuments) {
      summary.truncated = true;
      break;
    }
    if (documents.length < remainingDocuments) {
      break;
    }
    if (page.nextCursor == null) {
      throw new Error("Migration store omitted nextCursor for a full page.");
    }
    cursor = page.nextCursor;
  }

  return summary;
}

function hasBlockingFindings(summary) {
  return (
    summary.conflicts > 0 ||
    summary.invalidSources > 0 ||
    summary.sourceChanged > 0
  );
}

module.exports = {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  buildOrganizerMembershipCandidate,
  classifyExistingMembership,
  hasBlockingFindings,
  runTournamentMembershipMigration,
};
