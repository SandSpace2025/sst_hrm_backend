const UserKey = require("../models/user-key.model");
const encryptionService = require("../services/encryption.service");
const logger = require("../core/logger");

// Initialize user encryption keys
const initializeUserKeys = async (req, res) => {
  try {
    const { password } = req.body;
    const userId = req.userId;
    const userType = req.userRole;

    if (!password) {
      return res.status(400).json({
        message: "Password is required",
        code: "PASSWORD_REQUIRED",
      });
    }

    // Check if keys already exist
    const existingKeys = await UserKey.findActiveKey(userId, userType);
    if (existingKeys) {
      return res.status(400).json({
        message: "Keys already initialized",
        code: "KEYS_ALREADY_EXIST",
      });
    }

    // Generate master key
    const masterKey = encryptionService.generateKey();
    const salt = encryptionService.generateSalt();

    // Encrypt master key with password
    const encryptedMasterKey = encryptionService.encryptPrivateKey(
      masterKey.toString("hex"),
      password,
      salt,
    );

    // Generate RSA key pair
    const { publicKey, privateKey } = encryptionService.generateKeyPair();

    // Encrypt private key with master key
    const privateKeySalt = encryptionService.generateSalt();
    const encryptedPrivateKey = encryptionService.encryptPrivateKey(
      privateKey,
      masterKey.toString("hex"),
      privateKeySalt,
    );

    // Save user keys
    const userKey = new UserKey({
      userId,
      userType,
      masterKey: encryptedMasterKey,
      publicKey,
      keyDerivation: {
        algorithm: "pbkdf2",
        salt: salt.toString("hex"),
        iterations: 100000,
        keyLength: 32,
      },
      keyStrength: "strong",
    });

    await userKey.save();

    res.status(201).json({
      message: "User keys initialized successfully",
      publicKey,
      code: "KEYS_INITIALIZED",
    });
  } catch (error) {
    logger.error("Error initializing user keys", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "KEY_INIT_ERROR",
    });
  }
};

// Get user public key
const getUserPublicKey = async (req, res) => {
  try {
    const userId = req.userId;
    const userType = req.userRole;

    // Normalize userType to match the enum values in UserKey model
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    const userKey = await UserKey.findActiveKey(userId, normalizedUserType);
    if (!userKey) {
      return res.status(404).json({
        message: "User keys not found",
        code: "KEYS_NOT_FOUND",
      });
    }

    res.json({
      publicKey: userKey.publicKey,
      keyVersion: userKey.keyVersion,
      keyStrength: userKey.keyStrength,
      code: "PUBLIC_KEY_RETRIEVED",
    });
  } catch (error) {
    logger.error("Error getting public key", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "PUBLIC_KEY_ERROR",
    });
  }
};

// Rotate user keys
const rotateUserKeys = async (req, res) => {
  try {
    const { password, newPassword } = req.body;
    const userId = req.userId;
    const userType = req.userRole;

    if (!password || !newPassword) {
      return res.status(400).json({
        message: "Current password and new password are required",
        code: "PASSWORDS_REQUIRED",
      });
    }

    // Normalize userType to match the enum values in UserKey model
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    // Get current keys
    const userKey = await UserKey.findActiveKey(userId, normalizedUserType);
    if (!userKey) {
      return res.status(404).json({
        message: "User keys not found",
        code: "KEYS_NOT_FOUND",
      });
    }

    // Verify current password
    const currentMasterKey = encryptionService.decryptPrivateKey(
      userKey.masterKey,
      password,
    );

    // Generate new master key
    const newMasterKey = encryptionService.generateKey();
    const newSalt = encryptionService.generateSalt();

    // Encrypt new master key with new password
    const newEncryptedMasterKey = encryptionService.encryptPrivateKey(
      newMasterKey.toString("hex"),
      newPassword,
      newSalt,
    );

    // Generate new RSA key pair
    const { publicKey: newPublicKey, privateKey: newPrivateKey } =
      encryptionService.generateKeyPair();

    // Encrypt new private key with new master key
    const newPrivateKeySalt = encryptionService.generateSalt();
    const newEncryptedPrivateKey = encryptionService.encryptPrivateKey(
      newPrivateKey,
      newMasterKey.toString("hex"),
      newPrivateKeySalt,
    );

    // Store old key as backup
    userKey.backupKeys.push({
      encrypted: userKey.masterKey.encrypted,
      createdAt: new Date(),
      isActive: false,
    });

    // Update to new keys
    userKey.publicKey = newPublicKey;
    userKey.masterKey = newEncryptedMasterKey;
    userKey.keyVersion += 1;
    userKey.lastRotated = new Date();
    userKey.keyDerivation = {
      algorithm: "pbkdf2",
      salt: newSalt.toString("hex"),
      iterations: 100000,
      keyLength: 32,
    };

    await userKey.save();

    res.json({
      message: "Keys rotated successfully",
      publicKey: newPublicKey,
      keyVersion: userKey.keyVersion,
      code: "KEYS_ROTATED",
    });
  } catch (error) {
    logger.error("Error rotating keys", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "KEY_ROTATE_ERROR",
    });
  }
};

