const crypto = require("crypto");

const {deletedAccountId} = require("./account_deletion");
const {COLLECTIONS} = require("./firestore_contract");
const {appendAuditEvent} = require("./trusted_audit");
const CLAIM_TARGETS = new Set(["guestPlayer", "guestTeam"]);
const CLAIM_SCOPES = new Set(["team", "tournament", "hybrid", "publicShare"]);
const ACTIVE_MEMBERSHIP_STATUSES = new Set(["starter", "bench"]);
const ACTIVE_CLAIM_STATUS = "active";
const CLAIMED_STATUS = "claimed";
const MIN_CLAIM_TTL_MS = 60 * 60 * 1000;
const MAX_CLAIM_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const DEFAULT_CLAIM_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const CLAIM_TOKEN_VERSION = 2;
const MAX_ACTIVE_CLAIMS_PER_TARGET = 20;
const MAX_CLAIM_MEMBERSHIPS = 64;
const CLAIM_RATE_LIMIT_SCOPE = "guestClaim";
const CLAIM_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const MAX_CLAIM_ATTEMPTS_PER_WINDOW = 240;
const MAX_CLAIM_TARGETS_PER_WINDOW = 128;
const MAX_CLAIM_ATTEMPTS_PER_TARGET = 24;

async function issueGuestClaimCodeCore({
  db,
  actorId,
  payload,
  now,
  tokenSecret,
}) {
  const issuedAt = trustedNow(now);
  const request = normalizedIssueRequest(payload, actorId);
  await consumeGuestClaimQuota({
    db,
    actorId: request.actorId,
    targetKey: issueQuotaTargetKey(request),
    attemptedAt: issuedAt,
  });
  const rawToken = issuedClaimToken(request, tokenSecret);
  return issueGuestClaimAttempt({db, request, issuedAt, rawToken});
}

async function issueGuestClaimAttempt(issueRequest) {
  const {db, request, issuedAt, rawToken} = issueRequest;
  const tokenHash = claimTokenHash(rawToken);
  return db.runTransaction(async (transaction) => {
    await activeActorSnapshot({
      transaction,
      db,
      actorId: request.actorId,
    });
    const target = await claimTargetSnapshot({transaction, db, request});
    await assertIssuerAuthorization({
      transaction,
      db,
      request,
      target: target.data(),
      issuedAt,
    });
    const activeClaims = await activeClaimsForTarget({
      transaction,
      db,
      request,
    });
    if (activeClaims.docs.length > MAX_ACTIVE_CLAIMS_PER_TARGET) {
      throw new GuestClaimError(
        "resource-exhausted",
        "Claim target has too many active legacy codes.",
      );
    }
    const tokenRef = db.collection(COLLECTIONS.claimCodes).doc(tokenHash);
    const tokenSnapshot = await transaction.get(tokenRef);
    const referencedClaims = await referencedTargetClaims({
      transaction,
      db,
      target,
      tokenHash,
    });
    const claim = newClaimDocument({request, target: target.data(), issuedAt});
    const reusable = reusableIssuedClaim({
      tokenSnapshot,
      claim,
      issuedAt,
    });
    if (tokenSnapshot.exists && !reusable) {
      throw new GuestClaimError(
        "failed-precondition",
        "Issuance requestId has already reached a terminal state.",
      );
    }
    expireSupersededClaims({
      transaction,
      claimSnapshots: uniqueDocumentSnapshots([
        ...activeClaims.docs,
        ...referencedClaims,
      ]),
      reusableId: reusable ? tokenSnapshot.id : null,
      issuedAt,
    });
    if (reusable) {
      repairInvitedTarget({transaction, target, tokenHash, issuedAt});
      return issuedClaimResponse({
        code: rawToken,
        claim: tokenSnapshot.data(),
        reused: true,
      });
    }
    stageNewInviteTarget({transaction, target, tokenHash, issuedAt});
    transaction.create(tokenRef, claim);
    return issuedClaimResponse({code: rawToken, claim, reused: false});
  });
}

async function inspectGuestClaimCore({db, actorId, payload, now}) {
  const inspectedAt = trustedNow(now);
  const request = normalizedConsumeRequest(payload, actorId);
  await consumeGuestClaimQuota({
    db,
    actorId: request.actorId,
    targetKey: claimTokenHash(request.claimCode),
    attemptedAt: inspectedAt,
  });
  return db.runTransaction(async (transaction) => {
    await activeActorSnapshot({transaction, db, actorId: request.actorId});
    const snapshot = await claimCodeSnapshot({transaction, db, request});
    const claim = snapshot.data();
    if (!CLAIM_TARGETS.has(claim.targetType) || !nonEmptyText(claim.targetId)) {
      throw new GuestClaimError(
        "failed-precondition",
        "Claim code target is invalid.",
      );
    }
    const target = await claimTargetForClaim({transaction, db, claim});
    await assertClaimProvenance({
      transaction,
      db,
      request,
      claimSnapshot: snapshot,
      claim,
      target,
    });
    const expired = claim.status === ACTIVE_CLAIM_STATUS &&
      validExpiry(claim.expiresAt) <= inspectedAt;
    const pendingApproval = claim.requiresApproval === true &&
      !expired &&
      claim.status === ACTIVE_CLAIM_STATUS &&
      nonEmptyText(claim.teamId) &&
      nonEmptyText(claim.claimedByPlayerId);
    const canApprovePendingTeamClaim = pendingApproval &&
      claim.targetType === "guestTeam" &&
      await actorCanApprovePendingTeamClaim({
        transaction,
        db,
        actorId: request.actorId,
        claim,
        guestTeam: target.data(),
      });
    return {
      targetType: claim.targetType,
      targetId: claim.targetId,
      subjectName: inspectedSubjectName(claim.targetType, target.data()),
      scope: claim.scope,
      teamId: claim.teamId || null,
      tournamentId: claim.tournamentId || null,
      requiresApproval: claim.requiresApproval === true,
      pendingApproval,
      canApprovePendingTeamClaim,
      status: expired ? "expired" : claim.status,
      expiresAt: claim.expiresAt,
    };
  });
}

async function claimTargetForClaim({transaction, db, claim}) {
  const collection = claim.targetType === "guestPlayer" ?
    COLLECTIONS.guestPlayers :
    COLLECTIONS.guestTeams;
  const target = await transaction.get(
    db.collection(collection).doc(claim.targetId),
  );
  if (!target.exists) {
    throw new GuestClaimError("not-found", "Claim target not found.");
  }
  return target;
}

