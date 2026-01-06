const express = require("express");
const router = express.Router();
const payslipRequestController = require("../controllers/payslipRequest.controller");
const {
  verifyToken,
  isEmployee,
  isHrOrAdmin,
} = require("../middleware/auth.middleware");

// Debug middleware - log all requests to this router
router.use((req, res, next) => {
  console.log(`🔍 [PAYSLIP-ROUTES] ${req.method} ${req.path} - Params:`, req.params);
  next();
});

// Employee routes
router.post(
  "/submit",
  verifyToken,
  isEmployee,
  payslipRequestController.submitPayslipRequest
);

router.get(
  "/employee",
  verifyToken,
  isEmployee,
  payslipRequestController.getEmployeePayslipRequests
);

// HR routes - Specific routes must come before parameterized routes
router.get(
  "/hr",
  verifyToken,
  isHrOrAdmin,
  payslipRequestController.getHRPayslipRequests
);

router.get(
  "/hr/stats",
  verifyToken,
  isHrOrAdmin,
  payslipRequestController.getPayslipRequestStats
);

router.get(
  "/hr/history",
  verifyToken,
  isHrOrAdmin,
  payslipRequestController.getPayslipApprovalHistory
);

// Parameterized routes - Must come after specific routes

// Update payslip request status (HR)
router.put(
  "/:requestId/status",
  verifyToken,
  isHrOrAdmin,
  payslipRequestController.updatePayslipRequestStatus
);

// Preview payslip (HR)
router.post(
  "/:requestId/preview",
  verifyToken,
  isHrOrAdmin,
  payslipRequestController.previewPayslip
);

// Process payslip with base pay (HR)
router.post(
  "/:requestId/process",
  verifyToken,
  isHrOrAdmin,
  payslipRequestController.processPayslipWithBasePay
);

// Download payslip PDF route - GET /api/payslip-requests/:requestId/download
router.get(
  "/:requestId/download",
  verifyToken,
  payslipRequestController.downloadPayslipPDF
);

module.exports = router;
