const express = require("express");
const router = express.Router();
const keyController = require("../controllers/key.controller");
const { verifyToken } = require("../middleware/auth.middleware");

// Apply authentication middleware to all routes
router.use(verifyToken);

// Initialize user encryption keys
router.post("/initialize", keyController.initializeUserKeys);

// Get user public key
router.get("/public", keyController.getUserPublicKey);

// Get key status
router.get("/status", keyController.getKeyStatus);

// Verify key integrity
router.post("/verify", keyController.verifyKeyIntegrity);

// Rotate user keys
router.post("/rotate", keyController.rotateUserKeys);

// Mark keys as compromised
router.patch("/compromised", keyController.markKeysCompromised);

module.exports = router;