async function actorCanApprovePendingTeamClaim(approvalContext) {
  const {transaction, db, actorId, claim, guestTeam} = approvalContext;
  if (guestTeam.creatorId !== actorId) return false;
  const team = await transaction.get(
    db.collection(COLLECTIONS.teams).doc(claim.teamId),
  );
  return team.exists && team.data().ownerId === claim.claimedByPlayerId;
}

function inspectedSubjectName(targetType, target) {
  const candidate = targetType === "guestPlayer" ?
    target.displayName :
    target.name;
  return nonEmptyText(candidate) ? candidate.trim() : null;
}

async function claimGuestPlayerCore({db, actorId, payload, now}) {
  const claimedAt = trustedNow(now);
  const request = normalizedConsumeRequest(payload, actorId);
  await consumeGuestClaimQuota({
    db,
    actorId: request.actorId,
    targetKey: claimTokenHash(request.claimCode),
    attemptedAt: claimedAt,
  });
  return db.runTransaction(async (transaction) => {
    const claimSnapshot = await claimCodeSnapshot({transaction, db, request});
    const claim = claimSnapshot.data();
    assertClaimTarget(claim, "guestPlayer");
    const player = await activeActorSnapshot({
      transaction,
      db,
      actorId: request.actorId,
    });
    const guest = await claimTargetForClaim({transaction, db, claim});
    await assertClaimProvenance({
      transaction,
      db,
      request,
      claimSnapshot,
      claim,
      target: guest,
    });
    if (claimIsExpired(claim, claimedAt)) {
      stageExpiredClaim({
        transaction,
        claimSnapshot,
        claim,
        target: guest,
        claimedAt,
      });
      return expiredClaimResponse("guestPlayer", claim.targetId);
    }
    assertClaimStatusSupportsConsume(claim);

    const identity = {
      guest,
      guestPlayer: guest.data(),
      player,
      registeredPlayer: player.data(),
    };
    const replay = guestPlayerReplay(identity, claim, request.actorId);
    if (replay != null) {
      return playerClaimResponse(identity, request.actorId, replay);
    }

    const roster = await guestPlayerRoster({
      transaction,
      db,
      identity,
      actorId: request.actorId,
    });
    const rosterConflict = activeRosterConflict(roster, request.actorId);
    if (rosterConflict != null) {
      return playerClaimResponse(identity, request.actorId, rosterConflict);
    }

    stageGuestPlayerClaim({
      transaction,
      db,
      request,
      claimSnapshot,
      claim,
      identity,
      roster,
      claimedAt,
    });
    return playerClaimedResponse(identity, roster, request.actorId);
  });
}

async function claimGuestTeamCore({db, actorId, payload, now}) {
  const claimedAt = trustedNow(now);
  const request = normalizedTeamConsumeRequest(payload, actorId);
  await consumeGuestClaimQuota({
    db,
    actorId: request.actorId,
    targetKey: claimTokenHash(request.claimCode),
    attemptedAt: claimedAt,
  });
  return db.runTransaction(async (transaction) => {
    const claimSnapshot = await claimCodeSnapshot({transaction, db, request});
    const claim = claimSnapshot.data();
    assertClaimTarget(claim, "guestTeam");
    await activeActorSnapshot({transaction, db, actorId: request.actorId});
    const guest = await claimTargetForClaim({transaction, db, claim});
    await assertClaimProvenance({
      transaction,
      db,
      request,
      claimSnapshot,
      claim,
      target: guest,
    });
    if (claimIsExpired(claim, claimedAt)) {
      stageExpiredClaim({
        transaction,
        claimSnapshot,
        claim,
        target: guest,
        claimedAt,
      });
      return expiredClaimResponse("guestTeam", claim.targetId);
    }
    assertClaimStatusSupportsConsume(claim);

    const identity = await guestTeamIdentity({
      transaction,
      db,
      request,
      claim,
      guest,
    });
    assertGuestTeamActor(identity);
    const replay = guestTeamReplay(identity, claim);
    if (replay != null) return teamClaimResponse(identity, claim, replay);
    const targetConflict = guestTeamTargetConflict(identity, claim);
    if (targetConflict != null) {
      return teamClaimResponse(identity, claim, targetConflict);
    }

    const nameConflict = await duplicateTeamName({transaction, db, identity});
    if (nameConflict != null) {
      return teamClaimResponse(identity, claim, nameConflict);
    }
    if (claim.requiresApproval === true) {
      const approval = stageTeamApprovalOrRequest({
        transaction,
        request,
        claimSnapshot,
        claim,
        identity,
        claimedAt,
      });
      if (approval != null) {
        return teamClaimResponse(identity, claim, approval);
      }
    } else if (claim.claimedByPlayerId &&
        claim.claimedByPlayerId !== request.actorId) {
      return teamClaimResponse(
        identity,
        claim,
        claimConflict("targetAlreadyLinked"),
      );
    } else if (!identity.actorOwnsTeam) {
      throw new GuestClaimError(
        "permission-denied",
        "Only the registered team owner can claim this guest team.",
      );
    }

    stageGuestTeamClaim({
      transaction,
      db,
      request,
      claimSnapshot,
      claim,
      identity,
      claimedAt,
    });
    return teamClaimedResponse(identity);
  });
}

function normalizedIssueRequest(payload, actorId) {
  const targetType = enumText(
    payload && payload.targetType,
    "targetType",
    CLAIM_TARGETS,
  );
  return {
    actorId: documentIdText(actorId, "actorId", 128),
    requestId: requestIdText(payload && payload.requestId),
    targetType,
    targetId: documentIdText(payload && payload.targetId, "targetId", 256),
    ttlMs: boundedTtl(payload && payload.ttlMs),
    requiresApproval: normalizedApproval(payload, targetType),
  };
}

function normalizedConsumeRequest(payload, actorId) {
  return {
    actorId: documentIdText(actorId, "actorId", 128),
    claimCode: claimCodeText(payload && payload.claimCode),
  };
}

function normalizedTeamConsumeRequest(payload, actorId) {
  return {
    ...normalizedConsumeRequest(payload, actorId),
    teamId: optionalDocumentIdText(payload && payload.teamId, "teamId", 256),
  };
}

function issueQuotaTargetKey(request) {
  return JSON.stringify([request.targetType, request.targetId]);
}

