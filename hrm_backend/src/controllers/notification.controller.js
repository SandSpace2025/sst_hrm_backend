const Notification = require("../models/notification.model");
const logger = require("../core/logger");

/**
 * Get paginated notifications for the logged-in user
 */
exports.getUserNotifications = async (req, res) => {
  try {
    const userId = req.userId;
    const { page = 1, limit = 20 } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const notifications = await Notification.find({ recipient: userId })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Notification.countDocuments({ recipient: userId });
    const unreadCount = await Notification.countDocuments({
      recipient: userId,
      isRead: false,
    });

    res.status(200).json({
      notifications,
      total,
      unreadCount,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    });
  } catch (error) {
    logger.error("Error fetching notifications", { error: error.message });
    res.status(500).json({ message: error.message });
  }
};

/**
 * Mark a single notification or all notifications as read
 */
exports.markAsRead = async (req, res) => {
  try {
    const userId = req.userId;
    const { notificationId } = req.body;

    if (notificationId) {
      // Mark specific notification
      await Notification.findOneAndUpdate(
        { _id: notificationId, recipient: userId },
        { isRead: true, readAt: new Date() },
      );
    } else {
      // Mark all as read
      await Notification.updateMany(
        { recipient: userId, isRead: false },
        { isRead: true, readAt: new Date() },
      );
    }

    res.status(200).json({ message: "Notifications marked as read" });
  } catch (error) {
    logger.error("Error marking notifications as read", {
      error: error.message,
    });
    res.status(500).json({ message: error.message });
  }
};

/**
 * Delete a notification
 */
exports.deleteNotification = async (req, res) => {
  try {
    const userId = req.userId;
    const { notificationId } = req.params;

    const result = await Notification.findOneAndDelete({
      _id: notificationId,
      recipient: userId,
    });

    if (!result) {
      return res.status(404).json({ message: "Notification not found" });
    }

    res.status(200).json({ message: "Notification deleted" });
  } catch (error) {
    logger.error("Error deleting notification", { error: error.message });
    res.status(500).json({ message: error.message });
  }
};
