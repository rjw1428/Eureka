/**
 * Assertions for the amortization schedule. No test runner is configured in
 * this package, so this file is runnable directly: `node amortization.test.js`.
 * Exits non-zero on the first failed assertion.
 */
const assert = require("assert");
const {
    installmentAmount,
    futureInstallments,
    summaryId,
    isUpdateTarget,
} = require("./amortization");

// --- installmentAmount -----------------------------------------------------

assert.strictEqual(installmentAmount(300, 3), 100);
assert.strictEqual(installmentAmount(90, 3), 30);
assert.strictEqual(installmentAmount(50, 2), 25);
// A total that does not divide evenly is not rounded here; every month carries
// the same fraction, and the series still sums back to the total.
const uneven = installmentAmount(100, 3);
assert.ok(Math.abs(uneven * 3 - 100) < 1e-9, "the series must sum to the total");

// --- futureInstallments ----------------------------------------------------

// A three-month series started in March generates April and May only:
// installment 1 stays in March and is written by the client.
const march = new Date(2026, 2, 10, 14, 30);
const spring = futureInstallments(march, 3);
assert.strictEqual(spring.length, 2);
assert.deepStrictEqual(
    spring.map((i) => i.collection),
    ["2026_MAY", "2026_APR"],
);
// Written newest-first so each `nextId` can point at the entry already written.
assert.deepStrictEqual(spring.map((i) => i.index), [3, 2]);

// Every generated entry is anchored to the first instant of its month, not to
// the original day and time.
for (const installment of spring) {
    assert.strictEqual(installment.date.getDate(), 1);
    assert.strictEqual(installment.date.getHours(), 0);
    assert.strictEqual(installment.date.getMinutes(), 0);
    assert.strictEqual(installment.date.getSeconds(), 0);
}

// A two-month series generates exactly one future month.
assert.deepStrictEqual(
    futureInstallments(new Date(2026, 2, 10), 2).map((i) => i.collection),
    ["2026_APR"],
);

// A series crossing the year boundary rolls into the next year.
assert.deepStrictEqual(
    futureInstallments(new Date(2026, 11, 15), 3).map((i) => i.collection),
    ["2027_FEB", "2027_JAN"],
);

// A twelve-month series started in January covers the rest of the year.
const year = futureInstallments(new Date(2026, 0, 5), 12);
assert.strictEqual(year.length, 11);
assert.strictEqual(year[year.length - 1].collection, "2026_FEB");
assert.strictEqual(year[0].collection, "2026_DEC");

// The longest series the form allows still lands on real months.
const longest = futureInstallments(new Date(2026, 5, 20), 24);
assert.strictEqual(longest.length, 23);
assert.strictEqual(longest[0].collection, "2028_MAY");
assert.strictEqual(longest[longest.length - 1].collection, "2026_JUL");

// Starting on the 31st does not skip a short month: the anchor is the 1st.
assert.deepStrictEqual(
    futureInstallments(new Date(2026, 0, 31), 3).map((i) => i.collection),
    ["2026_MAR", "2026_FEB"],
);

// No month is generated twice.
const keys = futureInstallments(new Date(2026, 0, 31), 13).map((i) => i.collection);
assert.strictEqual(new Set(keys).size, keys.length, "each month appears once");

// --- summaryId -------------------------------------------------------------

assert.strictEqual(summaryId(new Date(2026, 2, 10), "groceries"), "2026_MAR_groceries");
assert.strictEqual(summaryId(new Date(2026, 11, 1), "travel"), "2026_DEC_travel");

// --- isUpdateTarget --------------------------------------------------------

const base = "ledger/ledger-1/2026_MAR";
assert.ok(isUpdateTarget(`${base}/abc123`, "abc123"));
assert.ok(!isUpdateTarget(`${base}/abc123`, "def456"));
// No id to spare means nothing is spared: an outright delete removes the
// whole series including installment 1.
assert.ok(!isUpdateTarget(`${base}/abc123`, null));
assert.ok(!isUpdateTarget(`${base}/abc123`, undefined));
assert.ok(!isUpdateTarget(`${base}/abc123`, ""));
// Only the document id is compared, never a substring of the wider path: a
// containment test would spare an unrelated document, leaving an orphan
// behind, and would also match the ledger or collection segment.
assert.ok(!isUpdateTarget(`${base}/abc123extra`, "abc123"));
assert.ok(!isUpdateTarget(`${base}/xxabc123`, "abc123"));
assert.ok(!isUpdateTarget(`${base}/abc123`, "2026_MAR"));
assert.ok(!isUpdateTarget(`${base}/abc123`, "ledger-1"));

console.log("amortization.test.js: all assertions passed");
