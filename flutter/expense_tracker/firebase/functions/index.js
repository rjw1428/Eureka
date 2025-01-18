
const { onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

exports.initializeExpenseTrackerAccount = onCall(async (request) => {
    logger.info(JSON.stringify(request.data));
    logger.info(request.data["userId"]);
    logger.info(request.data["email"]);

    const ledgerSnapshot = await getFirestore()
        .collection("ledger")
        .add({ budgetConfig: {} });

    const userSnapshot = await getFirestore()
        .collection("expenseUsers")
        .doc(request.data["userId"])
        .set({
            role: "primary",
            email: request.data["email"],
            ledgerId: ledgerSnapshot.id,
            userSettings: {},
        });

    return userSnapshot.writeTime;
});