// Mark keys as compromised
const markKeysCompromised = async (req, res) => {
  try {
    const userId = req.userId;
    const userType = req.userRole;

    // Normalize userType to match the enum values in UserKey model
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    const userKey = await UserKey.findActiveKey(userId, normalizedUserType);
    if (!userKey) {
      return res.status(404).json({
        message: "User keys not found",
        code: "KEYS_NOT_FOUND",
      });
    }

    // Mark as compromised
    await userKey.markCompromised();

    res.json({
      message: "Keys marked as compromised",
      code: "KEYS_COMPROMISED",
    });
  } catch (error) {
    logger.error("Error marking keys as compromised", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "KEY_COMPROMISE_ERROR",
    });
  }
};

// Get key status
const getKeyStatus = async (req, res) => {
  try {
    const userId = req.userId;
    const userType = req.userRole;

    // Normalize userType to match the enum values in UserKey model
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    const userKey = await UserKey.findActiveKey(userId, normalizedUserType);
    if (!userKey) {
      return res.status(404).json({
        message: "User keys not found",
        code: "KEYS_NOT_FOUND",
      });
    }

    res.json({
      keyVersion: userKey.keyVersion,
      keyStrength: userKey.keyStrength,
      isActive: userKey.isActive,
      isCompromised: userKey.isCompromised,
      lastRotated: userKey.lastRotated,
      usageStats: userKey.usageStats,
      code: "KEY_STATUS_RETRIEVED",
    });
  } catch (error) {
    logger.error("Error getting key status", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "KEY_STATUS_ERROR",
    });
  }
};

// Verify key integrity
const verifyKeyIntegrity = async (req, res) => {
  try {
    const { password } = req.body;
    const userId = req.userId;
    const userType = req.userRole;

    if (!password) {
      return res.status(400).json({
        message: "Password is required",
        code: "PASSWORD_REQUIRED",
      });
    }

    // Normalize userType to match the enum values in UserKey model
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    const userKey = await UserKey.findActiveKey(userId, normalizedUserType);
    if (!userKey) {
      return res.status(404).json({
        message: "User keys not found",
        code: "KEYS_NOT_FOUND",
      });
    }

    try {
      // Try to decrypt master key
      const masterKey = encryptionService.decryptPrivateKey(
        userKey.masterKey,
        password,
      );

      // Test encryption/decryption
      const testData = "test-integrity-check";
      const encrypted = await encryptionService.encryptMessage(
        testData,
        Buffer.from(masterKey, "hex"),
      );
      const decrypted = await encryptionService.decryptMessage(
        encrypted,
        Buffer.from(masterKey, "hex"),
      );

      const isIntegrityValid = decrypted === testData;

      res.json({
        isIntegrityValid,
        keyVersion: userKey.keyVersion,
        lastRotated: userKey.lastRotated,
        code: "KEY_INTEGRITY_CHECKED",
      });
    } catch (error) {
      res.json({
        isIntegrityValid: false,
        error: "Key decryption failed",
        code: "KEY_INTEGRITY_FAILED",
      });
    }
  } catch (error) {
    logger.error("Error verifying key integrity", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "KEY_INTEGRITY_ERROR",
    });
  }
};

module.exports = {
  initializeUserKeys,
  getUserPublicKey,
  rotateUserKeys,
  markKeysCompromised,
  getKeyStatus,
  verifyKeyIntegrity,
};
