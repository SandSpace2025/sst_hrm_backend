const express = require("express");
const router = express.Router();
const leaveRequestController = require("../controllers/leaveRequest.controller");
const authMiddleware = require("../middleware/auth.middleware");

// All leave request routes require authentication
router.use(authMiddleware.verifyToken);

// Get all leave requests with filtering and pagination
router.get("/", leaveRequestController.getLeaveRequests);

// Get leave request statistics
router.get("/stats", leaveRequestController.getLeaveRequestStats);

// Get leave calendar
router.get("/calendar", leaveRequestController.getLeaveCalendar);

// Get leave requests by employee
router.get(
  "/employee/:employeeId",
  leaveRequestController.getLeaveRequestsByEmployee
);

// Get single leave request by ID
router.get("/:id", leaveRequestController.getLeaveRequestById);

// Update leave request status (approve, reject, hold)
router.put("/:id/status", leaveRequestController.updateLeaveRequestStatus);

// Bulk update leave requests
router.put("/bulk-update", leaveRequestController.bulkUpdateLeaveRequests);

// Delete leave request
router.delete("/:id", leaveRequestController.deleteLeaveRequest);

module.exports = router;
