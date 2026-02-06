const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");
const logger = require("../core/logger");

const serviceAccountPath = path.join(__dirname, "../../service-account.json");

let initialized = false;

try {
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    initialized = true;
    logger.info("Firebase Admin initialized successfully");
  } else {
    logger.warn(
      "Firebase service-account.json not found. Push notifications will not work.",
    );
  }
} catch (error) {
  logger.error("Firebase initialization failed", {
    error: error.message,
    stack: error.stack,
  });
}

module.exports = { admin, initialized };
