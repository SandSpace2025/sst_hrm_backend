const express = require("express");
const router = express.Router();
const leaveManagementController = require("../controllers/leaveManagement.controller");
const authJwt = require("../middleware/auth.middleware");

// All routes require authentication
router.use(authJwt.verifyToken);

// Get all leave requests (HR/Admin)
router.get(
  "/requests",
  authJwt.isHrOrAdmin,
  leaveManagementController.getAllLeaveRequests
);

// HR approval routes
router.put(
  "/requests/:leaveRequestId/approve-hr",
  authJwt.isHrOrAdmin,
  leaveManagementController.approveLeaveRequestHR
);

router.put(
  "/requests/:leaveRequestId/reject-hr",
  authJwt.isHrOrAdmin,
  leaveManagementController.rejectLeaveRequestHR
);

// Admin approval routes
router.put(
  "/requests/:leaveRequestId/approve-admin",
  authJwt.isHrOrAdmin,
  leaveManagementController.approveLeaveRequestAdmin
);

router.put(
  "/requests/:leaveRequestId/reject-admin",
  authJwt.isHrOrAdmin,
  leaveManagementController.rejectLeaveRequestAdmin
);

// Cancel ongoing leave (HR/Admin only)
router.put(
  "/requests/:leaveRequestId/cancel",
  authJwt.isHrOrAdmin,
  leaveManagementController.cancelOngoingLeave
);

// Blackout dates management
router.post(
  "/blackout-dates",
  authJwt.isHrOrAdmin,
  leaveManagementController.createBlackoutDate
);

router.put(
  "/blackout-dates/:blackoutDateId",
  authJwt.isHrOrAdmin,
  leaveManagementController.updateBlackoutDate
);

router.delete(
  "/blackout-dates/:blackoutDateId",
  authJwt.isHrOrAdmin,
  leaveManagementController.deleteBlackoutDate
);

// Statistics
router.get(
  "/statistics",
  authJwt.isHrOrAdmin,
  leaveManagementController.getLeaveStatistics
);

// Employee leave summary
router.get(
  "/employee/:employeeId/summary",
  authJwt.isHrOrAdmin,
  leaveManagementController.getEmployeeLeaveSummary
);

module.exports = router;
