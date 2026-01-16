const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

initializeApp();

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
                    const linkedUser = await getFirestore()
                        .collection("expenseUsers")
                        .doc(user.id)
                        .get();

                    if (!linkedUser.exists) {
                        logger.warn(`Linked user ${user.id} not found.`);
                        return;
                    }

                    const token = linkedUser.data().fcmToken;
                    if (!token) {
                        logger.warn(`User ${user.id} does not have a token.`);
                        return;
                    }

                    const message = {
                        notification: {
                            title: "New Expense Added",
                            body: messageBody,
                        },
                        token: token,
                    };
                    return getMessaging().send(message);
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
        const token = data.fcmToken
        const name = data.firstName

        const body = `${name} reacted to your expense with ${reaction}!`
        logger.debug(`Sending reaction message ${body} to ${userId}`)
        if (!token) {
            logger.warn('User does not have a token')
           return { success: false, message: 'User does not have a token saved' }; 
        }
        const message = {
            notification: {
                title: "New Reaction!",
                body,
            },
            token: token,
        };
        const resp = await getMessaging().send(message)
        logger.log(`Message Status: ${resp}`)
        return { success: true, message: resp}
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
    const originalDate = new Date(template.date);
    let nextId = null;
    
    const expensePaths = [];
    const summaryUpdates = [];

    try {
        // Add first expense to the manifest
        const firstExpenseMonthStr = new Intl.DateTimeFormat('en-US', { month: 'short' }).format(originalDate).toUpperCase();
        const firstExpenseCollectionName = `${originalDate.getFullYear()}_${firstExpenseMonthStr}`;
        expensePaths.push(`ledger/${ledgerId}/${firstExpenseCollectionName}/${firstExpenseId}`);
        summaryUpdates.push({
            path: `ledger/${ledgerId}/summaries/${firstExpenseCollectionName}_${template.categoryId}`,
            amount: monthlyAmount,
        });

        for (let i = months; i >= 2; i--) {
            const expenseDate = new Date(originalDate);
            expenseDate.setMonth(originalDate.getMonth() + i - 1);

            const monthFormatter = new Intl.DateTimeFormat('en-US', { month: 'short' });
            const monthStr = monthFormatter.format(expenseDate).toUpperCase();
            const collectionName = `${expenseDate.getFullYear()}_${monthStr}`;

            const expenseData = {
                ...template,
                amount: monthlyAmount,
                date: expenseDate,
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
            
            const summaryDoc = await summaryRef.get();

            if (!summaryDoc.exists) {
                await summaryRef.set({
                    startDate: new Date(expenseDate.getFullYear(), expenseDate.getMonth()),
                    categoryId: template.categoryId,
                    total: 0,
                    count: 0,
                });
            }

            await summaryRef.update({
                total: FieldValue.increment(monthlyAmount),
                count: FieldValue.increment(1),
                lastUpdate: FieldValue.serverTimestamp(),
            });
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

        // Decrement all summary documents
        manifestData.summaryUpdates.forEach(update => {
            batch.update(db.doc(update.path), {
                total: FieldValue.increment(-update.amount),
                count: FieldValue.increment(-1),
            });
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
        const messaging = getMessaging();
        const notifications = [];
        let sentCount = 0;

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
                if (!userSettings[`notification.${notificationType}`]) {
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

                const message = {
                    notification: {
                        title,
                        body,
                    },
                    token,
                };

                notifications.push(
                    messaging.send(message).then(() => {
                        sentCount++;
                    }).catch((err) => {
                        logger.error(`Failed to send notification to user ${userId}:`, err);
                    })
                );
            } catch (error) {
                logger.error(`Error processing user ${userId}:`, error);
            }
        }

        await Promise.all(notifications);
        logger.info(`Successfully sent ${sentCount} budget notifications`);
        return { success: true, sentCount };
    } catch (e) {
        logger.error("Error in sendBudgetNotification:", e);
        throw new functions.https.HttpsError("internal", "An error occurred while sending notifications");
    }
});