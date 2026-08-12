/**
 * Pure helpers for the monthly rollover notification. Kept in its own module,
 * following the dateKey.js precedent, so recipient selection and message
 * wording can be unit-tested without the Cloud Functions runtime or Firestore.
 */

/**
 * Formats an amount as US currency for display in a notification body.
 * @param {number} total The amount rolled over.
 * @return {string} e.g. "$165.00".
 */
function formatTotal(total) {
    const amount = Number(total) || 0;
    return `$${amount.toFixed(2)}`;
}

/**
 * Renders "2026_AUG" as "Aug 2026" for the notification body. Falls back to
 * the raw key if it does not match the expected shape.
 * @param {string} monthKey A "YYYY_MON" key.
 * @return {string} A human-readable month label.
 */
function formatMonthLabel(monthKey) {
    if (typeof monthKey !== "string") return "";
    const match = /^(\d{4})_([A-Z]{3})$/.exec(monthKey);
    if (!match) return monthKey;
    const [, year, month] = match;
    return `${month.charAt(0)}${month.slice(1).toLowerCase()} ${year}`;
}

/**
 * Selects who should hear about a completed rollover: everyone linked to the
 * submitting user, never the submitter themselves.
 * @param {Array<{id: string}>} linkedAccounts The submitter's linked accounts.
 * @param {string} submitterId The uid of the user who submitted.
 * @return {Array<string>} Deduplicated recipient user ids.
 */
function recipientsFor(linkedAccounts, submitterId) {
    if (!Array.isArray(linkedAccounts)) return [];

    const ids = linkedAccounts
        .map((account) => (account && account.id) || null)
        .filter((id) => typeof id === "string" && id.length > 0)
        .filter((id) => id !== submitterId);

    return [...new Set(ids)];
}

/**
 * Builds the notification title and body.
 * @param {object} params The message inputs.
 * @param {string} params.submitterName The submitting user's first name.
 * @param {number} params.total The amount rolled over.
 * @param {string} params.monthKey The month rolled *into*, as "YYYY_MON".
 * @return {{title: string, body: string}} The rendered message.
 */
function buildMessage({ submitterName, total, monthKey }) {
    const name = submitterName || "Someone";
    const label = formatMonthLabel(monthKey);
    return {
        title: "Last month's overspend was carried over",
        body: label
            ? `${name} rolled ${formatTotal(total)} of overspending into ${label}.`
            : `${name} rolled ${formatTotal(total)} of overspending into this month.`,
    };
}

module.exports = { formatTotal, formatMonthLabel, recipientsFor, buildMessage };
