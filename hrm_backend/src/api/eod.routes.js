const express = require("express");
const router = express.Router();
const eodController = require("../controllers/eod.controller");
const authJwt = require("../middleware/auth.middleware"); 
// Employee EOD routes
router.post(
  "/create",
  [authJwt.verifyToken, authJwt.isEmployee],
  eodController.createEOD
);


router.get(
  "/today",
  [authJwt.verifyToken, authJwt.isEmployee],
  eodController.getTodayEOD
);

router.get(
  "/my-eods",
  [authJwt.verifyToken, authJwt.isEmployee],
  eodController.getMyEODs
);

router.put(
  "/:eodId",
  [authJwt.verifyToken, authJwt.isEmployee],
  eodController.updateEOD
);

router.delete(
  "/:eodId",
  [authJwt.verifyToken, authJwt.isEmployee],
  eodController.deleteEOD
);

router.get(
  "/stats",
  [authJwt.verifyToken, authJwt.isEmployee],
  eodController.getEODStats
);

// Admin/HR routes to view employee EODs
router.get(
  "/employee/:employeeId",
  [authJwt.verifyToken, authJwt.isHrOrAdmin],
  eodController.getEmployeeEODs
);

// Cron job route to check missed EODs (should be protected and called by scheduler)
router.post(
  "/check-missed",
  [authJwt.verifyToken, authJwt.isAdmin],
  eodController.checkMissedEODs
);

module.exports = router;
