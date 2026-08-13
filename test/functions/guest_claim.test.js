const assert = require('assert');
const crypto = require('crypto');

const {
  claimGuestPlayerCore,
  claimGuestTeamCore,
  GuestClaimError,
  inspectGuestClaimCore,
  issueGuestClaimCodeCore,
} = require('../../functions/guest_claim');
const {FakeFirestore} = require('./support/fake_firestore');

const NOW = Date.UTC(2026, 7, 1, 18);
const PLAYER_TOKEN = 'PLAYERCLAIMTOKEN2026';
const TEAM_TOKEN = 'TEAMCLAIMTOKEN2026';
const TOKEN_SECRET = 'test-only-claim-secret-at-least-32-bytes';
const ISSUE_REQUEST_ID = 'issue-request-00000001';

installFakeQueryOrderBy();

describe('trusted guest claim code issuance', () => {
  it('issues one server-owned token without copying the secret to the guest profile', async () => {
    const db = new FakeFirestore({
      'players/organizer-1': player(),
      'guestPlayers/guest-1': guestPlayer({createdBy: 'organizer-1'}),
    });
    const issue = (issuedAt) => issueGuestClaimCodeCore({
      db,
      actorId: 'organizer-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: ISSUE_REQUEST_ID,
      },
      now: () => issuedAt,
      tokenSecret: TOKEN_SECRET,
    });

    const first = await issue(NOW);
    const replay = await issue(NOW + 1);

    assert.strictEqual(first.reused, false);
    assert.strictEqual(replay.code, first.code);
    assert.strictEqual(replay.reused, true);
    assert.strictEqual(db.collectionData('claimCodes').length, 1);
    const tokenHash = sha256(first.code);
    assert.strictEqual(db.docData(`claimCodes/${tokenHash}`).status, 'active');
    assert.strictEqual(db.docData(`claimCodes/${first.code}`), undefined);
    assert.strictEqual(db.docData('guestPlayers/guest-1').claimCode, null);
    assert.strictEqual(
      db.docData('guestPlayers/guest-1').activeClaimTokenHash,
      tokenHash,
    );
    assert.strictEqual(db.docData('guestPlayers/guest-1').claimStatus, 'invited');
    assert.strictEqual(db.docData('guestPlayers/guest-1').updatedAt, NOW);
    assert.strictEqual(db.docData(`claimCodes/${tokenHash}`).updatedAt, NOW);
    assert.match(
      db.docData(`claimCodes/${tokenHash}`).issuanceRequestHash,
      /^[a-f0-9]{64}$/,
    );
    assert.strictEqual(
      JSON.stringify(db.collectionData('claimCodes')).includes(first.code),
      false,
    );

    const inspected = await inspectGuestClaimCore({
      db,
      actorId: 'organizer-1',
      payload: {claimCode: first.code},
      now: () => NOW,
    });
    assert.strictEqual(inspected.targetType, 'guestPlayer');
    assert.strictEqual(inspected.targetId, 'guest-1');
    assert.strictEqual(inspected.subjectName, 'Guest Hero');
    assert.strictEqual(inspected.canApprovePendingTeamClaim, false);
    assert.strictEqual(inspected.status, 'active');
  });

  it('limits repeated claim attempts for one actor and target per hour', async () => {
    const db = new FakeFirestore({
      'players/organizer-1': player(),
      'guestPlayers/guest-1': guestPlayer({createdBy: 'organizer-1'}),
    });
    const issue = () => issueGuestClaimCodeCore({
      db,
      actorId: 'organizer-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: ISSUE_REQUEST_ID,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });

    for (let attempt = 0; attempt < 24; attempt += 1) {
      await issue();
    }

    await assert.rejects(
      issue,
      (error) => error instanceof GuestClaimError &&
        error.code === 'resource-exhausted',
    );
    const quota = db.docData('safetyActionQuotas/organizer-1').guestClaim;
    assert.strictEqual(quota.count, 24);
    assert.strictEqual(quota.revision, 24);
    assert.strictEqual(Object.keys(quota.targets).length, 1);
    assert.strictEqual(db.collectionData('claimCodes').length, 1);
  });

  it('counts an invalid token attempt without creating claim state', async () => {
    const db = new FakeFirestore({'players/player-1': player()});

    await assert.rejects(
      () => inspectGuestClaimCore({
        db,
        actorId: 'player-1',
        payload: {claimCode: PLAYER_TOKEN},
        now: () => NOW,
      }),
      (error) => error instanceof GuestClaimError && error.code === 'not-found',
    );

    const quota = db.docData('safetyActionQuotas/player-1').guestClaim;
    assert.strictEqual(quota.count, 1);
    assert.strictEqual(Object.keys(quota.targets).length, 1);
    assert.deepStrictEqual(db.collectionData('claimCodes'), []);
  });

  it('denies issuance by an unrelated authenticated player', async () => {
    const db = new FakeFirestore({
      'players/organizer-1': player(),
      'players/attacker-1': player(),
      'guestTeams/guest-team-1': guestTeam({creatorId: 'organizer-1'}),
    });

    await assert.rejects(
      () => issueGuestClaimCodeCore({
        db,
        actorId: 'attacker-1',
        payload: {
          targetType: 'guestTeam',
          targetId: 'guest-team-1',
          requestId: ISSUE_REQUEST_ID,
        },
        now: () => NOW,
        tokenSecret: TOKEN_SECRET,
      }),
      permissionDenied,
    );
    assert.deepStrictEqual(db.collectionData('claimCodes'), []);
  });

  it('issues an approval-required team token for the guest-team creator', async () => {
    const db = new FakeFirestore({
      'players/organizer-1': player(),
      'guestTeams/guest-team-1': guestTeam({creatorId: 'organizer-1'}),
    });

    const issued = await issueGuestClaimCodeCore({
      db,
      actorId: 'organizer-1',
      payload: {
        targetType: 'guestTeam',
        targetId: 'guest-team-1',
        requestId: ISSUE_REQUEST_ID,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });

    assert.strictEqual(issued.requiresApproval, true);
    assert.strictEqual(issued.scope, 'tournament');
    assert.strictEqual(issued.tournamentId, 'street-cup');
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(issued.code)}`).targetType,
      'guestTeam',
    );
    assert.strictEqual(db.docData('guestTeams/guest-team-1').claimCode, null);
  });

  it('revokes the previous token when the issuer starts a new request', async () => {
    const db = new FakeFirestore({
      'players/organizer-1': player(),
      'guestPlayers/guest-1': guestPlayer({createdBy: 'organizer-1'}),
    });
    const first = await issueGuestClaimCodeCore({
      db,
      actorId: 'organizer-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: ISSUE_REQUEST_ID,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });
    const second = await issueGuestClaimCodeCore({
      db,
      actorId: 'organizer-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: 'issue-request-00000002',
      },
      now: () => NOW + 1,
      tokenSecret: TOKEN_SECRET,
    });

    assert.notStrictEqual(first.code, second.code);
    assert.strictEqual(db.collectionData('claimCodes').length, 2);
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(first.code)}`).status,
      'expired',
    );
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(second.code)}`).status,
      'active',
    );
    assert.strictEqual(db.docData('guestPlayers/guest-1').claimStatus, 'invited');
  });

  it('revokes the current token when another authorized issuer replaces it', async () => {
    const db = new FakeFirestore({
      'players/creator-1': player(),
      'players/captain-1': player(),
      'guestPlayers/guest-1': guestPlayer({
        createdBy: 'creator-1',
        teamId: 'team-1',
      }),
      'teams/team-1': team({ownerId: 'captain-1'}),
    });
    const issue = (actorId, requestId, now) => issueGuestClaimCodeCore({
      db,
      actorId,
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId,
      },
      now: () => now,
      tokenSecret: TOKEN_SECRET,
    });

    const first = await issue('creator-1', ISSUE_REQUEST_ID, NOW);
    const second = await issue(
      'captain-1',
      'issue-request-00000002',
      NOW + 1,
    );

    assert.strictEqual(
      db.docData(`claimCodes/${sha256(first.code)}`).status,
      'expired',
    );
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(second.code)}`).status,
      'active',
    );
    assert.strictEqual(
      db.docData('guestPlayers/guest-1').activeClaimTokenHash,
      sha256(second.code),
    );
  });

  it('rejects a conflicting retry that changes the original ttl', async () => {
    const db = new FakeFirestore({
      'players/organizer-1': player(),
      'guestPlayers/guest-1': guestPlayer({createdBy: 'organizer-1'}),
    });
    const issue = (ttlMs) => issueGuestClaimCodeCore({
      db,
      actorId: 'organizer-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: ISSUE_REQUEST_ID,
        ttlMs,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });
    const first = await issue(2 * 60 * 60 * 1000);

    await assert.rejects(
      () => issue(3 * 60 * 60 * 1000),
      (error) => error instanceof GuestClaimError &&
        error.code === 'failed-precondition',
    );

    assert.strictEqual(
      db.docData(`claimCodes/${sha256(first.code)}`).expiresAt,
      NOW + 2 * 60 * 60 * 1000,
    );
  });

  it('allows only an active guest-roster assistant from the authoritative ACL', async () => {
    const db = new FakeFirestore({
      'players/assistant-1': player(),
      'guestPlayers/guest-1': guestPlayer({
        createdBy: 'organizer-1',
        tournamentId: 'cup-1',
      }),
      'tournaments/cup-1': {organizerId: 'organizer-1'},
      'tournaments/cup-1/assistants/assistant-1': assistantPermission(),
    });

    const issued = await issueGuestClaimCodeCore({
      db,
      actorId: 'assistant-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: ISSUE_REQUEST_ID,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });

    assert.strictEqual(issued.targetId, 'guest-1');
  });

  it('rejects legacy, revoked, malformed, and unprivileged assistant authority', async () => {
    const invalidAssistantDocuments = [
      null,
      assistantPermission({permissions: {canManageGuestRoster: false}}),
      assistantPermission({status: 'revoked'}),
      assistantPermission({userId: 'different-assistant'}),
      assistantPermission({tournamentId: 'different-cup'}),
    ];
    for (const assistant of invalidAssistantDocuments) {
      const db = new FakeFirestore({
        'players/assistant-1': player(),
        'guestPlayers/guest-1': guestPlayer({
          createdBy: 'organizer-1',
          tournamentId: 'cup-1',
        }),
        'tournaments/cup-1': {
          organizerId: 'organizer-1',
          assistants: [{userId: 'assistant-1', role: 'full'}],
        },
        ...(assistant == null ? {} : {
          'tournaments/cup-1/assistants/assistant-1': assistant,
        }),
      });

      await assert.rejects(
        () => issueGuestClaimCodeCore({
          db,
          actorId: 'assistant-1',
          payload: {
            targetType: 'guestPlayer',
            targetId: 'guest-1',
            requestId: ISSUE_REQUEST_ID,
          },
          now: () => NOW,
          tokenSecret: TOKEN_SECRET,
        }),
        permissionDenied,
      );
    }
  });

  it('honors assistant revocation before issuing a replacement token', async () => {
    const db = new FakeFirestore({
      'players/assistant-1': player(),
      'guestPlayers/guest-1': guestPlayer({
        createdBy: 'organizer-1',
        tournamentId: 'cup-1',
      }),
      'tournaments/cup-1': {organizerId: 'organizer-1'},
      'tournaments/cup-1/assistants/assistant-1': assistantPermission(),
    });
    const request = (requestId) => issueGuestClaimCodeCore({
      db,
      actorId: 'assistant-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });

    await request(ISSUE_REQUEST_ID);
    db.store.set(
      'tournaments/cup-1/assistants/assistant-1',
      assistantPermission({status: 'revoked'}),
    );

    await assert.rejects(
      () => request('issue-request-00000002'),
      permissionDenied,
    );
  });
});

describe('trusted guest player claim', () => {
  it('consumes a newly issued hash-addressed token', async () => {
    const db = new FakeFirestore({
      'players/player-1': player(),
      'guestPlayers/guest-1': guestPlayer({createdBy: 'player-1'}),
    });
    const issued = await issueGuestClaimCodeCore({
      db,
      actorId: 'player-1',
      payload: {
        targetType: 'guestPlayer',
        targetId: 'guest-1',
        requestId: ISSUE_REQUEST_ID,
      },
      now: () => NOW,
      tokenSecret: TOKEN_SECRET,
    });

    const claimed = await claimGuestPlayerCore({
      db,
      actorId: 'player-1',
      payload: {claimCode: issued.code},
      now: () => NOW + 1,
    });

    assert.strictEqual(claimed.outcome, 'claimed');
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(issued.code)}`).status,
      'claimed',
    );
    assert.strictEqual(db.docData(`claimCodes/${issued.code}`), undefined);
    assertClaimAudits(
      db,
      ['guestPlayerClaimed', 'claimCodeConsumed'],
      issued.code,
    );
  });

  it('claims the authenticated actor, relinks roster, and writes bounded audits atomically', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      [`claimCodes/${PLAYER_TOKEN}`]: activeClaim({
        untrustedLegacyField: 'must-not-migrate',
      }),
    }));

    const claimed = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.strictEqual(claimed.outcome, 'claimed');
    assert.strictEqual(claimed.playerId, 'player-1');
    assert.deepStrictEqual(claimed.relinkedMembershipIds, ['membership-guest-1']);
    assert.strictEqual(
      db.docData('guestPlayers/guest-1').linkedPlayerId,
      'player-1',
    );
    assert.strictEqual(db.docData('guestPlayers/guest-1').claimCode, null);
    assert.deepStrictEqual(db.docData('players/player-1').teamIds, ['team-1']);
    assert.strictEqual(
      db.docData('teamMemberships/membership-guest-1').guestPlayerId,
      null,
    );
    assert.strictEqual(
      db.docData('teamMemberships/membership-guest-1').playerId,
      'player-1',
    );
    assert.deepStrictEqual(db.docData('teams/team-1').playerIds, ['player-1']);
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(PLAYER_TOKEN)}`).status,
      'claimed',
    );
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(PLAYER_TOKEN)}`).untrustedLegacyField,
      undefined,
    );
    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`), undefined);
    assertClaimAudits(db, ['guestPlayerClaimed', 'claimCodeConsumed'], PLAYER_TOKEN);
  });

  it('derives the linked player from auth and ignores a forged payload player id', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      'players/victim-1': player(),
    }));

    const claimed = await claimGuestPlayerCore({
      ...playerClaimRequest(db),
      payload: {claimCode: PLAYER_TOKEN, playerId: 'victim-1'},
    });

    assert.strictEqual(claimed.playerId, 'player-1');
    assert.strictEqual(
      db.docData('guestPlayers/guest-1').linkedPlayerId,
      'player-1',
    );
  });

  it('returns one idempotent replay without duplicating roster or audit records', async () => {
    const db = new FakeFirestore(playerClaimSeed());

    await claimGuestPlayerCore(playerClaimRequest(db));
    const replay = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.strictEqual(replay.outcome, 'alreadyClaimed');
    assert.strictEqual(replay.guestPlayerId, 'guest-1');
    assert.strictEqual(replay.playerId, 'player-1');
    assert.strictEqual(replay.duplicate, true);
    assert.strictEqual(db.collectionData('teamMemberships').length, 1);
    assert.strictEqual(db.collectionData('auditEvents').length, 2);
  });

  it('returns roster conflict without consuming the token or changing identity', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      'teamMemberships/membership-player-1': {
        teamId: 'team-1',
        playerId: 'player-1',
        guestPlayerId: null,
        status: 'bench',
      },
    }));

    const conflict = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.strictEqual(conflict.outcome, 'conflict');
    assert.strictEqual(conflict.conflict.type, 'rosterAlreadyContainsPlayer');
    assert.strictEqual(conflict.conflict.conflictingEntityId, null);
    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('rolls the entire claim back when a trusted audit write fails', async () => {
    const db = new FakeFirestore(
      playerClaimSeed(),
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => claimGuestPlayerCore(playerClaimRequest(db)),
      /Injected write failure/,
    );

    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
    assert.strictEqual(
      db.docData('teamMemberships/membership-guest-1').playerId,
      null,
    );
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('commits an expired status without touching the guest identity', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      [`claimCodes/${PLAYER_TOKEN}`]: activeClaim({expiresAt: NOW}),
    }));

    const expired = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.strictEqual(expired.outcome, 'expired');
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(PLAYER_TOKEN)}`).status,
      'expired',
    );
    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`), undefined);
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('rejects an unbound legacy claim document instead of trusting its id', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      'guestPlayers/guest-1': guestPlayer({
        teamId: 'team-1',
        createdBy: 'organizer-1',
        claimCode: null,
      }),
    }));

    await assert.rejects(
      () => claimGuestPlayerCore(playerClaimRequest(db)),
      (error) => error instanceof GuestClaimError &&
        error.code === 'failed-precondition',
    );

    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
  });

  it('rejects a legacy document whose issuer is not authorized for the target', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      [`claimCodes/${PLAYER_TOKEN}`]: activeClaim({createdBy: 'attacker-1'}),
    }));

    await assert.rejects(
      () => claimGuestPlayerCore(playerClaimRequest(db)),
      permissionDenied,
    );

    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`).status, 'active');
  });

  it('leaves inactive history untouched and reports only changed legacy teams', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      'teams/team-2': team({ownerId: 'organizer-1'}),
      'teamMemberships/membership-inactive-1': {
        teamId: 'team-2',
        playerId: null,
        guestPlayerId: 'guest-1',
        status: 'inactive',
      },
    }));

    const claimed = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.deepStrictEqual(claimed.relinkedMembershipIds, [
      'membership-guest-1',
      'membership-inactive-1',
    ]);
    assert.deepStrictEqual(claimed.syncedLegacyTeamIds, ['team-1']);
    assert.strictEqual(
      db.docData('teamMemberships/membership-inactive-1').guestPlayerId,
      null,
    );
    assert.strictEqual(
      db.docData('teamMemberships/membership-inactive-1').playerId,
      'player-1',
    );
    assert.strictEqual(
      db.docData('teamMemberships/membership-inactive-1').status,
      'inactive',
    );
    assert.deepStrictEqual(db.docData('teams/team-2').playerIds, []);
  });

  it('does not report or rewrite a legacy team that already contains the actor', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      'teams/team-1': team({
        ownerId: 'organizer-1',
        playerIds: ['player-1'],
      }),
    }));

    const claimed = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.deepStrictEqual(claimed.syncedLegacyTeamIds, []);
    assert.deepStrictEqual(db.docData('teams/team-1').playerIds, ['player-1']);
  });

  it('relinks the bounded maximum of 64 historical memberships', async () => {
    const db = new FakeFirestore({
      'players/player-1': player(),
      'guestPlayers/guest-1': guestPlayer({claimCode: PLAYER_TOKEN}),
      [`claimCodes/${PLAYER_TOKEN}`]: activeClaim(),
      ...guestMembershipEntries(64),
    });

    const claimed = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.strictEqual(claimed.relinkedMembershipIds.length, 64);
    assert.deepStrictEqual(claimed.linkedTeamIds, []);
    assert.strictEqual(
      db.docData('teamMemberships/history-63').playerId,
      'player-1',
    );
    assert.strictEqual(
      db.docData('teamMemberships/history-63').status,
      'inactive',
    );
  });

  it('rejects 65 guest memberships before changing any identity data', async () => {
    const db = new FakeFirestore({
      'players/player-1': player(),
      'guestPlayers/guest-1': guestPlayer({claimCode: PLAYER_TOKEN}),
      [`claimCodes/${PLAYER_TOKEN}`]: activeClaim(),
      ...guestMembershipEntries(65),
    });

    await assert.rejects(
      () => claimGuestPlayerCore(playerClaimRequest(db)),
      (error) => error instanceof GuestClaimError &&
        error.code === 'resource-exhausted',
    );

    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('teamMemberships/history-64').playerId, null);
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
  });

  it('does not reveal whether the guest phone belongs to another account', async () => {
    const matchingPhoneDb = new FakeFirestore(playerClaimSeed({
      'players/other-1': player({phone: '+201000000000'}),
      'guestPlayers/guest-1': guestPlayer({
        teamId: 'team-1',
        createdBy: 'organizer-1',
        claimCode: PLAYER_TOKEN,
        phoneNumber: '+201000000000',
      }),
    }));
    const unusedPhoneDb = new FakeFirestore(playerClaimSeed({
      'guestPlayers/guest-1': guestPlayer({
        teamId: 'team-1',
        createdBy: 'organizer-1',
        claimCode: PLAYER_TOKEN,
        phoneNumber: '+201000000000',
      }),
    }));

    const matchingPhoneClaim = await claimGuestPlayerCore(
      playerClaimRequest(matchingPhoneDb),
    );
    const unusedPhoneClaim = await claimGuestPlayerCore(
      playerClaimRequest(unusedPhoneDb),
    );

    assert.deepStrictEqual(matchingPhoneClaim, unusedPhoneClaim);
    assert.strictEqual(matchingPhoneClaim.outcome, 'claimed');
    assert.strictEqual(
      matchingPhoneDb.docData('guestPlayers/guest-1').phoneNumber,
      null,
    );
    assert.strictEqual(
      matchingPhoneDb.docData('players/other-1').phone,
      '+201000000000',
    );
  });

  it('does not reveal an existing linked player id to another token holder', async () => {
    const db = new FakeFirestore(playerClaimSeed({
      'guestPlayers/guest-1': guestPlayer({
        teamId: 'team-1',
        createdBy: 'organizer-1',
        claimCode: PLAYER_TOKEN,
        linkedPlayerId: 'victim-1',
      }),
    }));

    const conflict = await claimGuestPlayerCore(playerClaimRequest(db));

    assert.strictEqual(conflict.conflict.type, 'targetAlreadyLinked');
    assert.strictEqual(conflict.conflict.conflictingEntityId, null);
    assert.strictEqual(JSON.stringify(conflict).includes('victim-1'), false);
  });

  it('rejects an active hash token that is no longer bound to the target', async () => {
    const tokenHash = sha256(PLAYER_TOKEN);
    const db = new FakeFirestore({
      'players/player-1': player(),
      'guestPlayers/guest-1': guestPlayer({
        activeClaimTokenHash: sha256('ANOTHER_CURRENT_TOKEN'),
      }),
      [`claimCodes/${tokenHash}`]: activeClaim({
        tokenVersion: 2,
        issuanceRequestIdHash: sha256(ISSUE_REQUEST_ID),
        issuanceRequestHash: sha256('request-fingerprint'),
      }),
    });

    await assert.rejects(
      () => claimGuestPlayerCore(playerClaimRequest(db)),
      (error) => error instanceof GuestClaimError &&
        error.code === 'failed-precondition',
    );

    assert.strictEqual(db.docData(`claimCodes/${tokenHash}`).status, 'active');
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
  });

  it('rejects a token holder who has no active player profile', async () => {
    const seed = playerClaimSeed();
    delete seed['players/player-1'];
    const db = new FakeFirestore(seed);

    await assert.rejects(
      () => claimGuestPlayerCore(playerClaimRequest(db)),
      permissionDenied,
    );

    assert.strictEqual(db.docData(`claimCodes/${PLAYER_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestPlayers/guest-1').linkedPlayerId, null);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });
});

