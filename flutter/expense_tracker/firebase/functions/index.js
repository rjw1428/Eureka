
const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/firestore");

initializeApp();

exports.initializeExpenseTrackerAccount = onCall(async (request) => {
    try {
    const ledgerSnapshot = await getFirestore()
        .collection("ledger")
        .add({ budgetConfig: {} });

    await getFirestore()
        .collection("expenseUsers")
        .doc(request.data["userId"])
        .set({
            role: "primary",
            email: request.data["email"],
            ledgerId: ledgerSnapshot.id,
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
            pendingRequest: event.data.id
        })
    } catch(e) {
        logger.error(e);
        return null;
    }
});

exports.triggerLinkedAccount = onCall(async (request) => {
    try {
        logger.log(request.data['requestId'])
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
            .update({pendingRequest: null})


    } catch (e) {
        logger.error(e);
        return false;
    }

    return true;
});