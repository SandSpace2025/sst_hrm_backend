const express = require("express");
const router = express.Router();
const employeeController = require("../controllers/employee.controller");
const authMiddleware = require("../middleware/auth.middleware");

// All routes require authentication
router.use(authMiddleware.verifyToken);

// GET /api/payslips
router.get("/", employeeController.getPayslips);

module.exports = router;