async function consumeGuestClaimQuota({db, actorId, targetKey, attemptedAt}) {
  const windowStart = Math.floor(attemptedAt / CLAIM_RATE_LIMIT_WINDOW_MS) *
    CLAIM_RATE_LIMIT_WINDOW_MS;
  const windowKey = String(windowStart);
  const targetHash = claimTokenHash(`guest-claim:${targetKey}`);
  return db.runTransaction(async (transaction) => {
    await activeActorSnapshot({transaction, db, actorId});
    const quotaRef = db.collection(COLLECTIONS.safetyActionQuotas).doc(actorId);
    const quotaSnapshot = await transaction.get(quotaRef);
    const current = quotaSnapshot.exists ? quotaSnapshot.data() : null;
    const quota = guestClaimQuotaState(current?.[CLAIM_RATE_LIMIT_SCOPE], windowKey);
    const nextQuota = incrementGuestClaimQuota(quota, targetHash);
    transaction.set(quotaRef, {
      ...(current || {}),
      schemaVersion: 1,
      [CLAIM_RATE_LIMIT_SCOPE]: nextQuota,
      createdAt: current?.createdAt ?? new Date(attemptedAt),
      updatedAt: new Date(attemptedAt),
    });
  });
}

function guestClaimQuotaState(current, windowKey) {
  if (current == null) return emptyGuestClaimQuota(windowKey);
  if (!validGuestClaimQuotaState(current)) {
    throw new GuestClaimError(
      "failed-precondition",
      "Guest claim rate limit state is invalid.",
    );
  }
  return current.windowKey === windowKey ?
    current : emptyGuestClaimQuota(windowKey);
}

function emptyGuestClaimQuota(windowKey) {
  return {windowKey, count: 0, revision: 0, targets: {}};
}

function validGuestClaimQuotaState(current) {
  if (!isPlainObject(current) || !isPlainObject(current.targets)) return false;
  if (!Object.keys(current).every((key) => (
    ["windowKey", "count", "revision", "targets"].includes(key)
  ))) return false;
  const entries = Object.entries(current.targets);
  const targetCountsAreValid = entries.every(([key, count]) => (
    /^[a-f0-9]{64}$/.test(key) && Number.isInteger(count) &&
    count > 0 && count <= MAX_CLAIM_ATTEMPTS_PER_TARGET
  ));
  const countedAttempts = entries.reduce((sum, entry) => sum + entry[1], 0);
  return typeof current.windowKey === "string" &&
    Number.isInteger(current.count) && current.count > 0 &&
    current.count <= MAX_CLAIM_ATTEMPTS_PER_WINDOW &&
    current.revision === current.count &&
    entries.length <= MAX_CLAIM_TARGETS_PER_WINDOW &&
    targetCountsAreValid && countedAttempts === current.count;
}

function incrementGuestClaimQuota(quota, targetHash) {
  const targetCount = quota.targets[targetHash] || 0;
  const isNewTarget = targetCount === 0;
  if (quota.count >= MAX_CLAIM_ATTEMPTS_PER_WINDOW ||
      targetCount >= MAX_CLAIM_ATTEMPTS_PER_TARGET ||
      (isNewTarget &&
       Object.keys(quota.targets).length >= MAX_CLAIM_TARGETS_PER_WINDOW)) {
    throw new GuestClaimError(
      "resource-exhausted",
      "Too many guest claim attempts. Try again later.",
    );
  }
  const count = quota.count + 1;
  return {
    windowKey: quota.windowKey,
    count,
    revision: count,
    targets: {...quota.targets, [targetHash]: targetCount + 1},
  };
}

function boundedTtl(candidate) {
  if (candidate == null) return DEFAULT_CLAIM_TTL_MS;
  if (!Number.isInteger(candidate) ||
      candidate < MIN_CLAIM_TTL_MS ||
      candidate > MAX_CLAIM_TTL_MS) {
    throw new GuestClaimError("invalid-argument", "ttlMs is out of range.");
  }
  return candidate;
}

function normalizedApproval(payload, targetType) {
  const candidate = payload && payload.requiresApproval;
  if (candidate == null) return targetType === "guestTeam";
  if (typeof candidate !== "boolean") {
    throw new GuestClaimError(
      "invalid-argument",
      "requiresApproval must be a boolean.",
    );
  }
  return candidate;
}

async function activeActorSnapshot({transaction, db, actorId}) {
  const playerRef = db.collection(COLLECTIONS.players).doc(actorId);
  const deletionRef = db
    .collection(COLLECTIONS.accountDeletionRequests)
    .doc(deletedAccountId(actorId));
  const [player, deletion] = await Promise.all([
    transaction.get(playerRef),
    transaction.get(deletionRef),
  ]);
  if (!player.exists || deletion.exists) {
    throw new GuestClaimError(
      "permission-denied",
      "An active player profile is required.",
    );
  }
  return player;
}

async function claimTargetSnapshot({transaction, db, request}) {
  const collection = request.targetType === "guestPlayer" ?
    COLLECTIONS.guestPlayers :
    COLLECTIONS.guestTeams;
  const target = await transaction.get(
    db.collection(collection).doc(request.targetId),
  );
  if (!target.exists) {
    throw new GuestClaimError("not-found", "Claim target not found.");
  }
  if (target.data().claimStatus === CLAIMED_STATUS) {
    throw new GuestClaimError(
      "failed-precondition",
      "Claim target has already been claimed.",
    );
  }
  return target;
}

async function assertIssuerAuthorization(issueContext) {
  const {request, target} = issueContext;
  if (request.targetType === "guestTeam") {
    if (target.creatorId !== request.actorId) {
      throw new GuestClaimError(
        "permission-denied",
        "Only the guest team creator can issue its claim code.",
      );
    }
    return;
  }
  if (target.createdBy === request.actorId) return;
  const related = await guestPlayerIssuerDocuments(issueContext);
  if (canManageGuestPlayerClaim(related, request.actorId)) {
    return;
  }
  throw new GuestClaimError(
    "permission-denied",
    "Actor cannot issue a claim code for this guest player.",
  );
}

async function guestPlayerIssuerDocuments({transaction, db, request, target}) {
  const tournamentId = isSafeDocumentId(target.tournamentId, 256) ?
    target.tournamentId.trim() : null;
  const tournamentRef = tournamentId ?
    db.collection(COLLECTIONS.tournaments).doc(tournamentId) : null;
  const references = [
    isSafeDocumentId(target.teamId, 256) ?
      db.collection(COLLECTIONS.teams).doc(target.teamId) : null,
    isSafeDocumentId(target.guestTeamId, 256) ?
      db.collection(COLLECTIONS.guestTeams).doc(target.guestTeamId) : null,
    tournamentRef,
    tournamentRef ?
      tournamentRef.collection("assistants").doc(request.actorId) : null,
  ];
  const snapshots = await Promise.all(references.map((reference) => (
    reference == null ? Promise.resolve(null) : transaction.get(reference)
  )));
  return {
    team: existingDocument(snapshots[0]),
    guestTeam: existingDocument(snapshots[1]),
    tournament: existingDocument(snapshots[2]),
    assistant: existingDocument(snapshots[3]),
    tournamentId,
  };
}

