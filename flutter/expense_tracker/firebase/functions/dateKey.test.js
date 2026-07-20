/**
 * Lightweight assertions for the month-key scheme. No test runner is configured
 * in this package, so this file is runnable directly: `node dateKey.test.js`.
 * Exits non-zero on the first failed assertion.
 */
const assert = require("assert");
const { MONTH_COLLECTION_RE, monthKey, toDate } = require("./dateKey");

// Basic month keys.
assert.strictEqual(monthKey(new Date(2026, 6, 15)), "2026_JUL");
assert.strictEqual(monthKey(new Date(2026, 0, 1)), "2026_JAN");
assert.strictEqual(monthKey(new Date(2025, 11, 31)), "2025_DEC");

// Month boundaries: first and last local instant of a month land in that month.
assert.strictEqual(monthKey(new Date(2026, 6, 1, 0, 0, 0)), "2026_JUL");
assert.strictEqual(monthKey(new Date(2026, 6, 31, 23, 59, 59)), "2026_JUL");
// The instant after July is August, not July.
assert.strictEqual(monthKey(new Date(2026, 7, 1, 0, 0, 0)), "2026_AUG");
// Year boundary.
assert.strictEqual(monthKey(new Date(2027, 0, 1, 0, 0, 0)), "2027_JAN");

// Keys produced by monthKey are accepted by the collection matcher.
for (const d of [new Date(2026, 6, 15), new Date(2025, 11, 1), new Date(2030, 2, 9)]) {
    assert.ok(MONTH_COLLECTION_RE.test(monthKey(d)), `expected ${monthKey(d)} to match`);
}
// Non-month ids are rejected.
assert.ok(!MONTH_COLLECTION_RE.test("summaries"));
assert.ok(!MONTH_COLLECTION_RE.test("2026_July"));
assert.ok(!MONTH_COLLECTION_RE.test("2026_7"));

// toDate coerces the shapes stored on expense docs.
assert.strictEqual(toDate(null), null);
assert.strictEqual(toDate("2026-07-15T00:00:00.000Z").getUTCFullYear(), 2026);
assert.strictEqual(toDate({ _seconds: 0, _nanoseconds: 0 }).getTime(), 0);
assert.strictEqual(toDate({ toDate: () => new Date(0) }).getTime(), 0);

console.log("dateKey.test.js: all assertions passed");
