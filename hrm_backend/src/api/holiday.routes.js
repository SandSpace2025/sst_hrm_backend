const express = require("express");
const router = express.Router();
const holidayController = require("../controllers/holiday.controller");
const auth = require("../middleware/auth.middleware");

// Routes
// HR/Admin can create and delete holidays
router.post(
  "/",
  auth.verifyToken,
  auth.isHrOrAdmin,
  holidayController.createHoliday
);
router.delete(
  "/:id",
  auth.verifyToken,
  auth.isHrOrAdmin,
  holidayController.deleteHoliday
);

// All authenticated users can view holidays
router.get("/", auth.verifyToken, holidayController.getHolidays);

module.exports = router;
