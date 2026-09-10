/**
 * Pure scheduling maths for amortized expense series, kept out of the Cloud
 * Function bodies so the parts that decide *how much lands in which month* can
 * be unit-tested without the Firestore runtime. A mistake here is invisible
 * until a future month arrives, which is the worst possible time to find it.
 */
const { monthKey } = require("./dateKey");

/**
 * The amount charged in each month of the series.
 *
 * The caller is handed the full total precisely so this division happens once,
 * in one place: the client sends the total and writes installment 1 with the
 * same formula.
 * @param {number} total The full amount being spread.
 * @param {number} months How many months to spread it over.
 * @return {number} The per-month charge.
 */
function installmentAmount(total, months) {
    return total / months;
}

/**
 * The future installments of a series, newest first — the order the Cloud
 * Function writes them in so it can chain each `nextId` to the one before.
 *
 * Installment 1 is written by the client and is not part of this list. Every
 * generated entry is anchored to the first instant of its month rather than
 * inheriting the original day and time: the expense list is ordered by date
 * descending, so pinning them to the earliest instant keeps generated spend at
 * the bottom of the list once that month arrives.
 * @param {Date} originalDate The date of installment 1.
 * @param {number} months The length of the series.
 * @return {Array<{index: number, date: Date, collection: string}>} The
 *     installments after the first, from the last month back to the second.
 */
function futureInstallments(originalDate, months) {
    const installments = [];
    for (let i = months; i >= 2; i--) {
        // Month overflow is intentional: month 13 of 2026 is January 2027.
        const date = new Date(
            originalDate.getFullYear(),
            originalDate.getMonth() + i - 1,
            1,
        );
        installments.push({ index: i, date, collection: monthKey(date) });
    }
    return installments;
}

/**
 * The summary document id for a category in the month of [date].
 * @param {Date} date Any instant within the month.
 * @param {string} categoryId The category being rolled up.
 * @return {string} The "YYYY_MON_categoryId" document id.
 */
function summaryId(date, categoryId) {
    return `${monthKey(date)}_${categoryId}`;
}

/**
 * Whether a document path from a series manifest refers to [updateId].
 *
 * Used when tearing a series down to spare installment 1, whose document is
 * rewritten in place rather than deleted. The comparison is against the final
 * path segment: a substring test would also spare an unrelated document whose
 * id merely contains this one.
 * @param {string} path A full Firestore document path.
 * @param {string|null|undefined} updateId The document id to spare, if any.
 * @return {boolean} True when the path names that exact document.
 */
function isUpdateTarget(path, updateId) {
    if (!updateId) return false;
    return path.split("/").pop() === updateId;
}

module.exports = {
    installmentAmount,
    futureInstallments,
    summaryId,
    isUpdateTarget,
};
