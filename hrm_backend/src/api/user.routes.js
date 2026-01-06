const controller = require("../controllers/user.controller");
const { verifyToken } = require("../middleware/auth.middleware");
const express = require("express");

const router = express.Router();

router.use((req, res, next) => {
  res.header(
    "Access-Control-Allow-Headers",
    "x-access-token, Origin, Content-Type, Accept"
  );
  next();
});

// Route to get the current user's profile
router.get("/profile", [verifyToken], controller.getProfile);

// Route to update the current user's profile
router.put("/profile", [verifyToken], controller.updateProfile);

// Route to change the current user's password
router.put("/password", [verifyToken], controller.changePassword);

// Route to update FCM token
router.put("/fcm-token", [verifyToken], controller.updateFcmToken);

// Route to upload profile image
router.post(
  "/profile/image",
  [verifyToken, controller.uploadMiddleware],
  controller.uploadProfileImage
);

module.exports = router;