function canManageGuestPlayerClaim(related, actorId) {
  if (related.team && (
    related.team.ownerId === actorId ||
    stringList(related.team.viceCaptainIds).includes(actorId)
  )) return true;
  if (related.guestTeam && related.guestTeam.creatorId === actorId) return true;
  if (!related.tournament) return false;
  if (related.tournament.organizerId === actorId) return true;
  return related.assistant &&
    related.assistant.userId === actorId &&
    related.assistant.tournamentId === related.tournamentId &&
    related.assistant.status === "active" &&
    isPlainObject(related.assistant.permissions) &&
    related.assistant.permissions.canManageGuestRoster === true;
}

async function activeClaimsForTarget({transaction, db, request}) {
  const query = db.collection(COLLECTIONS.claimCodes)
    .where("createdBy", "==", request.actorId)
    .where("targetType", "==", request.targetType)
    .where("targetId", "==", request.targetId)
    .where("status", "==", ACTIVE_CLAIM_STATUS)
    .orderBy("createdAt", "desc")
    .limit(MAX_ACTIVE_CLAIMS_PER_TARGET + 1);
  return transaction.get(query);
}

function reusableIssuedClaim({tokenSnapshot, claim, issuedAt}) {
  if (!tokenSnapshot.exists) return false;
  const stored = tokenSnapshot.data();
  return stored.status === ACTIVE_CLAIM_STATUS &&
    validExpiry(stored.expiresAt) > issuedAt &&
    stored.tokenVersion === CLAIM_TOKEN_VERSION &&
    stored.issuanceRequestIdHash === claim.issuanceRequestIdHash &&
    stored.issuanceRequestHash === claim.issuanceRequestHash &&
    stored.targetType === claim.targetType &&
    stored.targetId === claim.targetId &&
    stored.scope === claim.scope &&
    (stored.teamId || null) === (claim.teamId || null) &&
    (stored.tournamentId || null) === (claim.tournamentId || null) &&
    stored.createdBy === claim.createdBy &&
    stored.requiresApproval === claim.requiresApproval;
}

function expireSupersededClaims({
  transaction,
  claimSnapshots,
  reusableId,
  issuedAt,
}) {
  for (const snapshot of claimSnapshots) {
    if (snapshot.id === reusableId) continue;
    if (!snapshot.exists || snapshot.data().status !== ACTIVE_CLAIM_STATUS) {
      continue;
    }
    transaction.update(snapshot.ref, {status: "expired", updatedAt: issuedAt});
  }
}

async function referencedTargetClaims({
  transaction,
  db,
  target,
  tokenHash,
}) {
  const claimCodes = db.collection(COLLECTIONS.claimCodes);
  const targetData = target.data();
  const references = [];
  if (isTokenHash(targetData.activeClaimTokenHash) &&
      targetData.activeClaimTokenHash !== tokenHash) {
    references.push(claimCodes.doc(targetData.activeClaimTokenHash.trim()));
  }
  if (isStoredClaimCode(targetData.claimCode)) {
    references.push(claimCodes.doc(targetData.claimCode.trim()));
  }
  return Promise.all(uniqueDocumentReferences(references).map((reference) => (
    transaction.get(reference)
  )));
}

function repairInvitedTarget({transaction, target, tokenHash, issuedAt}) {
  if (target.data().claimStatus === "invited" &&
      target.data().claimCode == null &&
      target.data().activeClaimTokenHash === tokenHash) {
    return;
  }
  stageNewInviteTarget({transaction, target, tokenHash, issuedAt});
}

function stageNewInviteTarget({transaction, target, tokenHash, issuedAt}) {
  transaction.update(target.ref, {
    claimStatus: "invited",
    claimCode: null,
    activeClaimTokenHash: tokenHash,
    updatedAt: issuedAt,
  });
}

function newClaimDocument({request, target, issuedAt}) {
  const scope = claimScope(target);
  return {
    targetType: request.targetType,
    targetId: request.targetId,
    scope,
    teamId: request.targetType === "guestPlayer" &&
      isSafeDocumentId(target.teamId, 256) ? target.teamId.trim() : null,
    tournamentId: claimTournamentId(target),
    createdBy: request.actorId,
    requiresApproval: request.requiresApproval,
    status: ACTIVE_CLAIM_STATUS,
    createdAt: issuedAt,
    updatedAt: issuedAt,
    expiresAt: issuedAt + request.ttlMs,
    claimedByPlayerId: null,
    claimedAt: null,
    tokenVersion: CLAIM_TOKEN_VERSION,
    issuanceRequestIdHash: requestIdHash(request.requestId),
    issuanceRequestHash: issueRequestHash(request),
  };
}

function claimScope(target) {
  const hasTeam = isSafeDocumentId(target.teamId, 256);
  const hasTournament = nonEmptyText(claimTournamentId(target));
  if (hasTeam && hasTournament) return "hybrid";
  if (hasTournament) return "tournament";
  if (hasTeam) return "team";
  return "publicShare";
}

function claimTournamentId(target) {
  if (isSafeDocumentId(target.tournamentId, 256)) {
    return target.tournamentId.trim();
  }
  return stringList(target.tournamentIds)
    .find((tournamentId) => isSafeDocumentId(tournamentId, 256)) || null;
}

function issuedClaimResponse({code, claim, reused}) {
  return {
    code,
    targetType: claim.targetType,
    targetId: claim.targetId,
    scope: claim.scope,
    teamId: claim.teamId || null,
    tournamentId: claim.tournamentId || null,
    requiresApproval: claim.requiresApproval === true,
    status: claim.status,
    expiresAt: claim.expiresAt,
    reused,
  };
}

async function claimCodeSnapshot({transaction, db, request}) {
  const claimCodes = db.collection(COLLECTIONS.claimCodes);
  const tokenHash = claimTokenHash(request.claimCode);
  const hashedRef = claimCodes.doc(tokenHash);
  const hashedSnapshot = await transaction.get(hashedRef);
  if (hashedSnapshot.exists) {
    return resolvedClaimSnapshot({
      snapshot: hashedSnapshot,
      hashedRef,
      tokenHash,
      isLegacy: false,
    });
  }
  const legacySnapshot = await transaction.get(
    claimCodes.doc(request.claimCode),
  );
  if (!legacySnapshot.exists) {
    throw new GuestClaimError("not-found", "Claim code not found.");
  }
  return resolvedClaimSnapshot({
    snapshot: legacySnapshot,
    hashedRef,
    tokenHash,
    isLegacy: true,
  });
}

