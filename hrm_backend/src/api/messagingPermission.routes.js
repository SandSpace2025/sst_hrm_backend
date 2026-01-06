const express = require("express");
const router = express.Router();
const messagingPermissionController = require("../controllers/messagingPermission.controller");
const {
  verifyToken,
  isEmployee,
  isAdmin,
} = require("../middleware/auth.middleware");

// Employee routes
router.get(
  "/check",
  verifyToken,
  isEmployee,
  messagingPermissionController.checkMessagingPermission
);

router.post(
  "/request",
  verifyToken,
  isEmployee,
  messagingPermissionController.requestMessagingPermission
);

// Admin routes
router.post(
  "/grant/:employeeId",
  verifyToken,
  isAdmin,
  messagingPermissionController.grantMessagingPermission
);

router.post(
  "/revoke/:employeeId",
  verifyToken,
  isAdmin,
  messagingPermissionController.revokeMessagingPermission
);

router.get(
  "/requests",
  verifyToken,
  isAdmin,
  messagingPermissionController.getMessagingPermissionRequests
);

router.get(
  "/active",
  verifyToken,
  isAdmin,
  messagingPermissionController.getActiveMessagingPermissions
);

module.exports = router;
