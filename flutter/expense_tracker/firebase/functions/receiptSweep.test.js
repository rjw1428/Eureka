/**
 * Assertions for the backstop receipt sweep. No test runner is configured in
 * this package, so this file is runnable directly: `node receiptSweep.test.js`.
 * Exits non-zero on the first failed assertion.
 */
const assert = require("assert");
const { sweepDueMarkers, receiptPath } = require("./receiptSweep");

const silentLogger = { info() {}, warn() {}, error() {} };

/** Records every path deleted, and can be told to fail on specific ones. */
function fakeBucket({ failOn = [], missing = [] } = {}) {
    const deleted = [];
    return {
        deleted,
        file(path) {
            return {
                async delete({ ignoreNotFound } = {}) {
                    if (failOn.includes(path)) {
                        throw new Error(`storage unavailable for ${path}`);
                    }
                    if (missing.includes(path) && !ignoreNotFound) {
                        throw new Error(`no such object ${path}`);
                    }
                    deleted.push(path);
                },
            };
        },
    };
}

/** Minimal Firestore stand-in supporting the single query the sweep issues. */
function fakeDb(markers) {
    const remaining = new Map(markers.map((m) => [m.id, m]));
    return {
        remaining,
        collection() {
            return {
                where(field, op, value) {
                    return {
                        async get() {
                            const docs = [...remaining.values()]
                                .filter((m) => m.deleteAfter <= value)
                                .map((m) => ({
                                    id: m.id,
                                    data: () => ({
                                        ledgerId: m.ledgerId,
                                        receiptId: m.receiptId,
                                    }),
                                    ref: {
                                        async delete() {
                                            remaining.delete(m.id);
                                        },
                                    },
                                }));
                            return { docs };
                        },
                    };
                },
            };
        },
    };
}

const NOW = 1000;
const marker = (id, deleteAfter, extra = {}) => ({
    id,
    receiptId: id,
    ledgerId: "ledger-1",
    deleteAfter,
    ...extra,
});

(async () => {
    // Path derives from ledger + receipt, never an expense document id.
    assert.strictEqual(receiptPath("L", "R"), "receipts/L/R");

    // A due marker is reclaimed: object deleted, then marker deleted.
    {
        const db = fakeDb([marker("r1", 500)]);
        const bucket = fakeBucket();
        const result = await sweepDueMarkers({
            db, bucket, now: NOW, logger: silentLogger,
        });

        assert.deepStrictEqual(bucket.deleted, ["receipts/ledger-1/r1"]);
        assert.strictEqual(db.remaining.size, 0);
        assert.deepStrictEqual(result, { reclaimed: 1, failed: 0, due: 1 });
    }

    // A marker inside its backstop window is left completely alone, so the
    // sweep can never race a live undo.
    {
        const db = fakeDb([marker("r1", NOW + 5000)]);
        const bucket = fakeBucket();
        const result = await sweepDueMarkers({
            db, bucket, now: NOW, logger: silentLogger,
        });

        assert.deepStrictEqual(bucket.deleted, []);
        assert.strictEqual(db.remaining.size, 1);
        assert.deepStrictEqual(result, { reclaimed: 0, failed: 0, due: 0 });
    }

    // An object that is already gone is the goal state, not a failure.
    {
        const db = fakeDb([marker("gone", 500)]);
        const bucket = fakeBucket({ missing: ["receipts/ledger-1/gone"] });
        const result = await sweepDueMarkers({
            db, bucket, now: NOW, logger: silentLogger,
        });

        assert.strictEqual(result.reclaimed, 1);
        assert.strictEqual(result.failed, 0);
        assert.strictEqual(db.remaining.size, 0);
    }

    // One failure must not halt the batch, and its marker must survive to be
    // retried on a later run.
    {
        const db = fakeDb([
            marker("ok1", 500),
            marker("bad", 500),
            marker("ok2", 500),
        ]);
        const bucket = fakeBucket({ failOn: ["receipts/ledger-1/bad"] });
        const result = await sweepDueMarkers({
            db, bucket, now: NOW, logger: silentLogger,
        });

        assert.strictEqual(result.reclaimed, 2, "both healthy markers reclaimed");
        assert.strictEqual(result.failed, 1);
        assert.deepStrictEqual([...db.remaining.keys()], ["bad"]);
    }

    // Running twice over the same data makes no further changes and does not
    // throw.
    {
        const db = fakeDb([marker("r1", 500)]);
        const bucket = fakeBucket();
        await sweepDueMarkers({ db, bucket, now: NOW, logger: silentLogger });
        const second = await sweepDueMarkers({
            db, bucket, now: NOW, logger: silentLogger,
        });

        assert.deepStrictEqual(second, { reclaimed: 0, failed: 0, due: 0 });
        assert.strictEqual(bucket.deleted.length, 1, "no second delete");
    }

    // A malformed marker is cleared rather than retried forever.
    {
        const db = fakeDb([
            { id: "junk", ledgerId: null, receiptId: null, deleteAfter: 500 },
        ]);
        const bucket = fakeBucket();
        const result = await sweepDueMarkers({
            db, bucket, now: NOW, logger: silentLogger,
        });

        assert.strictEqual(db.remaining.size, 0);
        assert.strictEqual(result.reclaimed, 0);
        assert.deepStrictEqual(bucket.deleted, []);
    }

    console.log("receiptSweep.test.js: all assertions passed");
})();
