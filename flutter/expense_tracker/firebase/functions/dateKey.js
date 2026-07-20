/**
 * Shared date/month-key helpers for summary bucketing. Kept in its own module
 * so the "YYYY_MON" scheme can be unit-tested independently of the Cloud
 * Functions runtime.
 */

/** Matches a monthly expense collection id, e.g. "2026_JUL". */
const MONTH_COLLECTION_RE = /^\d{4}_[A-Z]{3}$/;

/**
 * Builds the monthly collection key ("YYYY_MON") for a date, matching the
 * client scheme in expense_stream_provider.dart (`_formatMonth`): the calendar
 * year plus the uppercased en-US short month. Used for both the raw expense
 * collection name and the summary document id so they always agree.
 * @param {Date} date The date to derive the month key from.
 * @return {string} The "YYYY_MON" key (e.g. "2026_JUL").
 */
function monthKey(date) {
    const monthStr = new Intl.DateTimeFormat("en-US", { month: "short" })
        .format(date)
        .toUpperCase();
    return `${date.getFullYear()}_${monthStr}`;
}

/**
 * Coerces a stored expense `date` (Firestore Timestamp, {_seconds}, or ISO
 * string) into a JS Date. Returns null if it cannot be parsed.
 * @param {*} value The raw date value from a transaction document.
 * @return {Date|null} The parsed date, or null.
 */
function toDate(value) {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate();
    if (value._seconds != null) return new Date(value._seconds * 1000);
    return new Date(value);
}

module.exports = { MONTH_COLLECTION_RE, monthKey, toDate };
