/* eslint-disable */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendCustomNotification = functions.https.onCall(
  async (data, context) => {
    // Expected input:
    // data.emails: an array of target user emails
    // data.title: notification title
    // data.body: notification body
    const targetEmails = data.emails;
    const notificationTitle = data.title;
    const notificationBody = data.body;

    if (!Array.isArray(targetEmails) || targetEmails.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "No target emails provided."
      );
    }

    // Query Firestore for users with emails matching targetEmails
    const usersSnapshot = await admin
      .firestore()
      .collection("users")
      .where("email", "in", targetEmails)
      .get();

    let tokens = [];
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      if (userData.tokens && Array.isArray(userData.tokens)) {
        tokens = tokens.concat(userData.tokens);
      }
    });

    if (tokens.length === 0) {
      return {
        success: false,
        message: "No tokens found for these users.",
      };
    }

    // Build the notification payload
    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        type: "custom_notification",
      },
    };

    // Send the notification to all tokens
    const response = await admin.messaging().sendToDevice(tokens, payload);
    return { success: true, response };
  }
);
