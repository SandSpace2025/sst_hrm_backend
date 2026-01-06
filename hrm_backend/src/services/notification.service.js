const { admin, initialized } = require("../config/firebase");

/**
 * Send a push notification to a specific device
 * @param {string} token - FCM device token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Optional data payload (e.g., matching frontend routing args)
 */
const sendNotification = async (token, title, body, data = {}) => {
    if (!initialized || !token) return;

    try {
        const message = {
            notification: {
                title,
                body,
            },
            android: {
                notification: {
                    channelId: "hrm_notifications_v2",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    priority: "high",
                    sound: "default",
                },
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                ...data,
            },
            token,
        };

        const response = await admin.messaging().send(message);
        console.log("🚀 Notification sent successfully:", response);
        return response;
    } catch (error) {
        console.error("❌ Error sending notification:", error);
        // If token is invalid, we might want to remove it from the user model (future improvement)
    }
};

/**
 * Send a push notification to multiple devices
 * @param {string[]} tokens - Array of FCM device tokens
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Optional data payload
 */
const sendMulticastNotification = async (tokens, title, body, data = {}) => {
    if (!initialized || !tokens || tokens.length === 0) return;

    try {
        const message = {
            notification: {
                title,
                body,
            },
            android: {
                notification: {
                    channelId: "hrm_notifications_v2",
                    clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    priority: "high",
                    sound: "default",
                },
            },
            data: {
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                ...data,
            },
            tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(
            `🚀 Multicast notification sent. Success: ${response.successCount}, Failure: ${response.failureCount}`
        );
        return response;
    } catch (error) {
        console.error("❌ Error sending multicast notification:", error);
    }
};

module.exports = {
    sendNotification,
    sendMulticastNotification,
};
