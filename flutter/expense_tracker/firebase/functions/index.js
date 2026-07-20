const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { MONTH_COLLECTION_RE, monthKey, toDate } = require("./dateKey");

initializeApp();

/**
 * Creates a new notification document for a user.
 * @param {string} userId The ID of the user to create the notification for.
 * @param {string} title The title of the notification.
 * @param {string} body The body/content of the notification.
 * @param {object} actions A map of actions associated with the notification.
 */
async function createNotification(userId, title, body, actions = {}) {
    try {
        const db = getFirestore();
        const notificationRef = db
            .collection("expenseUsers")
            .doc(userId)
            .collection("notifications")
            .doc(); // Let Firestore generate the ID

        await notificationRef.set({
            id: notificationRef.id,
            title: title,
            body: body,
            actions: actions,
            timestamp: FieldValue.serverTimestamp(),
            isRead: false,
        });
        logger.info(`Notification created for user ${userId}: ${title}`);
    } catch (error) {
        logger.error(`Error creating notification for user ${userId}:`, error);
    }
}

// Cloud Function to handle sending FCM when a new notification document is created
exports.onNotificationCreated = onDocumentCreated(
    "expenseUsers/{userId}/notifications/{notificationId}",
    async (event) => {
        try {
            const notificationData = event.data.data();
            const userId = event.params.userId;
            logger.info(`Processing new notification for user ${userId}: ${notificationData.title}`);

            const userSnapshot = await getFirestore()
                .collection("expenseUsers")
                .doc(userId)
                .get();

            if (!userSnapshot.exists) {
                logger.warn(`User ${userId} not found, cannot send FCM.`);
                return;
            }

            const userData = userSnapshot.data();
            const token = userData.fcmToken;

            if (!token) {
                logger.warn(`User ${userId} does not have an FCM token, skipping FCM.`);
                return;
            }

            const message = {
                notification: {
                    title: notificationData.title,
                    body: notificationData.body,
                },
                token: token,
                data: {
                    notificationId: notificationData.id,
                    ...notificationData.actions
                }
            };

            await getMessaging().send(message);
            logger.info(`FCM sent for notification ${notificationData.id} to user ${userId}.`);
        } catch (e) {
            logger.error("Error in onNotificationCreated:", e);
        }
    }
);


exports.sendExpenseNotification = onDocumentCreated(
    "ledger/{ledgerId}/{expenseCollectionId}/{expenseId}",
    async (event) => {
        try {
            const expenseData = event.data.data();
            logger.info(expenseData);

            if (expenseData.notify !== true) {
                logger.info("Notify is not true, exiting.");
                return;
            }

            const submittedBy = expenseData.submittedBy;
            const submittingUser = await getFirestore()
                .collection("expenseUsers")
                .doc(submittedBy)
                .get();

            if (!submittingUser.exists) {
                logger.warn("Submitting user not found");
                return;
            }

            const ledgerDoc = await getFirestore()
                .collection("ledger")
                .doc(event.params.ledgerId)
                .get();
            logger.debug(event.params.ledgerId);
            if (!ledgerDoc.exists) {
                logger.warn("No budget configured")
                return;
            }

            const config = ledgerDoc.data()
            logger.debug(config)

            const category = config.budgetConfig[expenseData.categoryId]
            logger.debug(category)
            const messageBody = category
                ? expenseData.note
                    ? `${submittingUser.data().firstName} added an expense of \$${expenseData.amount} to ${category.label} for ${expenseData.note}`
                    : `${submittingUser.data().firstName} added an expense of \$${expenseData.amount} to ${category.label}`
                : `${submittingUser.data().firstName} added an expense of \$${expenseData.amount}`
            const linkedAccounts = submittingUser.data().linkedAccounts;

            if (linkedAccounts && linkedAccounts.length > 0) {
                const notifications = linkedAccounts.map(async (user) => {
                    await createNotification(
                        user.id,
                        "New Expense Added",
                        messageBody,
                        { type: "newExpense", expenseId: event.params.expenseId, ledgerId: event.params.ledgerId }
                    );
                });

                await Promise.all(notifications);
            }
        } catch (e) {
            logger.error(e);
        }
    }
);



