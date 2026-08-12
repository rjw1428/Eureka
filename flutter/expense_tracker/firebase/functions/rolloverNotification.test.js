/**
 * Lightweight assertions for the rollover notification helpers. No test runner
 * is configured in this package, so this file is runnable directly:
 * `node rolloverNotification.test.js`. Exits non-zero on the first failure.
 */
const assert = require("assert");
const {
    formatTotal,
    formatMonthLabel,
    recipientsFor,
    buildMessage,
} = require("./rolloverNotification");

// --- recipientsFor: the submitter never hears about their own submission.
assert.deepStrictEqual(
    recipientsFor([{ id: "user-1" }, { id: "user-2" }], "user-1"),
    ["user-2"],
);

// A user with no linked accounts produces no recipients.
assert.deepStrictEqual(recipientsFor([], "user-1"), []);
assert.deepStrictEqual(recipientsFor(undefined, "user-1"), []);
assert.deepStrictEqual(recipientsFor(null, "user-1"), []);

// Non-array input is tolerated rather than throwing inside a callable.
assert.deepStrictEqual(recipientsFor("nope", "user-1"), []);

// Malformed entries are skipped, not passed through as undefined ids.
assert.deepStrictEqual(
    recipientsFor([{ id: "user-2" }, {}, null, { id: "" }], "user-1"),
    ["user-2"],
);

// Duplicates collapse, so nobody is notified twice.
assert.deepStrictEqual(
    recipientsFor([{ id: "user-2" }, { id: "user-2" }, { id: "user-3" }], "user-1"),
    ["user-2", "user-3"],
);

// A ledger where every linked account is the submitter yields nobody.
assert.deepStrictEqual(recipientsFor([{ id: "user-1" }], "user-1"), []);

// --- formatTotal
assert.strictEqual(formatTotal(165), "$165.00");
assert.strictEqual(formatTotal(165.5), "$165.50");
assert.strictEqual(formatTotal(0), "$0.00");
assert.strictEqual(formatTotal(undefined), "$0.00");
assert.strictEqual(formatTotal("165"), "$165.00");

// --- formatMonthLabel
assert.strictEqual(formatMonthLabel("2026_SEP"), "Sep 2026");
assert.strictEqual(formatMonthLabel("2026_JAN"), "Jan 2026");
// Unrecognised shapes pass through rather than rendering garbage.
assert.strictEqual(formatMonthLabel("garbage"), "garbage");
assert.strictEqual(formatMonthLabel(undefined), "");

// --- buildMessage
const message = buildMessage({
    submitterName: "Ryan",
    total: 165,
    monthKey: "2026_SEP",
});
assert.ok(message.title.length > 0, "expected a title");
assert.ok(
    message.body.includes("Ryan"),
    `expected the submitter name in: ${message.body}`,
);
assert.ok(
    message.body.includes("$165.00"),
    `expected the formatted total in: ${message.body}`,
);
assert.ok(
    message.body.includes("Sep 2026"),
    `expected the month label in: ${message.body}`,
);

// A missing name degrades to something readable rather than "undefined".
const anonymous = buildMessage({ total: 10, monthKey: "2026_SEP" });
assert.ok(
    !anonymous.body.includes("undefined"),
    `expected no "undefined" in: ${anonymous.body}`,
);
assert.ok(anonymous.body.includes("Someone"));

console.log("rolloverNotification.test.js: all assertions passed");
