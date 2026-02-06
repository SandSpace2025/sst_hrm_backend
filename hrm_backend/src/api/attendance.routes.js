const express = require("express");
const router = express.Router();
const attendanceController = require("../controllers/attendance.controller");
const auth = require("../middleware/auth.middleware"); // Assuming auth middleware exists (verified in directory listing)

// All routes require authentication
router.post("/punch-in", auth.verifyToken, attendanceController.punchIn);
router.post("/punch-out", auth.verifyToken, attendanceController.punchOut);
router.get("/status", auth.verifyToken, attendanceController.getTodayStatus);
router.get("/history", auth.verifyToken, attendanceController.getHistory);

// HR/Admin: Manual update
router.put(
  "/:id",
  auth.verifyToken,
  auth.isHrOrAdmin,
  attendanceController.updateAttendance
);

module.exports = router;
