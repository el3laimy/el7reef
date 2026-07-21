const COLLECTIONS = Object.freeze(require("./firestore_collections.json"));

const EVENT_STATUS = Object.freeze({
  active: "active",
  voided: "voided",
});

const EVENT_TYPE = Object.freeze({
  goal: "goal",
  mvp: "mvp",
});

const MATCH_STATUS = Object.freeze({
  completed: "completed",
  frozen: "frozen",
  live: "live",
  pendingReview: "pendingReview",
  settled: "settled",
});

const SIDE_KEYS = Object.freeze(["A", "B"]);

module.exports = {
  COLLECTIONS,
  EVENT_STATUS,
  EVENT_TYPE,
  MATCH_STATUS,
  SIDE_KEYS,
};
