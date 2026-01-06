const express = require("express");
const router = express.Router();
const employeeController = require("../controllers/employee.controller");
const authMiddleware = require("../middleware/auth.middleware");

// All employee routes require authentication and employee role
router.use(authMiddleware.verifyToken);
router.use(authMiddleware.isEmployee);

// Dashboard routes
router.get(
  "/dashboard-summary",
  employeeController.getEmployeeDashboardSummary
);
router.get("/profile", employeeController.getEmployeeProfile);
router.put("/profile", employeeController.updateEmployeeProfile);

// Profile image upload - spread the array from controller
router.post("/upload-profile-image", ...employeeController.uploadProfileImage);

// Leave management routes
router.post("/leave", employeeController.applyForLeave);
router.get("/leave", employeeController.getLeaveRequests);

// Payslip routes
router.get("/payslips/preview", employeeController.getSalaryBreakdownPreview);
router.get("/payslips", employeeController.getPayslips);

// Messaging routes
router.get("/hr-contacts", employeeController.getHRContacts);
router.get("/admin-contacts", employeeController.getAdminContacts);
router.get(
  "/employee-contacts",
  employeeController.getEmployeeContactsForMessaging
);
router.post("/messages/hr", employeeController.sendMessageToHR);
router.post("/messages/admin", employeeController.sendMessageToAdmin);
router.post("/messages/employee", employeeController.sendMessageToEmployee);
router.get("/messages", employeeController.getEmployeeMessages);
router.get(
  "/conversation/:userId/:userType",
  employeeController.getConversation
);
router.put("/messages/:messageId/read", employeeController.markMessageAsRead);
router.put(
  "/conversation/:userId/:userType/seen",
  employeeController.markConversationAsSeen
);

// Announcements
router.get("/announcements", employeeController.getAnnouncements);

module.exports = router;