describe('trusted guest team claim', () => {
  it('claims directly for the authenticated registered-team owner', async () => {
    const db = new FakeFirestore(teamClaimSeed({requiresApproval: false}));

    const claimed = await claimGuestTeamCore(teamClaimRequest(db, 'captain-1'));

    assert.strictEqual(claimed.outcome, 'claimed');
    assert.strictEqual(claimed.teamId, 'team-1');
    assert.deepStrictEqual(
      db.docData('teams/team-1').tournamentIds,
      ['legacy-cup', 'street-cup'],
    );
    assert.strictEqual(
      db.docData('guestTeams/guest-team-1').linkedTeamId,
      'team-1',
    );
    assert.strictEqual(db.docData('guestTeams/guest-team-1').claimCode, null);
    assertClaimAudits(db, ['guestTeamClaimed', 'claimCodeConsumed'], TEAM_TOKEN);
  });

  it('stores one approval request, then lets the guest creator finalize it', async () => {
    const db = new FakeFirestore(teamClaimSeed({requiresApproval: true}));

    const requested = await claimGuestTeamCore(
      teamClaimRequest(db, 'captain-1'),
    );
    const duplicateRequest = await claimGuestTeamCore(
      teamClaimRequest(db, 'captain-1'),
    );

    assert.strictEqual(requested.outcome, 'approvalRequired');
    assert.strictEqual(requested.duplicate, false);
    assert.strictEqual(requested.requestedByPlayerId, null);
    assert.strictEqual(duplicateRequest.duplicate, true);
    assert.strictEqual(duplicateRequest.requestedByPlayerId, null);
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(TEAM_TOKEN)}`).status,
      'active',
    );
    assert.strictEqual(db.docData(`claimCodes/${TEAM_TOKEN}`), undefined);
    assert.strictEqual(db.docData('guestTeams/guest-team-1').linkedTeamId, null);
    assert.strictEqual(db.docData('guestTeams/guest-team-1').claimCode, null);
    assert.deepStrictEqual(db.docData('teams/team-1').tournamentIds, ['legacy-cup']);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);

    const inspected = await inspectGuestClaimCore({
      db,
      actorId: 'organizer-1',
      payload: {claimCode: TEAM_TOKEN},
      now: () => NOW + 1,
    });
    assert.strictEqual(inspected.subjectName, 'Guest Hawks');
    assert.strictEqual(inspected.pendingApproval, true);
    assert.strictEqual(inspected.canApprovePendingTeamClaim, true);
    assert.strictEqual(
      Object.hasOwn(inspected, 'claimedByPlayerId'),
      false,
    );

    const approved = await claimGuestTeamCore({
      db,
      actorId: 'organizer-1',
      payload: {claimCode: TEAM_TOKEN},
      now: () => NOW + 2,
    });
    const replay = await claimGuestTeamCore(
      teamClaimRequest(db, 'captain-1'),
    );

    assert.strictEqual(approved.outcome, 'claimed');
    assert.strictEqual(approved.requestedByPlayerId, null);
    assert.strictEqual(replay.outcome, 'alreadyClaimed');
    assert.strictEqual(replay.requestedByPlayerId, null);
    assert.strictEqual(
      db.docData(`claimCodes/${sha256(TEAM_TOKEN)}`).status,
      'claimed',
    );
    assert.deepStrictEqual(
      db.docData('teams/team-1').tournamentIds,
      ['legacy-cup', 'street-cup'],
    );
    assert.strictEqual(db.collectionData('auditEvents').length, 2);
  });

  it('rechecks registered-team ownership when the guest creator approves', async () => {
    const db = new FakeFirestore(teamClaimSeed({
      requiresApproval: true,
      extra: {
        'players/new-owner-1': player(),
        'teams/team-1': team({ownerId: 'new-owner-1'}),
        [`claimCodes/${TEAM_TOKEN}`]: activeClaim({
          targetType: 'guestTeam',
          targetId: 'guest-team-1',
          createdBy: 'organizer-1',
          requiresApproval: true,
          teamId: 'team-1',
          claimedByPlayerId: 'captain-1',
        }),
      },
    }));

    await assert.rejects(
      () => claimGuestTeamCore({
        db,
        actorId: 'organizer-1',
        payload: {claimCode: TEAM_TOKEN},
        now: () => NOW + 2,
      }),
      (error) => (
        error instanceof GuestClaimError &&
        error.code === 'failed-precondition'
      ),
    );

    assert.strictEqual(db.docData(`claimCodes/${TEAM_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestTeams/guest-team-1').linkedTeamId, null);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('rejects a non-owner who is unrelated to the guest team', async () => {
    const db = new FakeFirestore(teamClaimSeed({
      requiresApproval: false,
      extra: {'players/attacker-1': player()},
    }));

    await assert.rejects(
      () => claimGuestTeamCore(teamClaimRequest(db, 'attacker-1')),
      permissionDenied,
    );

    assert.strictEqual(db.docData(`claimCodes/${TEAM_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestTeams/guest-team-1').linkedTeamId, null);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });

  it('rolls direct team claim writes back when its audit cannot commit', async () => {
    const db = new FakeFirestore(
      teamClaimSeed({requiresApproval: false}),
      {failWrite: ({path}) => path.startsWith('auditEvents/')},
    );

    await assert.rejects(
      () => claimGuestTeamCore(teamClaimRequest(db, 'captain-1')),
      /Injected write failure/,
    );

    assert.strictEqual(db.docData(`claimCodes/${TEAM_TOKEN}`).status, 'active');
    assert.strictEqual(db.docData('guestTeams/guest-team-1').linkedTeamId, null);
    assert.deepStrictEqual(db.docData('teams/team-1').tournamentIds, ['legacy-cup']);
    assert.deepStrictEqual(db.collectionData('auditEvents'), []);
  });
});

function playerClaimRequest(db) {
  return {
    db,
    actorId: 'player-1',
    payload: {claimCode: PLAYER_TOKEN},
    now: () => NOW,
  };
}

function teamClaimRequest(db, actorId) {
  return {
    db,
    actorId,
    payload: {claimCode: TEAM_TOKEN, teamId: 'team-1'},
    now: () => NOW + 1,
  };
}

function playerClaimSeed(overrides = {}) {
  return {
    'players/player-1': player({teamIds: []}),
    'guestPlayers/guest-1': guestPlayer({
      teamId: 'team-1',
      createdBy: 'organizer-1',
      claimCode: PLAYER_TOKEN,
    }),
    'teams/team-1': team({ownerId: 'organizer-1'}),
    'teamMemberships/membership-guest-1': {
      teamId: 'team-1',
      playerId: null,
      guestPlayerId: 'guest-1',
      claimedFromGuestPlayerId: null,
      status: 'bench',
      updatedAt: NOW - 100,
    },
    [`claimCodes/${PLAYER_TOKEN}`]: activeClaim(),
    ...overrides,
  };
}

function teamClaimSeed({requiresApproval, extra = {}}) {
  return {
    'players/captain-1': player(),
    'players/organizer-1': player(),
    'guestTeams/guest-team-1': guestTeam({
      creatorId: 'organizer-1',
      claimCode: TEAM_TOKEN,
    }),
    'teams/team-1': team({ownerId: 'captain-1'}),
    [`claimCodes/${TEAM_TOKEN}`]: activeClaim({
      targetType: 'guestTeam',
      targetId: 'guest-team-1',
      createdBy: 'organizer-1',
      requiresApproval,
    }),
    ...extra,
  };
}

function activeClaim(overrides = {}) {
  return {
    targetType: 'guestPlayer',
    targetId: 'guest-1',
    scope: 'team',
    teamId: null,
    tournamentId: null,
    createdBy: 'organizer-1',
    requiresApproval: false,
    status: 'active',
    createdAt: NOW - 1000,
    updatedAt: NOW - 1000,
    expiresAt: NOW + 60 * 60 * 1000,
    claimedByPlayerId: null,
    claimedAt: null,
    ...overrides,
  };
}

function player(overrides = {}) {
  return {
    name: 'Registered Player',
    nameLower: 'registered player',
    phone: null,
    teamIds: [],
    lastActiveAt: NOW - 1000,
    ...overrides,
  };
}

function guestPlayer(overrides = {}) {
  return {
    displayName: 'Guest Hero',
    normalizedName: 'guest hero',
    phoneNumber: null,
    teamId: null,
    guestTeamId: null,
    tournamentId: null,
    createdBy: 'organizer-1',
    claimStatus: 'invited',
    claimCode: null,
    linkedPlayerId: null,
    updatedAt: NOW - 1000,
    ...overrides,
  };
}

function guestTeam(overrides = {}) {
  return {
    name: 'Guest Hawks',
    normalizedName: 'guest hawks',
    creatorId: 'organizer-1',
    tournamentIds: ['street-cup'],
    claimStatus: 'invited',
    claimCode: null,
    linkedTeamId: null,
    updatedAt: NOW - 1000,
    ...overrides,
  };
}

function assistantPermission(overrides = {}) {
  return {
    tournamentId: 'cup-1',
    userId: 'assistant-1',
    status: 'active',
    permissions: {canManageGuestRoster: true},
    ...overrides,
  };
}

function team(overrides = {}) {
  return {
    name: 'Registered Hawks',
    nameLower: 'registered hawks',
    ownerId: 'captain-1',
    viceCaptainIds: [],
    playerIds: [],
    tournamentIds: ['legacy-cup'],
    ...overrides,
  };
}

function guestMembershipEntries(count) {
  return Object.fromEntries(Array.from({length: count}, (_, index) => [
    `teamMemberships/history-${index}`,
    {
      teamId: `archived-team-${index}`,
      playerId: null,
      guestPlayerId: 'guest-1',
      claimedFromGuestPlayerId: null,
      status: 'inactive',
      updatedAt: NOW - 100,
    },
  ]));
}

function assertClaimAudits(db, expectedActions, rawToken) {
  const audits = db.collectionData('auditEvents');
  assert.deepStrictEqual(
    audits.map((audit) => audit.action).sort(),
    [...expectedActions].sort(),
  );
  assert.strictEqual(JSON.stringify(audits).includes(rawToken), false);
  for (const audit of audits) {
    assert.strictEqual(audit.source, 'trustedOperation');
    assert.strictEqual(audit.verificationVersion, 1);
    assert.match(audit.actorId, /^[A-Za-z0-9_-]+$/);
    assert.match(audit.entityId, /^[A-Za-z0-9_-]+$/);
    assert.match(audit.requestId, /^claim:[a-f0-9]{32}:/);
    assert(Number.isFinite(audit.createdAt));
    assert(audit.beforePayload && typeof audit.beforePayload === 'object');
    assert(audit.afterPayload && typeof audit.afterPayload === 'object');
  }
}

function permissionDenied(error) {
  return error instanceof GuestClaimError && error.code === 'permission-denied';
}

function sha256(candidate) {
  return crypto.createHash('sha256').update(candidate).digest('hex');
}

function installFakeQueryOrderBy() {
  const probe = new FakeFirestore().collection('probe').where('id', '==', 'id');
  const queryPrototype = Object.getPrototypeOf(probe);
  if (typeof queryPrototype.orderBy === 'function') return;
  queryPrototype.orderBy = function orderBy(field, direction) {
    assert.strictEqual(field, 'createdAt');
    assert.strictEqual(direction, 'desc');
    return this;
  };
}
