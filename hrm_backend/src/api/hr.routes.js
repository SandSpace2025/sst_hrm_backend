const express = require("express");
const router = express.Router();
const hrController = require("../controllers/hr.controller");
const authMiddleware = require("../middleware/auth.middleware");

// All HR routes require authentication and HR role
router.use(authMiddleware.verifyToken);
router.use(authMiddleware.isHrOrAdmin);

// Dashboard routes
router.get("/dashboard-summary", hrController.getHRDashboardSummary);
router.get("/profile", hrController.getHRProfile);
router.put("/profile", hrController.updateHRProfile);
router.post("/profile/image", hrController.uploadProfileImage);

// Employee management routes
router.get("/employees", hrController.getEmployees);
router.post("/employees", hrController.createEmployee);
router.put("/employees/:employeeId", hrController.updateEmployee);
router.delete("/employees/:employeeId", hrController.deleteEmployee);

// Employee leave management routes
router.get(
  "/employees/:employeeId/leave-data",
  hrController.getEmployeeLeaveData
);
router.put(
  "/employees/:employeeId/leave-data",
  hrController.updateEmployeeLeaveData
);

// Messaging routes
router.get("/employees-for-messaging", hrController.getEmployeesForMessaging);
router.get("/admins-for-messaging", hrController.getAdminsForMessaging);
router.post("/send-to-employee", hrController.sendMessageToEmployee);
router.post("/send-to-admin", hrController.sendMessageToAdmin);
router.get("/messages", hrController.getHRMessages);
router.get("/conversation/:userId/:userType", hrController.getConversation);
router.put("/messages/:messageId/read", hrController.markAsRead);
router.put("/mark-message-read/:messageId", hrController.markMessageAsRead);
router.put(
  "/mark-conversation-seen/:userId/:userType",
  hrController.markConversationAsSeen
);

// Announcement routes
router.post("/announcements", hrController.createAnnouncement);
router.get("/announcements", hrController.getAnnouncements);

module.exports = router;
