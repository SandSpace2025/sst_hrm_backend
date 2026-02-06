const express = require("express");
const router = express.Router();
const leaveController = require("../controllers/leave.controller");
const authJwt = require("../middleware/auth.middleware");

// All routes require authentication and employee role
router.use(authJwt.verifyToken);
router.use(authJwt.isEmployee);

// Apply for leave
router.post("/apply", leaveController.applyLeave);

// Get my leave requests
router.get("/my-requests", leaveController.getMyLeaveRequests);

// Get leave balance
router.get("/balance", leaveController.getLeaveBalance);

// Cancel leave request (before approval)
router.put("/:leaveRequestId/cancel", leaveController.cancelLeaveRequest);

// Get blackout dates
router.get("/blackout-dates", leaveController.getBlackoutDates);

// Get leave statistics
router.get("/statistics", leaveController.getLeaveStatistics);

module.exports = router;
