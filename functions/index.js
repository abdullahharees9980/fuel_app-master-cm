const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();

exports.sendOrderAcceptedNotification = onDocumentUpdated(
    "orders/{orderId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (before.status !== "accepted" && after.status === "accepted") {
        const orderId = event.params.orderId;
        const userId = after.userId;

        const db = getFirestore();
        const userDoc = await db.collection("users").doc(userId).get();

        if (!userDoc.exists) {
          logger.info("User doc not found for userId:", userId);
          return;
        }

        const userData = userDoc.data();
        const fcmToken = userData && userData.fcmToken;
        if (!fcmToken) {
          logger.info("No FCM token for user:", userId);
          return;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: "Order Accepted!",
            body: `Your order ${orderId} has been accepted.`,
          },
          data: {
            type: "order_accepted",
            orderId: orderId,
          },
        };

        await getMessaging().send(message);
        logger.info(
            "Notification sent to user:", userId,
        );
      }
    },
);