function resolvedClaimSnapshot({snapshot, hashedRef, tokenHash, isLegacy}) {
  return {
    id: snapshot.id,
    ref: snapshot.ref,
    exists: snapshot.exists,
    data: () => snapshot.data(),
    hashedRef,
    tokenHash,
    isLegacy,
  };
}

async function assertClaimProvenance(provenance) {
  const {transaction, db, request, claimSnapshot, claim, target} = provenance;
  if (claimSnapshot.isLegacy) {
    assertLegacyClaimDocument({request, claim, target});
    await assertIssuerAuthorization({
      transaction,
      db,
      request: {
        actorId: claim.createdBy,
        targetType: claim.targetType,
        targetId: claim.targetId,
      },
      target: target.data(),
      issuedAt: claim.createdAt,
    });
    return;
  }
  const isTrustedToken = claim.tokenVersion === CLAIM_TOKEN_VERSION ||
    claim.legacyValidated === true;
  if (!isTrustedToken) {
    throw invalidClaimProvenance();
  }
  if (claim.status === ACTIVE_CLAIM_STATUS &&
      target.data().activeClaimTokenHash !== claimSnapshot.tokenHash) {
    throw invalidClaimProvenance();
  }
}

function assertLegacyClaimDocument({request, claim, target}) {
  const legacySchemaIsValid = claim.tokenVersion == null &&
    isSafeDocumentId(claim.createdBy, 128) &&
    CLAIM_SCOPES.has(claim.scope) &&
    isOptionalDocumentId(claim.teamId, 256) &&
    isOptionalDocumentId(claim.tournamentId, 256) &&
    isOptionalDocumentId(claim.claimedByPlayerId, 128) &&
    Number.isFinite(claim.createdAt) &&
    Number.isFinite(claim.updatedAt) &&
    Number.isFinite(claim.expiresAt) &&
    claim.updatedAt >= claim.createdAt &&
    claim.expiresAt > claim.createdAt &&
    typeof claim.requiresApproval === "boolean" &&
    [ACTIVE_CLAIM_STATUS, CLAIMED_STATUS, "expired"].includes(claim.status);
  const targetStillCarriesToken = target.data().claimCode === request.claimCode;
  if (!legacySchemaIsValid || !targetStillCarriesToken) {
    throw invalidClaimProvenance();
  }
}

function invalidClaimProvenance() {
  return new GuestClaimError(
    "failed-precondition",
    "Claim code is not the current trusted token for this target.",
  );
}

function assertClaimTarget(claim, expectedTarget) {
  if (claim.targetType !== expectedTarget ||
      !isSafeDocumentId(claim.targetId, 256)) {
    throw new GuestClaimError(
      "failed-precondition",
      `Claim code does not target a ${expectedTarget}.`,
    );
  }
}

function claimIsExpired(claim, claimedAt) {
  return claim.status === ACTIVE_CLAIM_STATUS &&
    validExpiry(claim.expiresAt) <= claimedAt;
}

function stageExpiredClaim({
  transaction,
  claimSnapshot,
  claim,
  target,
  claimedAt,
}) {
  stageClaimMutation({
    transaction,
    claimSnapshot,
    claim,
    changedAt: claimedAt,
    patch: {
      status: "expired",
      updatedAt: claimedAt,
    },
  });
  clearClaimTargetBinding({
    transaction,
    target,
    claimSnapshot,
    changedAt: claimedAt,
  });
}

function assertClaimStatusSupportsConsume(claim) {
  if (claim.status === ACTIVE_CLAIM_STATUS) return;
  if (claim.status === CLAIMED_STATUS) return;
  throw new GuestClaimError(
    "failed-precondition",
    "Claim code is not active.",
  );
}

function guestPlayerReplay(identity, claim, actorId) {
  const linkedPlayerId = identity.guestPlayer.linkedPlayerId;
  if (identity.guestPlayer.claimStatus === CLAIMED_STATUS &&
      linkedPlayerId === actorId &&
      claim.status === CLAIMED_STATUS &&
      claim.claimedByPlayerId === actorId) {
    return {outcome: "alreadyClaimed", duplicate: true};
  }
  if (linkedPlayerId && linkedPlayerId !== actorId) {
    return claimConflict("targetAlreadyLinked");
  }
  if (claim.claimedByPlayerId && claim.claimedByPlayerId !== actorId) {
    return claimConflict("targetAlreadyLinked");
  }
  if (claim.status === CLAIMED_STATUS) {
    throw new GuestClaimError(
      "failed-precondition",
      "Claim code state does not match the guest player.",
    );
  }
  return null;
}

async function guestPlayerRoster({transaction, db, identity, actorId}) {
  const guestMemberships = await transaction.get(
    db.collection(COLLECTIONS.teamMemberships)
      .where("guestPlayerId", "==", identity.guest.id)
      .limit(MAX_CLAIM_MEMBERSHIPS + 1),
  );
  const playerMemberships = await transaction.get(
    db.collection(COLLECTIONS.teamMemberships)
      .where("playerId", "==", actorId)
      .limit(MAX_CLAIM_MEMBERSHIPS + 1),
  );
  if (guestMemberships.docs.length > MAX_CLAIM_MEMBERSHIPS ||
      playerMemberships.docs.length > MAX_CLAIM_MEMBERSHIPS) {
    throw new GuestClaimError(
      "resource-exhausted",
      "Claim roster exceeds the supported membership limit.",
    );
  }
  const activeGuestMemberships = guestMemberships.docs.filter(
    (snapshot) => isActiveMembership(snapshot.data()),
  );
  const teamIds = uniqueStrings([
    ...activeGuestMemberships.map((snapshot) => snapshot.data().teamId),
  ]).filter((teamId) => isSafeDocumentId(teamId, 256));
  const teamSnapshots = await Promise.all(teamIds.map((teamId) => (
    transaction.get(db.collection(COLLECTIONS.teams).doc(teamId))
  )));
  const legacyTeamUpdates = teamSnapshots.filter((snapshot) => (
    snapshot.exists &&
    !stringList(snapshot.data().playerIds).includes(actorId)
  ));
  return {
    guestMemberships: guestMemberships.docs,
    activeGuestMemberships,
    playerMemberships,
    teamIds,
    legacyTeamUpdates,
  };
}

function activeRosterConflict(roster, actorId) {
  const activeByTeam = new Set(
    roster.playerMemberships.docs
      .filter((snapshot) => (
        snapshot.data().playerId === actorId &&
        isActiveMembership(snapshot.data())
      ))
      .map((snapshot) => snapshot.data().teamId),
  );
  const conflict = roster.activeGuestMemberships.find((snapshot) => (
    activeByTeam.has(snapshot.data().teamId)
  ));
  return conflict ? claimConflict("rosterAlreadyContainsPlayer") : null;
}

