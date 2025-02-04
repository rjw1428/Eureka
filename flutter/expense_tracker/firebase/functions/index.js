
const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { onDocumentCreated } = require("firebase-functions/firestore");

initializeApp();

exports.initializeExpenseTrackerAccount = onCall(async (request) => {
    const now = new Date().toISOString()
    try {
        const ledgerSnapshot = await getFirestore()
            .collection("ledger")
            .add({
                budgetConfig: {}, 
                initialized: now 
            });

        await getFirestore()
            .collection("expenseUsers")
            .doc(request.data["userId"])
            .set({
                role: "primary",
                email: request.data["email"],
                firstName: request.data["firstName"],
                lastName: request.data["lastName"],
                ledgerId: ledgerSnapshot.id,
                initialized: now,
                userSettings: {},
            });
    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

exports.triggerShareExpenseNotification = onDocumentCreated('/pendingShareRequests/{documentId}', async (event) =>  {
    try {
        const requestData = event.data.data();
        const targetEmail = requestData.targetEmail;
        if (!targetEmail) {
            logger.error('no email address provided')
            return null
        }

        const userQuery = await getFirestore().collection('expenseUsers').where('email', "==", targetEmail).limit(1).get();
        if (userQuery.empty) {
            logger.warn('no user found with provided email');
            return null;
        }

        const requesterDoc = await getFirestore().collection('expenseUsers').doc(requestData.requestingUser).get();
        if (!requesterDoc.exists) {
            logger.warn('requesting user not found');
            return null;
        }
        
        const userDoc = userQuery.docs[0];
        const requesterData = requesterDoc.data();
        const userData = userDoc.data();
        await event.data.ref.update({
            targetUserId: userDoc.id,
            requestingUserEmail: requesterData.email,
            targetCurrentLedgerId: userData.ledgerId,
            requestingUserLedgerId: requesterData.ledgerId
        });

        await userDoc.ref.update({
            notification: {
                type: 'pendingRequest',
                data: { requestId: event.data.id }
            }
        })
    } catch(e) {
        logger.error(e);
        return null;
    }
});

exports.triggerLinkedAccount = onCall(async (request) => {
    try {
        const acceptedRequestSnapshot = await getFirestore()
            .collection("pendingShareRequests")
            .doc(request.data["requestId"])
            .get()

        const acceptedRequest = acceptedRequestSnapshot.data()
        logger.log(acceptedRequest)
        await getFirestore()
            .collection("expenseUsers")
            .doc(acceptedRequest.requestingUser)
            .update({
                linkedAccounts: FieldValue.arrayUnion({
                    id: acceptedRequest.targetUserId,
                    email: acceptedRequest.targetEmail
                })
            })

        await getFirestore()
            .collection("pendingShareRequests")
            .doc(request.data["requestId"])
            .delete()
    
    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

exports.clearLinkRequest = onCall(async (request) => {
    try {
        await getFirestore()
            .collection("expenseUsers")
            .doc(request.data["targetId"])
            .update({notification: null})


    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});

exports.unlinkRequest = onCall(async (request) => {
    try {

        // TARGET ID = TARGET ACCOUNT ID
        // initiatorId = INITIATOR ACCOUNT ID
        const targetDocRef = getFirestore()
            .collection("expenseUsers")
            .doc(request.data["targetId"])
        
        const targetSnapshot = await targetDocRef.get()
        const targetDoc = targetSnapshot.data(); // GET TARGET's DATA
        logger.info(targetDoc);
        const restoreLedgerId = targetDoc.backupLedgerId
        const sourceUser = targetDoc.linkedAccounts.find((account) => account.id === request.data["initiatorId"])
        const sourceEmail = sourceUser?.email || 'A linked account';
        const updatedLinkedAccounts = targetDoc.linkedAccounts.filter((account) => account.id != request.data["initiatorId"]);
        
        let update;
        if (targetDoc.role === 'primary') {
            update = {
                linkedAccounts: updatedLinkedAccounts,
                archivedLinkedAccounts: FieldValue.arrayUnion([sourceUser]),
                notification: { // notification
                    type: 'primaryUnlink',
                    data: { email : sourceEmail }
                },
            }
        } else if (targetDoc.role === 'secondary') {
            update = {
                linkedAccounts: updatedLinkedAccounts,
                role: 'primary',
                backupLedgerId: null,
                ledgerId: restoreLedgerId,
                notification: {
                    type: 'secondaryUnlink',
                    data: { email : sourceEmail }
                },
            }
        }

        await targetDocRef.update(update);

    } catch(e) {
        logger.error(e);
        return false;
    }
    return true;
})