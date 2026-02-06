const { admin, initialized } = require("../config/firebase");
const logger = require("../core/logger");

/**
 * Send a push notification to a specific device
 * @param {string} token - FCM device token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Optional data payload (e.g., matching frontend routing args)
 */
const Notification = require("../models/notification.model");
const User = require("../models/user.model");

/**
 * Send a push notification to a specific device
 * @param {string} token - FCM device token
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Optional data payload (e.g., matching frontend routing args)
 * @param {string} userId - Optional: Explicit recipient User ID for persistence (Recommended)
 */
const sendNotification = async (
  token,
  title,
  body,
  data = {},
  userId = null,
  useDataOnly = false, // Kept for signature compatibility but ignored for now
) => {
  // 1. Persist notification to MongoDB (if userId is known)
  try {
    let user;
    if (userId) {
      user = await User.findById(userId);
    }

    // Only attempt to look up by token if we don't have a user yet and token exists
    if (!user && token) {
      user = await User.findOne({ fcmToken: token });
    }

    if (user) {
      try {
        const type = data.type || "other";
        await Notification.create({
          recipient: user._id,
          type,
          title,
          body,
          data,
          isRead: false,
        });
        // logger.info("Notification persisted to DB", { userId: user._id });
      } catch (dbError) {
        logger.error("Error persisting notification to DB", {
          error: dbError.message,
        });
      }
    }
  } catch (err) {
    logger.error("Error finding user for notification persistence", {
      error: err.message,
    });
  }

  // 2. Send FCM Push Notification
  if (!initialized || !token) {
    // logger.warn("Skipping FCM push: Not initialized or no token provided");
    return;
  }

  try {
    // ALWAYS send standard notification payload as per user request
    const message = {
      notification: {
        title,
        body,
      },
      android: {
        priority: "high", // Critical for background/terminated wake
        notification: {
          channelId: "hrm_alerts_v3",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          priority: "high",
          sound: "default",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1, // Required for background fetch/wake
            "mutable-content": 1,
          },
        },
        headers: {
          "apns-priority": "10", // High priority
        },
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        title: title,
        body: body,
        message: body,
        ...data,
      },
      fcmOptions: {
        analyticsLabel: data.type || "general",
      },
      // Optional: Set TTL for offline delivery (e.g., 24 hours)
      // android: { ttl: 86400000 },
      token,
    };

    const response = await admin.messaging().send(message);
    logger.info("Notification sent successfully", {
      messageId: response.split("/").pop(),
    });
    return response;
  } catch (error) {
    logger.error("Error sending notification", {
      code: error.code,
      error: error.message,
    });
  }
};

/**
 * Send a push notification to multiple devices
 * @param {string[]} tokens - Array of FCM device tokens
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Optional data payload
 * @param {boolean} useDataOnly - Ignored, sends standard notification
 */
const sendMulticastNotification = async (
  tokens,
  title,
  body,
  data = {},
  useDataOnly = false,
) => {
  // 1. Persist to MongoDB
  try {
    if (tokens && tokens.length > 0) {
      const users = await User.find({ fcmToken: { $in: tokens } });
      const notificationsToCreate = users.map((user) => ({
        recipient: user._id,
        type: data.type || "other",
        title,
        body,
        data,
        isRead: false,
      }));

      if (notificationsToCreate.length > 0) {
        try {
          await Notification.insertMany(notificationsToCreate);
        } catch (dbError) {
          logger.error("Error persisting multicast notifications", {
            error: dbError.message,
          });
        }
      }
    }
  } catch (err) {
    logger.error("Error finding users for multicast persistence", {
      error: err.message,
    });
  }

  // 2. Send FCM Multicast
  if (!initialized || !tokens || tokens.length === 0) return;

  try {
    const message = {
      notification: {
        title,
        body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "hrm_alerts_v3",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          priority: "high",
          sound: "default",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
          },
        },
        headers: {
          "apns-priority": "10",
        },
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        title: title,
        body: body,
        message: body,
        ...data,
      },
      fcmOptions: {
        analyticsLabel: data.type || "multicast",
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    logger.info(
      `Multicast notification sent. Success: ${response.successCount}, Failure: ${response.failureCount}`,
    );
    return response;
  } catch (error) {
    logger.error("Error sending multicast notification", {
      error: error.message,
    });
  }
};

module.exports = {
  sendNotification,
  sendMulticastNotification,
};
