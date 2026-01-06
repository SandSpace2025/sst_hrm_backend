require("dotenv").config();

const encryptionConfig = {
  // Encryption algorithm settings
  algorithm: process.env.ENCRYPTION_ALGORITHM || "aes-256-gcm",
  keyLength: parseInt(process.env.ENCRYPTION_KEY_LENGTH) || 32,
  ivLength: parseInt(process.env.ENCRYPTION_IV_LENGTH) || 16,
  tagLength: parseInt(process.env.ENCRYPTION_TAG_LENGTH) || 16,
  saltLength: parseInt(process.env.ENCRYPTION_SALT_LENGTH) || 32,
  iterations: parseInt(process.env.ENCRYPTION_ITERATIONS) || 100000,

  // Key management settings
  keyRotationInterval: process.env.KEY_ROTATION_INTERVAL || "30d",
  keyBackupRetention: process.env.KEY_BACKUP_RETENTION || "90d",
  keyStrengthRequirement: process.env.KEY_STRENGTH_REQUIREMENT || "strong",

  // Security settings
  maxKeyAge: 365 * 24 * 60 * 60 * 1000, // 1 year in milliseconds
  minKeyStrength: "strong",
  requireKeyRotation: true,

  // File encryption settings
  maxFileSize: parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024, // 10MB
  allowedFileTypes: (
    process.env.ALLOWED_FILE_TYPES ||
    "image/jpeg,image/png,image/gif,application/pdf,text/plain"
  ).split(","),

  // Performance settings
  encryptionTimeout: 30000, // 30 seconds
  decryptionTimeout: 30000, // 30 seconds
  keyDerivationTimeout: 5000, // 5 seconds

  // Logging settings
  logEncryptionOperations: process.env.LOG_ENCRYPTION_OPERATIONS === "true",
  logKeyOperations: process.env.LOG_KEY_OPERATIONS === "true",
  logSecurityEvents: process.env.LOG_SECURITY_EVENTS === "true",

  // Development settings
  isDevelopment: process.env.NODE_ENV === "development",
  allowWeakKeys: process.env.ALLOW_WEAK_KEYS === "true",
  skipKeyValidation: process.env.SKIP_KEY_VALIDATION === "true",
};

// Validation
if (encryptionConfig.keyLength < 16) {
  throw new Error("Key length must be at least 16 bytes");
}

if (encryptionConfig.iterations < 10000) {
  throw new Error("Iterations must be at least 10000");
}

if (encryptionConfig.saltLength < 16) {
  throw new Error("Salt length must be at least 16 bytes");
}

module.exports = encryptionConfig;
