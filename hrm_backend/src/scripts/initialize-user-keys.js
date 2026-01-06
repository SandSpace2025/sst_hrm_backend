const mongoose = require("mongoose");
const UserKey = require("../models/user-key.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const Employee = require("../models/employee.model");
const encryptionService = require("../services/encryption.service");
require("dotenv").config();

// Connect to MongoDB
const connectDB = async () => {
  try {
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/hrm",
      {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      }
    );
    console.log("✅ Connected to MongoDB");
  } catch (error) {
    console.error("❌ MongoDB connection error:", error);
    process.exit(1);
  }
};

// Initialize encryption keys for a user
const initializeUserKeys = async (userId, userType) => {
  try {
    // Check if keys already exist
    const existingKeys = await UserKey.findActiveKey(userId, userType);
    if (existingKeys) {
      console.log(
        `✅ User ${userId} (${userType}) already has encryption keys`
      );
      return existingKeys;
    }

    // Generate a default password for key initialization
    const defaultPassword = `default_key_${userId}_${Date.now()}`;

    // Generate master key
    const masterKey = encryptionService.generateKey();
    const salt = encryptionService.generateSalt();

    // Encrypt master key with default password
    const encryptedMasterKey = encryptionService.encryptPrivateKey(
      masterKey.toString("hex"),
      defaultPassword,
      salt
    );

    // Generate RSA key pair
    const { publicKey, privateKey } = encryptionService.generateKeyPair();

    // Encrypt private key with master key
    const privateKeySalt = encryptionService.generateSalt();
    const encryptedPrivateKey = encryptionService.encryptPrivateKey(
      privateKey,
      masterKey.toString("hex"),
      privateKeySalt
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
    console.log(
      `✅ Successfully initialized keys for user ${userId} (${userType})`
    );
    return userKey;
  } catch (error) {
    console.error(`❌ Failed to initialize keys for user ${userId}:`, error);
    throw error;
  }
};

// Get all users from all collections
const getAllUsers = async () => {
  const users = [];

  // Get all admins
  const admins = await Admin.find({}).select("user");
  for (const admin of admins) {
    users.push({ userId: admin.user, userType: "Admin" });
  }

  // Get all HR users
  const hrUsers = await HR.find({}).select("user");
  for (const hr of hrUsers) {
    users.push({ userId: hr.user, userType: "HR" });
  }

  // Get all employees
  const employees = await Employee.find({}).select("user");
  for (const employee of employees) {
    users.push({ userId: employee.user, userType: "Employee" });
  }

  return users;
};

// Main function to initialize keys for all users
const initializeAllUserKeys = async () => {
  try {
    console.log("🚀 Starting encryption key initialization for all users...");

    const users = await getAllUsers();
    console.log(`📊 Found ${users.length} users to process`);

    let successCount = 0;
    let errorCount = 0;

    for (const user of users) {
      try {
        await initializeUserKeys(user.userId, user.userType);
        successCount++;
      } catch (error) {
        console.error(
          `❌ Error processing user ${user.userId}:`,
          error.message
        );
        errorCount++;
      }
    }

    console.log("\n📈 Initialization Summary:");
    console.log(`✅ Successfully processed: ${successCount} users`);
    console.log(`❌ Errors: ${errorCount} users`);
    console.log(`📊 Total users: ${users.length}`);
  } catch (error) {
    console.error("❌ Error in initialization process:", error);
  }
};

// Run the script
const run = async () => {
  try {
    await connectDB();
    await initializeAllUserKeys();
    console.log("\n🎉 Key initialization completed!");
  } catch (error) {
    console.error("❌ Script failed:", error);
  } finally {
    await mongoose.disconnect();
    console.log("👋 Disconnected from MongoDB");
    process.exit(0);
  }
};

// Run if called directly
if (require.main === module) {
  run();
}

module.exports = {
  initializeUserKeys,
  initializeAllUserKeys,
};
