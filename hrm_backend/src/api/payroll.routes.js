const express = require("express");
const router = express.Router();
const {
  createPayroll,
  getPayrollsForEmployee,
  updatePayroll,
  deletePayroll,
} = require("../controllers/payroll.controller");

const { verifyToken, isHrOrAdmin } = require("../middleware/auth.middleware");

// @route   POST /api/payroll
// @desc    Create a new payroll record for an employee
// @access  Admin
router.post("/", [verifyToken, isHrOrAdmin], createPayroll);

// @route   GET /api/payroll/employee/:employeeId
// @desc    Get all payroll records for a specific employee
// @access  Admin
router.get(
  "/employee/:employeeId",
  [verifyToken, isHrOrAdmin],
  getPayrollsForEmployee
);

// @route   PUT /api/payroll/:payrollId
// @desc    Update a specific payroll record (totalPay or bonus)
// @access  Admin
router.put("/:payrollId", [verifyToken, isHrOrAdmin], updatePayroll);

// @route   DELETE /api/payroll/:payrollId
// @desc    Delete a specific payroll record
// @access  Admin
router.delete("/:payrollId", [verifyToken, isHrOrAdmin], deletePayroll);

module.exports = router;
