const express = require("express");
const router = express.Router();
const notificationController = require("../controllers/notification.controller");
const { verifyToken } = require("../middleware/auth.middleware");

// Apply auth middleware to all routes
router.use(verifyToken);

// Get user notifications
router.get("/", notificationController.getUserNotifications);

// Mark as read
router.put("/read", notificationController.markAsRead);

// Delete notification
router.delete("/:notificationId", notificationController.deleteNotification);

module.exports = router;
