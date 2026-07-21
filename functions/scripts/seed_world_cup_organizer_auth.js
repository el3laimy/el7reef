"use strict";

const admin = require("firebase-admin");

const ORGANIZER_UID = "organizer-1";
const ORGANIZER_EMAIL = "world-cup-organizer@example.test";
const ORGANIZER_PASSWORD = "WorldCup2026!";

function assertLocalAuthEmulator(environment) {
  const host = environment.FIREBASE_AUTH_EMULATOR_HOST ?? "";
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
    throw new Error(
      "Refusing seed: FIREBASE_AUTH_EMULATOR_HOST must target localhost.",
    );
  }
}

async function seedOrganizer(auth) {
  try {
    await auth.getUser(ORGANIZER_UID);
    await auth.updateUser(ORGANIZER_UID, {
      email: ORGANIZER_EMAIL,
      password: ORGANIZER_PASSWORD,
      displayName: "منظم كأس العالم",
      disabled: false,
      emailVerified: true,
    });
    return "updated";
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid: ORGANIZER_UID,
      email: ORGANIZER_EMAIL,
      password: ORGANIZER_PASSWORD,
      displayName: "منظم كأس العالم",
      disabled: false,
      emailVerified: true,
    });
    return "created";
  }
}

async function main() {
  const projectId = process.argv[2];
  if (!projectId) {
    throw new Error("Usage: node seed_world_cup_organizer_auth.js <project-id>");
  }
  assertLocalAuthEmulator(process.env);
  admin.initializeApp({projectId});
  const result = await seedOrganizer(admin.auth());
  console.log(`World Cup organizer auth user ${result}: ${ORGANIZER_UID}`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  ORGANIZER_EMAIL,
  ORGANIZER_PASSWORD,
  ORGANIZER_UID,
  assertLocalAuthEmulator,
  seedOrganizer,
};