// On a share request, find the user an create a notification on their account
exports.triggerShareExpenseNotification = onDocumentCreated(
    "/pendingShareRequests/{documentId}",
    async (event) => {
        try {
            const requestData = event.data.data();
            const targetEmail = requestData.targetEmail;
            if (!targetEmail) {
                logger.error("no email address provided");
                return null;
            }

            const userQuery = await getFirestore()
                .collection("expenseUsers")
                .where("email", "==", targetEmail)
                .limit(1)
                .get();
            if (userQuery.empty) {
                logger.warn("no user found with provided email");
                return null;
            }

            const requesterDoc = await getFirestore()
                .collection("expenseUsers")
                .doc(requestData.requestingUser)
                .get();
            if (!requesterDoc.exists) {
                logger.warn("requesting user not found");
                return null;
            }

            const userDoc = userQuery.docs[0];
            const requesterData = requesterDoc.data();
            const userData = userDoc.data();
            await event.data.ref.update({
                targetUserId: userDoc.id,
                requestingUserEmail: requesterData.email,
                targetCurrentLedgerId: userData.ledgerId,
                requestingUserLedgerId: requesterData.ledgerId,
            });

            await userDoc.ref.update({
                notification: {
                    type: "pendingRequest",
                    data: { requestId: event.data.id },
                },
            });
        } catch (e) {
            logger.error(e);
            return null;
        }
    }
);

exports.sendReactionNotification = onCall(async (request) => {
    try {
        const userId = request.data["id"]
        const reaction = request.data['reactionEmoji']
        logger.debug(userId)
        const targetSnapshot = await getFirestore()
            .collection("expenseUsers")
            .doc(userId)
            .get();

        if (!targetSnapshot.exists) {
            logger.warn(
                `Expense user ${userId} not found for reaction notification.`
            );
            return { success: false, message: 'User does not exist' };
        }

        const data = targetSnapshot.data()
        const name = data.firstName

        const body = `${name} reacted to your expense with ${reaction}!`
        
        await createNotification(
            userId,
            "New Reaction!",
            body,
            { type: "newReaction", reaction: reaction }
        );

        return { success: true, message: "Reaction notification created" }
    } catch (e) {
        logger.error(e)
        return { success: false, message: e}
    }
})

