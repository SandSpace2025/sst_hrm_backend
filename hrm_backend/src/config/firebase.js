const admin = require("firebase-admin");
const path = require("path");
const fs = require("fs");

const serviceAccountPath = path.join(__dirname, "../../service-account.json");

let initialized = false;

try {
    if (fs.existsSync(serviceAccountPath)) {
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });
        initialized = true;
        console.log("✅ Firebase Admin initialized successfully");
    } else {
        console.warn(
            "⚠️ Firebase service-account.json not found in root. Push notifications will not work."
        );
    }
} catch (error) {
    console.error("❌ Firebase initialization failed:", error);
}

module.exports = { admin, initialized };