function stageGuestPlayerClaim(claimRequest) {
  const {
    transaction,
    db,
    request,
    claimSnapshot,
    claim,
    identity,
    roster,
    claimedAt,
  } = claimRequest;
  for (const membership of roster.guestMemberships) {
    transaction.update(membership.ref, {
      playerId: request.actorId,
      guestPlayerId: null,
      claimedFromGuestPlayerId: identity.guest.id,
      updatedAt: claimedAt,
    });
  }
  const linkedTeamIds = uniqueStrings([
    ...stringList(identity.registeredPlayer.teamIds),
    ...roster.teamIds,
  ]);
  transaction.update(identity.player.ref, {
    teamIds: linkedTeamIds,
    lastActiveAt: claimedAt,
  });
  stageLegacyTeamPlayers({transaction, roster, actorId: request.actorId});
  transaction.update(identity.guest.ref, {
    claimStatus: CLAIMED_STATUS,
    claimCode: null,
    activeClaimTokenHash: null,
    linkedPlayerId: request.actorId,
    phoneNumber: null,
    updatedAt: claimedAt,
  });
  stageConsumedClaim({
    transaction,
    claimSnapshot,
    claim,
    actorId: request.actorId,
    claimedAt,
  });
  appendClaimAudits({
    transaction,
    db,
    action: "guestPlayerClaimed",
    entityType: "guestPlayer",
    entityId: identity.guest.id,
    actorId: request.actorId,
    claimCode: request.claimCode,
    targetType: claim.targetType,
    previousClaimStatus: identity.guestPlayer.claimStatus,
    claimedAt,
  });
}

function stageLegacyTeamPlayers({transaction, roster, actorId}) {
  for (const team of roster.legacyTeamUpdates) {
    const playerIds = uniqueStrings([...stringList(team.data().playerIds), actorId]);
    transaction.update(team.ref, {playerIds});
  }
}

async function guestTeamIdentity({transaction, db, request, claim, guest}) {
  const teamId = request.teamId || optionalBoundedText(claim.teamId, "teamId", 256);
  if (!teamId) {
    throw new GuestClaimError("invalid-argument", "teamId is required.");
  }
  if (claim.teamId && claim.teamId !== teamId) {
    return {
      requestedTeamMismatch: true,
      requestedTeamId: claim.teamId,
      teamId,
      guest,
      guestTeam: guest.data(),
    };
  }
  const teamRef = db.collection(COLLECTIONS.teams).doc(teamId);
  const team = await transaction.get(teamRef);
  if (!team.exists) {
    throw new GuestClaimError("not-found", "Registered team not found.");
  }
  return {
    guest,
    guestTeam: guest.data(),
    team,
    registeredTeam: team.data(),
    teamId,
    actorOwnsTeam: team.data().ownerId === request.actorId,
    actorIsGuestCreator: guest.data().creatorId === request.actorId,
  };
}

function assertGuestTeamActor(identity) {
  if (identity.requestedTeamMismatch) return;
  if (identity.actorOwnsTeam || identity.actorIsGuestCreator) return;
  throw new GuestClaimError(
    "permission-denied",
    "Actor cannot claim this guest team.",
  );
}

function guestTeamReplay(identity, claim) {
  if (identity.requestedTeamMismatch) return null;
  const linkedTeamId = identity.guestTeam.linkedTeamId;
  if (identity.guestTeam.claimStatus === CLAIMED_STATUS &&
      linkedTeamId === identity.teamId &&
      claim.status === CLAIMED_STATUS &&
      claim.teamId === identity.teamId) {
    return {outcome: "alreadyClaimed", duplicate: true};
  }
  return null;
}

function guestTeamTargetConflict(identity, claim) {
  if (identity.requestedTeamMismatch) {
    return claimConflict("pendingTargetLink");
  }
  if (identity.guestTeam.linkedTeamId &&
      identity.guestTeam.linkedTeamId !== identity.teamId) {
    return claimConflict("targetAlreadyLinked");
  }
  if (claim.status === CLAIMED_STATUS && claim.teamId !== identity.teamId) {
    return claimConflict("targetAlreadyLinked");
  }
  if (claim.status === CLAIMED_STATUS) {
    throw new GuestClaimError(
      "failed-precondition",
      "Claim code state does not match the guest team.",
    );
  }
  return null;
}

async function duplicateTeamName({transaction, db, identity}) {
  if (!nonEmptyText(identity.guestTeam.normalizedName)) return null;
  const matches = await transaction.get(
    db.collection(COLLECTIONS.teams)
      .where("nameLower", "==", identity.guestTeam.normalizedName.trim())
      .limit(3),
  );
  const duplicate = matches.docs.find((snapshot) => snapshot.id !== identity.teamId);
  return duplicate ? claimConflict("duplicateName") : null;
}

function stageTeamApprovalOrRequest(approvalRequest) {
  const {transaction, request, claimSnapshot, claim, identity, claimedAt} =
    approvalRequest;
  if (identity.actorIsGuestCreator) {
    if (identity.actorOwnsTeam) return null;
    if (!claim.teamId || !claim.claimedByPlayerId) {
      throw new GuestClaimError(
        "failed-precondition",
        "No pending team claim request exists.",
      );
    }
    if (identity.registeredTeam.ownerId !== claim.claimedByPlayerId) {
      throw new GuestClaimError(
        "failed-precondition",
        "Pending claimant no longer owns the registered team.",
      );
    }
    return null;
  }
  if (!identity.actorOwnsTeam) {
    throw new GuestClaimError(
      "permission-denied",
      "Only the registered team owner can request approval.",
    );
  }
  if (claim.claimedByPlayerId && claim.claimedByPlayerId !== request.actorId) {
    return claimConflict("pendingTargetLink");
  }
  if (claim.teamId === identity.teamId &&
      claim.claimedByPlayerId === request.actorId) {
    return teamApprovalResponse({duplicate: true});
  }
  stageActiveClaimTargetBinding({
    transaction,
    target: identity.guest,
    claimSnapshot,
    changedAt: claimedAt,
  });
  stageClaimMutation({
    transaction,
    claimSnapshot,
    claim,
    changedAt: claimedAt,
    patch: {
      teamId: identity.teamId,
      claimedByPlayerId: request.actorId,
      updatedAt: claimedAt,
    },
  });
  return teamApprovalResponse({duplicate: false});
}

