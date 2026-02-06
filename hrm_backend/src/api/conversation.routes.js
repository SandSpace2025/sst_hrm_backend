const express = require("express");
const router = express.Router();
const conversationController = require("../controllers/conversation.controller");
const { verifyToken } = require("../middleware/auth.middleware");

// Apply authentication middleware to all routes
router.use(verifyToken);

// Create new conversation
router.post("/", conversationController.createConversation);

// Get user conversations
router.get("/", conversationController.getUserConversations);

// Get specific conversation
router.get("/:conversationId", conversationController.getConversation);

// Add participant to conversation
router.post(
  "/:conversationId/participants",
  conversationController.addParticipant
);

// Remove participant from conversation
router.delete(
  "/:conversationId/participants",
  conversationController.removeParticipant
);

// Mark conversation as read
router.patch(
  "/:conversationId/read",
  conversationController.markAsRead
);

// Note: Conversation archiving and deletion are disabled for organizational security
// Conversations and messages are permanent records for audit purposes

module.exports = router;
