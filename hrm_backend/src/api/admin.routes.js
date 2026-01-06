const express = require("express");
const router = express.Router();
const controller = require("../controllers/admin.controller");
const {
  verifyToken,
  isAdmin,
  isHrOrAdmin,
} = require("../middleware/auth.middleware");

router.get(
  "/dashboard-summary",
  [verifyToken, isAdmin],
  controller.getDashboardSummary
);
router.get("/users/:role", [verifyToken, isAdmin], controller.getUsersByRole);
router.post("/create-user", [verifyToken, isHrOrAdmin], controller.createUser);
router.put("/users/:id", [verifyToken, isHrOrAdmin], controller.updateUser);
router.delete("/users/:id", [verifyToken, isHrOrAdmin], controller.deleteUser);
router.put(
  "/conversation/:userId/:userType/seen",
  [verifyToken, isAdmin],
  controller.markConversationAsSeen
);

module.exports = router;