exports.triggerLinkedAccount = onCall(async (request) => {
    try {
        const acceptedRequestSnapshot = await getFirestore()
            .collection("pendingShareRequests")
            .doc(request.data["requestId"])
            .get();

        // Unpack request
        const acceptedRequest = acceptedRequestSnapshot.data();
        logger.log(acceptedRequest);

        // Get the "accepting" user's data
        const targetUserRef = await getFirestore()
            .collection("expenseUsers")
            .doc(acceptedRequest.targetUserId)
            .get();

        const targetUser = targetUserRef.data();
        logger.log(targetUser);
        // Write it to the "requesting" user
        await getFirestore()
            .collection("expenseUsers")
            .doc(acceptedRequest.requestingUser)
            .update({
                linkedAccounts: FieldValue.arrayUnion({
                    id: acceptedRequest.targetUserId,
                    email: targetUser.email,
                    firstName: targetUser.firstName,
                    lastName: targetUser.lastName,
                    color: targetUser.userSettings?.color ?? "255, 60, 75, 175",
                }),
            });

        // Get the "requesting" user's data
        const sourceUserRef = await getFirestore()
            .collection("expenseUsers")
            .doc(acceptedRequest.requestingUser)
            .get();

        const sourceUser = sourceUserRef.data();
        logger.log(sourceUser);
        // Write it to the "accepting" user
        await getFirestore()
            .collection("expenseUsers")
            .doc(acceptedRequest.targetUserId)
            .update({
                linkedAccounts: FieldValue.arrayUnion({
                    id: acceptedRequest.requestingUser,
                    email: sourceUser.email,
                    firstName: sourceUser.firstName,
                    lastName: sourceUser.lastName,
                    color: sourceUser.userSettings?.color ?? "255, 60, 75, 175",
                }),
            });

        // Remove Request
        await getFirestore()
            .collection("pendingShareRequests")
            .doc(request.data["requestId"])
            .delete();
    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

// On cancelling a pending request, remove the target users notification
exports.clearLinkRequest = onCall(async (request) => {
    try {
        await getFirestore()
            .collection("expenseUsers")
            .doc(request.data["targetId"])
            .update({ notification: null });
    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

// On unlink, restore the secondary user's ledger
exports.unlinkRequest = onCall(async (request) => {
    try {
        // TARGET ID = TARGET ACCOUNT ID
        // initiatorId = INITIATOR ACCOUNT ID
        const targetDocRef = getFirestore()
            .collection("expenseUsers")
            .doc(request.data["targetId"]);

        const targetSnapshot = await targetDocRef.get();
        const targetDoc = targetSnapshot.data(); // GET TARGET's DATA

        const restoreLedgerId = targetDoc.backupLedgerId;
        const sourceUser = targetDoc.linkedAccounts.find(
            (account) => account.id === request.data["initiatorId"]
        );
        console.log(sourceUser)
        const sourceEmail = sourceUser?.email || "A linked account";
        const updatedLinkedAccounts = targetDoc.linkedAccounts.filter(
            (account) => account.id != request.data["initiatorId"]
        );
        console.log(updatedLinkedAccounts.length)

        let update;
        if (targetDoc.role === "primary") {
            update = {
                linkedAccounts: updatedLinkedAccounts,
                archivedLinkedAccounts: FieldValue.arrayUnion(sourceUser),
                notification: {
                    // notification
                    type: "primaryUnlink",
                    data: { email: sourceEmail },
                },
            };
        } else if (targetDoc.role === "secondary") {
            update = {
                linkedAccounts: updatedLinkedAccounts,
                role: "primary",
                backupLedgerId: null,
                ledgerId: restoreLedgerId,
                archivedLinkedAccounts: FieldValue.arrayUnion(sourceUser),
                notification: {
                    type: "secondaryUnlink",
                    data: { email: sourceEmail },
                },
            };
        }

        await targetDocRef.update(update);
    } catch (e) {
        logger.error(e);
        return false;
    }
    return true;
});

// On updating color, notify all linked accounts
exports.updateLinkedAccounts = onCall(async (request) => {
    try {
        const ids = request.data["ids"]
        const sourceId = request.data["self"];
        const color = request.data["color"];

        await Promise.all(
            ids.map(async (id) => {
                const targetRef = getFirestore()
                    .collection("expenseUsers")
                    .doc(id);

                const targetSnapshot = await targetRef.get();
                const targetData = targetSnapshot.data();
                const updatedAccounts = targetData.linkedAccounts.map(
                    (linkedAccount) => linkedAccount.id !== sourceId
                        ?linkedAccount
                        : { ...linkedAccount, color }
                );
                return targetRef.update({ linkedAccounts: updatedAccounts });
            })
        );
    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

exports.promoteAccount = onCall(async (request) => {
    try {
        const id = request.data["id"];
        const removeId = request.data["removeId"];
        const targetRef = getFirestore()
            .collection("expenseUsers")
            .doc(id);

        const targetSnapshot = await targetRef.get();
        const updatedLinkedAccounts = (targetSnapshot.data().linkedAccounts || []).filter(
            (account) => account.id !== removeId
        );

        await targetRef.update({
            role: "primary",
            backupLedgerId: null,
            linkedAccounts: updatedLinkedAccounts,
        });
    } catch (e) {
        logger.error(e);
        return false;
    }
    return true;

});

exports.createAmortizedExpenses = onCall(async (request) => {
    logger.info("Starting createAmortizedExpenses function");

    if (!request.auth) {
        logger.error("User is not authenticated.");
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const { template, firstExpenseId, groupId, months, ledgerId } = request.data;
    const db = getFirestore();

    if (!template || !firstExpenseId || !groupId || !months || !ledgerId) {
        logger.error("Missing required data in payload.", request.data);
        throw new functions.https.HttpsError("invalid-argument", "The function must be called with all required arguments.");
    }

    const monthlyAmount = template.amount / months;
    const templateDate = template.date && template.date._seconds
        ? new Date(template.date._seconds * 1000)
        : new Date(template.date);
    const originalDate = templateDate;
    let nextId = null;
    
    const expensePaths = [];
    const summaryUpdates = [];

    try {
        // Add first expense to the manifest
        const firstExpenseCollectionName = monthKey(originalDate);
        expensePaths.push(`ledger/${ledgerId}/${firstExpenseCollectionName}/${firstExpenseId}`);
        summaryUpdates.push({
            path: `ledger/${ledgerId}/summaries/${firstExpenseCollectionName}_${template.categoryId}`,
            amount: monthlyAmount,
        });

        for (let i = months; i >= 2; i--) {
            const expenseDate = new Date(originalDate);
            expenseDate.setMonth(originalDate.getMonth() + i - 1);

            const collectionName = monthKey(expenseDate);

            const expenseData = {
                ...template,
                amount: monthlyAmount,
                date: expenseDate.toISOString(),
                amortized: {
                    groupId: groupId,
                    index: i,
                    over: months,
                    nextId: nextId,
                },
                submittedBy: request.auth.uid,
            };
            delete expenseData.id;

            const newDocRef = await db.collection("ledger").doc(ledgerId).collection(collectionName).add(expenseData);
            nextId = newDocRef.id;

            expensePaths.push(newDocRef.path);

            const summaryId = `${collectionName}_${template.categoryId}`;
            const summaryRef = db.collection("ledger").doc(ledgerId).collection("summaries").doc(summaryId);
            summaryUpdates.push({ path: summaryRef.path, amount: monthlyAmount });

            // Atomic create-or-increment: no read-then-write, no overwrite race.
            await summaryRef.set({
                startDate: new Date(expenseDate.getFullYear(), expenseDate.getMonth()),
                categoryId: template.categoryId,
                total: FieldValue.increment(monthlyAmount),
                count: FieldValue.increment(1),
                lastUpdate: FieldValue.serverTimestamp(),
            }, { merge: true });
        }

        const firstExpenseRef = db.doc(expensePaths[0]);
        await firstExpenseRef.update({ "amortized.nextId": nextId });

        // Create the manifest
        const manifestRef = db.collection("ledger").doc(ledgerId).collection("amortization_series").doc(groupId);
        await manifestRef.set({
            expensePaths: expensePaths.reverse(), // Reverse to have them in chronological order
            summaryUpdates,
            createdAt: FieldValue.serverTimestamp(),
        });

        logger.info("Successfully created all amortized expenses and manifest.");
        return { success: true };
    } catch (error) {
        logger.error("Error creating amortized expenses:", error);
        throw new functions.https.HttpsError("internal", "An error occurred while creating the amortized expenses.");
    }
});

exports.deleteAmortizedSeries = onCall(async (request) => {
    logger.info("Starting deleteAmortizedSeries function");

    if (!request.auth) {
        logger.error("User is not authenticated.");
        throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const { groupId, ledgerId, updateId } = request.data;
    if (!groupId || !ledgerId) {
        logger.error("Missing groupId or ledgerId in payload.", request.data);
        throw new functions.https.HttpsError("invalid-argument", "Missing groupId or ledgerId.");
    }
    
    const db = getFirestore();
    const manifestRef = db.collection("ledger").doc(ledgerId).collection("amortization_series").doc(groupId);

    try {
        const manifestDoc = await manifestRef.get();
        if (!manifestDoc.exists) {
            logger.error(`Amortization manifest not found for groupId: ${groupId}`);
            throw new functions.https.HttpsError("not-found", "Amortization series not found.");
        }

        const manifestData = manifestDoc.data();
        const batch = db.batch();

        // Delete all expenses in the series
        manifestData.expensePaths.forEach(path => {
            if (updateId && path.includes(updateId)) {
                return
            }
            batch.delete(db.doc(path));
        });

        // Decrement all summary documents. Using set(merge:true) instead of
        // update() means a missing summary no longer throws and aborts the
        // whole batch; any resulting drift is repairable by reconciliation.
        manifestData.summaryUpdates.forEach(update => {
            batch.set(db.doc(update.path), {
                total: FieldValue.increment(-update.amount),
                count: FieldValue.increment(-1),
                lastUpdate: FieldValue.serverTimestamp(),
            }, { merge: true });
        });

        // Delete the manifest itself
        batch.delete(manifestRef);

        await batch.commit();
        logger.info(`Successfully deleted amortization series with groupId: ${groupId}`);
        return { success: true };

    } catch (error) {
        logger.error(`Error deleting amortization series ${groupId}:`, error);
        throw new functions.https.HttpsError("internal", "An error occurred while deleting the expense series.");
    }
});

/**
 * Recomputes category-month summaries from the raw transaction documents,
 * writing absolute count/total values (idempotent) and deleting summaries whose
 * bucket has no raw transactions so no phantom count:0 bucket lingers.
 *
 * @param {FirebaseFirestore.Firestore} db Firestore instance.
 * @param {string} ledgerId The ledger to reconcile.
 * @param {{month: string, categoryId: string}|null} filter When provided,
 *   only that single category-month bucket is reconciled; otherwise the whole
 *   ledger is swept.
 * @return {Promise<{reconciled: number, deleted: number}>} Counts of buckets
 *   written and empty summaries removed.
 */
async function reconcileLedgerSummaries(db, ledgerId, filter = null) {
    const ledgerRef = db.collection("ledger").doc(ledgerId);

    // Determine which monthly collections to scan.
    let monthCollections;
    if (filter) {
        monthCollections = [ledgerRef.collection(filter.month)];
    } else {
        const all = await ledgerRef.listCollections();
        monthCollections = all.filter((c) => MONTH_COLLECTION_RE.test(c.id));
    }

    // buckets: summaryId -> { month, categoryId, count, total, startDate }
    const buckets = new Map();
    for (const monthCol of monthCollections) {
        const snap = await monthCol.get();
        snap.forEach((doc) => {
            const data = doc.data();
            const categoryId = data.categoryId;
            if (!categoryId) return;
            if (filter && categoryId !== filter.categoryId) return;
            const summaryId = `${monthCol.id}_${categoryId}`;
            const date = toDate(data.date);
            const startDate = date
                ? new Date(date.getFullYear(), date.getMonth())
                : null;
            const existing = buckets.get(summaryId);
            if (existing) {
                existing.count += 1;
                existing.total += Number(data.amount) || 0;
                if (!existing.startDate && startDate) existing.startDate = startDate;
            } else {
                buckets.set(summaryId, {
                    month: monthCol.id,
                    categoryId,
                    count: 1,
                    total: Number(data.amount) || 0,
                    startDate,
                });
            }
        });
    }

    const summariesRef = ledgerRef.collection("summaries");
    let reconciled = 0;
    let deleted = 0;

    // Collect write operations, then commit in chunks to stay under the
    // 500-operation Firestore batch limit for large/old ledgers.
    const ops = [];

    // Write absolute values for every bucket that has raw transactions.
    for (const [summaryId, b] of buckets) {
        ops.push((batch) =>
            batch.set(
                summariesRef.doc(summaryId),
                {
                    startDate: b.startDate,
                    categoryId: b.categoryId,
                    count: b.count,
                    total: b.total,
                    lastUpdate: FieldValue.serverTimestamp(),
                },
                { merge: true }
            )
        );
        reconciled += 1;
    }

    // Delete summaries whose bucket has no raw transactions (empty bucket).
    if (filter) {
        if (!buckets.has(`${filter.month}_${filter.categoryId}`)) {
            const emptyDoc = await summariesRef
                .doc(`${filter.month}_${filter.categoryId}`)
                .get();
            if (emptyDoc.exists) {
                ops.push((batch) => batch.delete(emptyDoc.ref));
                deleted += 1;
            }
        }
    } else {
        const existingSummaries = await summariesRef.get();
        existingSummaries.forEach((doc) => {
            if (!buckets.has(doc.id)) {
                ops.push((batch) => batch.delete(doc.ref));
                deleted += 1;
            }
        });
    }

    const CHUNK = 450;
    for (let i = 0; i < ops.length; i += CHUNK) {
        const batch = db.batch();
        for (const op of ops.slice(i, i + CHUNK)) op(batch);
        await batch.commit();
    }

    return { reconciled, deleted };
}

/**
 * Reconciles a single category-month summary from its raw transactions.
 * Request data: { ledgerId, month ("YYYY_MON"), categoryId }.
 */
exports.reconcileSummary = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const { ledgerId, month, categoryId } = request.data || {};
    if (!ledgerId || !month || !categoryId) {
        throw new HttpsError("invalid-argument", "ledgerId, month and categoryId are required.");
    }
    if (!MONTH_COLLECTION_RE.test(month)) {
        throw new HttpsError("invalid-argument", `month must look like "YYYY_MON", got "${month}".`);
    }
    try {
        const db = getFirestore();
        const result = await reconcileLedgerSummaries(db, ledgerId, { month, categoryId });
        logger.info(`reconcileSummary ${ledgerId}/${month}_${categoryId}:`, result);
        return { success: true, ...result };
    } catch (error) {
        logger.error(`Error reconciling summary ${ledgerId}/${month}_${categoryId}:`, error);
        throw new HttpsError("internal", "An error occurred while reconciling the summary.");
    }
});

/**
 * Reconciles every category-month summary for a ledger from raw transactions.
 * Heals ledgers corrupted before the integrity fixes were in place.
 * Request data: { ledgerId }.
 */
exports.reconcileLedger = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const { ledgerId } = request.data || {};
    if (!ledgerId) {
        throw new HttpsError("invalid-argument", "ledgerId is required.");
    }
    try {
        const db = getFirestore();
        const result = await reconcileLedgerSummaries(db, ledgerId);
        logger.info(`reconcileLedger ${ledgerId}:`, result);
        return { success: true, ...result };
    } catch (error) {
        logger.error(`Error reconciling ledger ${ledgerId}:`, error);
        throw new HttpsError("internal", "An error occurred while reconciling the ledger.");
    }
});

/**
 * Reconciles a batch of category-month summaries in a single call. Used by the
 * client to lazily self-heal the buckets a Spending Report is about to show,
 * so opening a report costs one round trip instead of one per month.
 * Request data: { ledgerId, buckets: [{ month ("YYYY_MON"), categoryId }] }.
 */
exports.reconcileSummaries = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
    }
    const { ledgerId, buckets } = request.data || {};
    if (!ledgerId || !Array.isArray(buckets) || buckets.length === 0) {
        throw new HttpsError("invalid-argument", "ledgerId and a non-empty buckets array are required.");
    }
    for (const b of buckets) {
        if (!b || !b.month || !b.categoryId) {
            throw new HttpsError("invalid-argument", "each bucket needs month and categoryId.");
        }
        if (!MONTH_COLLECTION_RE.test(b.month)) {
            throw new HttpsError("invalid-argument", `month must look like "YYYY_MON", got "${b.month}".`);
        }
    }
    try {
        const db = getFirestore();
        let reconciled = 0;
        let deleted = 0;
        for (const b of buckets) {
            const result = await reconcileLedgerSummaries(db, ledgerId, {
                month: b.month,
                categoryId: b.categoryId,
            });
            reconciled += result.reconciled;
            deleted += result.deleted;
        }
        logger.info(`reconcileSummaries ${ledgerId}: ${buckets.length} buckets`, { reconciled, deleted });
        return { success: true, reconciled, deleted };
    } catch (error) {
        logger.error(`Error reconciling summaries ${ledgerId}:`, error);
        throw new HttpsError("internal", "An error occurred while reconciling summaries.");
    }
});

exports.sendBudgetNotification = onCall(async (request) => {
    logger.info("Starting sendBudgetNotification function");

    try {
        const { userIds, amount, categoryLabel, notificationType } = request.data;

        if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
            throw new functions.https.HttpsError("invalid-argument", "userIds must be a non-empty array.");
        }
        if (amount === undefined || amount === null) {
            throw new functions.https.HttpsError("invalid-argument", "amount is required.");
        }
        if (!categoryLabel) {
            throw new functions.https.HttpsError("invalid-argument", "categoryLabel is required.");
        }
        if (!notificationType) {
            throw new functions.https.HttpsError("invalid-argument", "notificationType is required.");
        }

        const db = getFirestore();
        
        for (const userId of userIds) {
            logger.debug(userId)
            try {
                const userSnapshot = await db
                    .collection("expenseUsers")
                    .doc(userId)
                    .get();

                if (!userSnapshot.exists) {
                    logger.warn(`User ${userId} not found`);
                    continue;
                }

                const userData = userSnapshot.data();
                const userSettings = userData.userSettings || {};
                const notificationSettings = userSettings.notification || {};

                // Check if notifications are enabled for this type
                if (!notificationSettings[notificationType]) {
                    logger.info(`Notification type ${notificationType} disabled for user ${userId}`);
                    continue;
                }

                const token = userData.fcmToken;
                if (!token) {
                    logger.warn(`User ${userId} does not have an FCM token`);
                    continue;
                }

                let title, body;
                if (notificationType === "overspendingIndividualBudget") {
                    title = `Oh no, the budget for ${categoryLabel} as been exceeded`;
                    body = `An expense has been added for ${amount}, making you overbudget in ${categoryLabel}`;
                } else if (notificationType === "overspendingTotalBudget") {
                    title = "Uh oh, the monthly budget has been blown!";
                    body = `An expense has been added for ${amount} to ${categoryLabel} making you over budget for the month`;
                } else {
                    logger.warn(`Unknown notification type: ${notificationType}`);
                    continue;
                }
                
                await createNotification(
                    userId,
                    title,
                    body,
                    { type: notificationType, category: categoryLabel, amount: amount }
                );

            } catch (error) {
                logger.error(`Error processing user ${userId}:`, error);
            }
        }

        logger.info(`Successfully processed budget notifications`);
        return { success: true };
    } catch (e) {
        logger.error("Error in sendBudgetNotification:", e);
        throw new functions.https.HttpsError("internal", "An error occurred while sending notifications");
    }
});