function stageActiveClaimTargetBinding({
  transaction,
  target,
  claimSnapshot,
  changedAt,
}) {
  if (target.data().claimCode == null &&
      target.data().activeClaimTokenHash === claimSnapshot.tokenHash) {
    return;
  }
  transaction.update(target.ref, {
    claimCode: null,
    activeClaimTokenHash: claimSnapshot.tokenHash,
    updatedAt: changedAt,
  });
}

function stageGuestTeamClaim(claimRequest) {
  const {
    transaction,
    db,
    request,
    claimSnapshot,
    claim,
    identity,
    claimedAt,
  } = claimRequest;
  const mergedTournamentIds = uniqueStrings([
    ...stringList(identity.registeredTeam.tournamentIds),
    ...stringList(identity.guestTeam.tournamentIds),
  ]);
  transaction.update(identity.team.ref, {tournamentIds: mergedTournamentIds});
  transaction.update(identity.guest.ref, {
    claimStatus: CLAIMED_STATUS,
    claimCode: null,
    activeClaimTokenHash: null,
    linkedTeamId: identity.teamId,
    updatedAt: claimedAt,
  });
  stageConsumedClaim({
    transaction,
    claimSnapshot,
    claim,
    actorId: claim.claimedByPlayerId || request.actorId,
    teamId: identity.teamId,
    claimedAt,
  });
  appendClaimAudits({
    transaction,
    db,
    action: "guestTeamClaimed",
    entityType: "guestTeam",
    entityId: identity.guest.id,
    actorId: request.actorId,
    claimCode: request.claimCode,
    targetType: claim.targetType,
    previousClaimStatus: identity.guestTeam.claimStatus,
    claimedAt,
  });
}

function stageConsumedClaim({
  transaction,
  claimSnapshot,
  claim,
  actorId,
  claimedAt,
  teamId,
}) {
  stageClaimMutation({
    transaction,
    claimSnapshot,
    claim,
    changedAt: claimedAt,
    patch: {
      status: CLAIMED_STATUS,
      claimedByPlayerId: actorId,
      claimedAt,
      updatedAt: claimedAt,
      ...(teamId ? {teamId} : {}),
    },
  });
}

function stageClaimMutation({
  transaction,
  claimSnapshot,
  claim,
  patch,
  changedAt,
}) {
  if (!claimSnapshot.isLegacy) {
    transaction.update(claimSnapshot.ref, patch);
    return;
  }
  transaction.create(claimSnapshot.hashedRef, {
    ...canonicalLegacyClaimDocument(claim),
    ...patch,
    tokenVersion: 1,
    legacyValidated: true,
    legacyMigratedAt: changedAt,
  });
  transaction.delete(claimSnapshot.ref);
}

function canonicalLegacyClaimDocument(claim) {
  return {
    targetType: claim.targetType,
    targetId: claim.targetId,
    scope: claim.scope,
    teamId: nonEmptyText(claim.teamId) ? claim.teamId.trim() : null,
    tournamentId: nonEmptyText(claim.tournamentId) ?
      claim.tournamentId.trim() : null,
    createdBy: claim.createdBy.trim(),
    requiresApproval: claim.requiresApproval,
    status: claim.status,
    createdAt: claim.createdAt,
    updatedAt: claim.updatedAt,
    expiresAt: claim.expiresAt,
    claimedByPlayerId: nonEmptyText(claim.claimedByPlayerId) ?
      claim.claimedByPlayerId.trim() : null,
    claimedAt: Number.isFinite(claim.claimedAt) ? claim.claimedAt : null,
  };
}

function clearClaimTargetBinding({
  transaction,
  target,
  claimSnapshot,
  changedAt,
}) {
  const targetData = target.data();
  const ownsLegacyBinding = claimSnapshot.isLegacy &&
    targetData.claimCode === claimSnapshot.id;
  const ownsHashedBinding =
    targetData.activeClaimTokenHash === claimSnapshot.tokenHash;
  if (!ownsLegacyBinding && !ownsHashedBinding) return;
  transaction.update(target.ref, {
    claimCode: null,
    activeClaimTokenHash: null,
    updatedAt: changedAt,
  });
}

function appendClaimAudits(auditRequest) {
  const tokenDigest = claimTokenDigest(auditRequest.claimCode);
  appendClaimAuditEvent({
    ...auditRequest,
    requestId: `claim:${tokenDigest}:${auditRequest.action}`,
    beforePayload: {claimStatus: auditRequest.previousClaimStatus || "guest"},
    afterPayload: {claimStatus: CLAIMED_STATUS},
    metadata: null,
  });
  appendClaimAuditEvent({
    ...auditRequest,
    action: "claimCodeConsumed",
    entityType: "claimCode",
    entityId: `claim-token-${tokenDigest}`,
    requestId: `claim:${tokenDigest}:claimCodeConsumed`,
    beforePayload: {status: ACTIVE_CLAIM_STATUS},
    afterPayload: {status: CLAIMED_STATUS},
    metadata: {targetType: auditRequest.targetType},
  });
}

function appendClaimAuditEvent(auditEvent) {
  appendAuditEvent({
    transaction: auditEvent.transaction,
    db: auditEvent.db,
    entityType: auditEvent.entityType,
    entityId: auditEvent.entityId,
    action: auditEvent.action,
    actorId: auditEvent.actorId,
    beforePayload: auditEvent.beforePayload,
    afterPayload: auditEvent.afterPayload,
    metadata: auditEvent.metadata,
    requestId: auditEvent.requestId,
    createdAt: auditEvent.claimedAt,
  });
}

function playerClaimedResponse(identity, roster, actorId) {
  return {
    outcome: "claimed",
    guestPlayerId: identity.guest.id,
    playerId: actorId,
    relinkedMembershipIds: roster.guestMemberships.map(
      (entry) => entry.id,
    ),
    linkedTeamIds: uniqueStrings([
      ...stringList(identity.registeredPlayer.teamIds),
      ...roster.teamIds,
    ]),
    syncedLegacyTeamIds: roster.legacyTeamUpdates.map((snapshot) => snapshot.id),
    duplicate: false,
  };
}

function playerClaimResponse(identity, actorId, response) {
  return {
    guestPlayerId: identity.guest.id,
    playerId: actorId,
    relinkedMembershipIds: [],
    linkedTeamIds: stringList(identity.registeredPlayer.teamIds),
    syncedLegacyTeamIds: [],
    ...response,
  };
}

function teamClaimedResponse(identity) {
  return {
    outcome: "claimed",
    guestTeamId: identity.guest.id,
    teamId: identity.teamId,
    mergedTournamentIds: uniqueStrings([
      ...stringList(identity.registeredTeam.tournamentIds),
      ...stringList(identity.guestTeam.tournamentIds),
    ]),
    requestedByPlayerId: null,
    duplicate: false,
  };
}

