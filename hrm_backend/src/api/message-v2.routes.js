const express = require("express");
const router = express.Router();
const messageController = require("../controllers/message-v2.controller");
const { verifyToken } = require("../middleware/auth.middleware");

// Apply authentication middleware to all routes
router.use(verifyToken);

// Send message to conversation
router.post("/", messageController.sendMessage);

// Get conversation messages
router.get(
  "/conversation/:conversationId",
  messageController.getConversationMessages
);

// Mark message as read
router.patch("/:messageId/read", messageController.markMessageAsRead);

// Note: Message editing and deletion are disabled for organizational security
// Once a message is sent, it cannot be modified or deleted

module.exports = router;
