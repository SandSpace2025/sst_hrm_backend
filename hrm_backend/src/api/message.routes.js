const express = require("express");
const router = express.Router();
const messageController = require("../controllers/message.controller");
const authMiddleware = require("../middleware/auth.middleware");

// All message routes require authentication
router.use(authMiddleware.verifyToken);

// Get message statistics (MUST come before /:messageId routes)
router.get("/stats", messageController.getMessageStats);

// Get employees list for messaging
router.get("/employees", messageController.getEmployeesForMessaging);

// Get HR list for messaging
router.get("/hr-users", messageController.getHRForMessaging);

// Get conversation with specific user (using simple conversationId format)
router.get(
  "/conversation/:userId/:userType",
  messageController.getAdminConversationSimple
);

// Send message to employee (Admin only)
router.post("/send-to-employee", messageController.sendMessageToEmployee);

// Send message to HR (Admin to HR)
router.post("/send-to-hr", messageController.sendMessageToHR);

// Mark multiple messages as read
router.put("/mark-multiple-read", messageController.markMultipleAsRead);

// Get all messages for admin
router.get("/", messageController.getAdminMessages);

// Mark message as read
router.put("/:messageId/read", messageController.markAsRead);

// Archive message
router.put("/:messageId/archive", messageController.archiveMessage);

// Delete message
router.delete("/:messageId", messageController.deleteMessage);

// Approve existing employee messages (admin only)
router.post(
  "/approve-employee-messages",
  messageController.approveEmployeeMessages
);

module.exports = router;
