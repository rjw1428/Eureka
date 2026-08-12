/**
 * Backstop reclamation for released receipt objects.
 *
 * Split out from index.js so the logic is testable without an emulator, in the
 * same spirit as dateKey.js. The scheduled trigger is a thin wrapper.
 */

const MARKER_COLLECTION = "receipt_deletions";

/**
 * Storage path for a receipt object. Derived from the ledger and the receipt
 * id — never the expense document id, so an expense moving between month
 * collections cannot orphan its object.
 * @param {string} ledgerId Owning ledger.
 * @param {string} receiptId Stable receipt identifier.
 * @return {string} Full object path.
 */
function receiptPath(ledgerId, receiptId) {
    return `receipts/${ledgerId}/${receiptId}`;
}

/**
 * Deletes every released object whose backstop time has passed, then its
 * marker.
 *
 * Idempotent and partial-failure tolerant: an object that is already gone
 * counts as reclaimed, and a failure on one marker leaves that marker in place
 * for a later run without stopping the batch.
 *
 * @param {object} deps Injected collaborators.
 * @param {object} deps.db Firestore instance.
 * @param {object} deps.bucket Storage bucket.
 * @param {object} deps.now Timestamp representing the current instant.
 * @param {object} deps.logger Logger with info/warn/error.
 * @return {Promise<{reclaimed: number, failed: number, due: number}>} Counts.
 */
async function sweepDueMarkers({ db, bucket, now, logger }) {
    const due = await db
        .collection(MARKER_COLLECTION)
        .where("deleteAfter", "<=", now)
        .get();

    let reclaimed = 0;
    let failed = 0;

    // Sequential rather than Promise.all: this runs nightly over a handful of
    // stragglers, and one failure must not take the rest of the batch with it.
    for (const doc of due.docs) {
        const { ledgerId, receiptId } = doc.data();

        if (!ledgerId || !receiptId) {
            logger.warn(`Malformed deletion marker ${doc.id}; removing it.`);
            await doc.ref.delete();
            continue;
        }

        try {
            // ignoreNotFound: an object already gone is the goal state, not an
            // error — the marker should still be cleared.
            await bucket
                .file(receiptPath(ledgerId, receiptId))
                .delete({ ignoreNotFound: true });
            await doc.ref.delete();
            reclaimed++;
        } catch (e) {
            // Marker retained so a later run retries it.
            logger.error(`Sweep could not reclaim ${receiptId}: ${e}`);
            failed++;
        }
    }

    return { reclaimed, failed, due: due.docs.length };
}

module.exports = { sweepDueMarkers, receiptPath, MARKER_COLLECTION };
