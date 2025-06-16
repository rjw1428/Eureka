const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/firestore");
const functions = require('firebase-functions/v1');

initializeApp();

// Create a ledger for new users and add to account
exports.initializeExpenseTrackerAccount = functions.auth.user().onCreate(async (user) => {
    const now = new Date().toISOString();
    const userId = user.uid;
    const email = user.email;
    console.log(JSON.stringify(user));
    const displayNameParts = user.displayName ? user.displayName.split(" ") : [];
    try {
        const ledgerSnapshot = await getFirestore().collection("ledger").add({
            budgetConfig: {},
            initialized: now,
        });

        let data = {
            role: "primary",
            email,
            ledgerId: ledgerSnapshot.id,
            initialized: now,
            linkedAccounts: [],
            archivedLinkedAccounts: [],
            userSettings: {},
        };
        
        if (displayNameParts.length > 0) {
            const firstName = displayNameParts[0];
            const lastName =  displayNameParts[1];
            data["firstName"] = firstName || "New";
            data["lastName"] = lastName || "User";
        }

        await getFirestore()
            .collection("expenseUsers")
            .doc(userId)
            .set(data, { merge: true });
    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

// Create a summary entry on writing an expense (currently only used in migration and will be removed)
// exports.updateSummaryOnCreate = onDocumentCreated('/ledger/{ledgerId}/{timeframe}/{documentId}', async (event) => {
//     const doc = event.data.data();
//     try {
//         const ledgerId = event.params.ledgerId
//         const summaryId = `${event.params.timeframe}_${doc.categoryId}`
//         const summaryRef = getFirestore().doc(`/ledger/${ledgerId}/summaries/${summaryId}`)
//         const summarySnapshot = await summaryRef.get()

//         if (summarySnapshot.exists) {
//             return summaryRef.update({
//                 count: FieldValue.increment(1),
//                 total: FieldValue.increment(doc.amount),
//                 lastUpdate: new Date(doc.date)
//             })
//         }

//         return summaryRef.set({
//             startDate: new Date(doc.date),
//             categoryId: doc.categoryId,
//             count: FieldValue.increment(1),
//             total: FieldValue.increment(doc.amount),
//             lastUpdate: new Date(doc.date)
//         })
//     } catch (e) {
//         logger.error(e);
//         logger.log(JSON.stringify(doc))
//         return null
//     }
// })

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
        const ids = request.data["ids"];
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

})