function teamClaimResponse(identity, claim, response) {
  const hasLoadedTeam = !identity.requestedTeamMismatch;
  return {
    guestTeamId: hasLoadedTeam ? identity.guest.id : claim.targetId,
    teamId: identity.teamId,
    mergedTournamentIds: hasLoadedTeam ? uniqueStrings([
      ...stringList(identity.registeredTeam.tournamentIds),
      ...stringList(identity.guestTeam.tournamentIds),
    ]) : [],
    requestedByPlayerId: null,
    ...response,
  };
}

function teamApprovalResponse({duplicate}) {
  return {
    outcome: "approvalRequired",
    requestedByPlayerId: null,
    duplicate,
  };
}

function expiredClaimResponse(targetType, targetId) {
  return {outcome: "expired", targetType, targetId, duplicate: false};
}

function claimConflict(conflictType) {
  return {
    outcome: "conflict",
    conflict: {
      type: conflictType,
      conflictingEntityId: null,
    },
    duplicate: false,
  };
}

function claimTokenDigest(claimCode) {
  return claimTokenHash(claimCode).slice(0, 32);
}

function claimTokenHash(claimCode) {
  return crypto.createHash("sha256").update(claimCode).digest("hex");
}

function issuedClaimToken(request, tokenSecret) {
  const secret = normalizedTokenSecret(tokenSecret);
  return crypto.createHmac("sha256", secret)
    .update(JSON.stringify([
      CLAIM_TOKEN_VERSION,
      request.actorId,
      request.targetType,
      request.targetId,
      request.requestId,
    ]))
    .digest("base64url");
}

function normalizedTokenSecret(candidate) {
  if ((typeof candidate !== "string" && !Buffer.isBuffer(candidate)) ||
      Buffer.byteLength(candidate) < 32) {
    throw new GuestClaimError(
      "failed-precondition",
      "A server claim-token secret of at least 32 bytes is required.",
    );
  }
  return candidate;
}

function requestIdText(candidate) {
  const requestId = boundedText(candidate, "requestId", 128);
  if (requestId.length < 16 || !/^[A-Za-z0-9_-]+$/.test(requestId)) {
    throw new GuestClaimError("invalid-argument", "requestId is invalid.");
  }
  return requestId;
}

function requestIdHash(requestId) {
  return crypto.createHash("sha256").update(requestId).digest("hex");
}

function issueRequestHash(request) {
  return crypto.createHash("sha256")
    .update(JSON.stringify({
      targetType: request.targetType,
      targetId: request.targetId,
      ttlMs: request.ttlMs,
      requiresApproval: request.requiresApproval,
    }))
    .digest("hex");
}

function claimCodeText(candidate) {
  const token = boundedText(candidate, "claimCode", 128);
  if (!/^[A-Za-z0-9_-]+$/.test(token)) {
    throw new GuestClaimError("invalid-argument", "claimCode is invalid.");
  }
  return token;
}

function enumText(candidate, fieldName, allowed) {
  const normalized = boundedText(candidate, fieldName, 64);
  if (!allowed.has(normalized)) {
    throw new GuestClaimError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function boundedText(candidate, fieldName, maxLength) {
  if (typeof candidate !== "string") {
    throw new GuestClaimError(
      "invalid-argument",
      `${fieldName} must be a string.`,
    );
  }
  const normalized = candidate.trim();
  if (!normalized || normalized.length > maxLength) {
    throw new GuestClaimError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function optionalBoundedText(candidate, fieldName, maxLength) {
  if (candidate == null || candidate === "") return null;
  return boundedText(candidate, fieldName, maxLength);
}

function documentIdText(candidate, fieldName, maxLength) {
  const normalized = boundedText(candidate, fieldName, maxLength);
  if (normalized.includes("/")) {
    throw new GuestClaimError("invalid-argument", `${fieldName} is invalid.`);
  }
  return normalized;
}

function optionalDocumentIdText(candidate, fieldName, maxLength) {
  if (candidate == null || candidate === "") return null;
  return documentIdText(candidate, fieldName, maxLength);
}

function trustedNow(now) {
  if (typeof now !== "function") {
    throw new GuestClaimError("internal", "A trusted clock is required.");
  }
  const timestamp = now();
  if (!Number.isFinite(timestamp) || timestamp < 0) {
    throw new GuestClaimError("internal", "Trusted clock returned invalid time.");
  }
  return timestamp;
}

function validExpiry(candidate) {
  if (!Number.isFinite(candidate) || candidate < 0) {
    throw new GuestClaimError(
      "failed-precondition",
      "Claim code has an invalid expiry.",
    );
  }
  return candidate;
}

function nonEmptyText(candidate) {
  return typeof candidate === "string" && candidate.trim().length > 0;
}

function isSafeDocumentId(candidate, maxLength) {
  return nonEmptyText(candidate) &&
    candidate.trim().length <= maxLength &&
    !candidate.includes("/");
}

function isOptionalDocumentId(candidate, maxLength) {
  return candidate == null || candidate === "" ||
    isSafeDocumentId(candidate, maxLength);
}

function isActiveMembership(membership) {
  return ACTIVE_MEMBERSHIP_STATUSES.has(membership.status);
}

function isTokenHash(candidate) {
  return typeof candidate === "string" && /^[a-f0-9]{64}$/.test(candidate);
}

function isStoredClaimCode(candidate) {
  return typeof candidate === "string" &&
    candidate.length <= 128 &&
    /^[A-Za-z0-9_-]+$/.test(candidate);
}

function uniqueStrings(candidates) {
  return [...new Set(candidates.filter(nonEmptyText).map((entry) => entry.trim()))];
}

function stringList(candidate) {
  return Array.isArray(candidate) ? candidate.filter(nonEmptyText) : [];
}

function uniqueDocumentReferences(references) {
  const unique = new Map();
  for (const reference of references) unique.set(reference.path, reference);
  return [...unique.values()];
}

function uniqueDocumentSnapshots(snapshots) {
  const unique = new Map();
  for (const snapshot of snapshots) unique.set(snapshot.ref.path, snapshot);
  return [...unique.values()];
}

function isPlainObject(candidate) {
  if (!candidate || typeof candidate !== "object") return false;
  const prototype = Object.getPrototypeOf(candidate);
  return prototype === Object.prototype || prototype === null;
}

function existingDocument(snapshot) {
  return snapshot && snapshot.exists ? snapshot.data() : null;
}

class GuestClaimError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

module.exports = {
  claimGuestPlayerCore,
  claimGuestTeamCore,
  inspectGuestClaimCore,
  issueGuestClaimCodeCore,
  GuestClaimError,
};
