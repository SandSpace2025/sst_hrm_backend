/**
 * Migration Script: Create HR-Admin Conversations
 *
 * This script helps migrate from the old messaging system to the new
 * conversation-based encrypted messaging system.
 *
 * Run this script to create conversations between HR and Admin users.
 */

const mongoose = require("mongoose");
const Conversation = require("../models/conversation.model");
const HR = require("../models/hr.model");
const Admin = require("../models/admin.model");
const crypto = require("crypto");

// Database connection
const connectDB = async () => {
  try {
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/hrm"
    );
    console.log("✅ Connected to MongoDB");
  } catch (error) {
    console.error("❌ MongoDB connection error:", error);
    process.exit(1);
  }
};

// Generate conversation ID
const generateConversationId = () => {
  return crypto.randomBytes(16).toString("hex");
};

// Generate encryption keys for conversation
const generateEncryptionKeys = () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", {
    modulusLength: 2048,
    publicKeyEncoding: { type: "spki", format: "pem" },
    privateKeyEncoding: { type: "pkcs8", format: "pem" },
  });

  return { publicKey, privateKey };
};

// Create HR-Admin conversations
const createHRAdminConversations = async () => {
  try {
    console.log("🔄 Starting HR-Admin conversation creation...");

    // Get all HR users
    const hrUsers = await HR.find().populate("user", "name email");
    console.log(`📋 Found ${hrUsers.length} HR users`);

    // Get all Admin users
    const adminUsers = await Admin.find().populate("user", "fullName email");
    console.log(`📋 Found ${adminUsers.length} Admin users`);

    if (hrUsers.length === 0 || adminUsers.length === 0) {
      console.log(
        "⚠️  No HR or Admin users found. Skipping conversation creation."
      );
      return;
    }

    const conversations = [];

    // Create conversations between each HR and each Admin
    for (const hr of hrUsers) {
      for (const admin of adminUsers) {
        // Check if conversation already exists
        const existingConversation = await Conversation.findOne({
          "participants.userId": { $all: [hr._id, admin._id] },
          "participants.userType": { $all: ["HR", "Admin"] },
        });

        if (existingConversation) {
          console.log(
            `⏭️  Conversation already exists between HR ${hr.user.name} and Admin ${admin.user.fullName}`
          );
          continue;
        }

        // Generate encryption keys
        const { publicKey, privateKey } = generateEncryptionKeys();

        // Create conversation
        const conversation = new Conversation({
          conversationId: generateConversationId(),
          participants: [
            {
              userId: hr._id,
              userType: "HR",
              userRole: hr.role || "HR Manager",
              joinedAt: new Date(),
              isActive: true,
            },
            {
              userId: admin._id,
              userType: "Admin",
              userRole: admin.role || "Administrator",
              joinedAt: new Date(),
              isActive: true,
            },
          ],
          title: `HR-Admin Communication: ${hr.user.name} ↔ ${admin.user.fullName}`,
          description: `Direct communication between HR ${hr.user.name} and Admin ${admin.user.fullName}`,
          conversationType: "direct",
          encryptionKeys: {
            publicKey,
            privateKeyEncrypted: privateKey, // In production, this should be encrypted
            keyVersion: 1,
          },
          settings: {
            allowNewParticipants: false,
            requireApproval: false,
            isArchived: false,
            isPinned: false,
          },
          lastMessageAt: new Date(),
          messageCount: 0,
        });

        await conversation.save();
        conversations.push(conversation);

        console.log(`✅ Created conversation: ${conversation.title}`);
      }
    }

    console.log(
      `🎉 Successfully created ${conversations.length} HR-Admin conversations`
    );

    // Display summary
    console.log("\n📊 Summary:");
    console.log(`   HR Users: ${hrUsers.length}`);
    console.log(`   Admin Users: ${adminUsers.length}`);
    console.log(`   Conversations Created: ${conversations.length}`);
    console.log(
      `   Total Possible Combinations: ${hrUsers.length * adminUsers.length}`
    );
  } catch (error) {
    console.error("❌ Error creating HR-Admin conversations:", error);
    throw error;
  }
};

// Create HR-Employee conversations (optional)
const createHREmployeeConversations = async () => {
  try {
    console.log("🔄 Creating HR-Employee conversations...");

    // Get all HR users
    const hrUsers = await HR.find().populate("user", "name email");

    // Get all Employee users
    const Employee = require("../models/employee.model");
    const employeeUsers = await Employee.find().populate("user", "name email");

    console.log(
      `📋 Found ${hrUsers.length} HR users and ${employeeUsers.length} Employee users`
    );

    if (hrUsers.length === 0 || employeeUsers.length === 0) {
      console.log(
        "⚠️  No HR or Employee users found. Skipping HR-Employee conversation creation."
      );
      return;
    }

    const conversations = [];

    // Create conversations between each HR and each Employee
    for (const hr of hrUsers) {
      for (const employee of employeeUsers) {
        // Check if conversation already exists
        const existingConversation = await Conversation.findOne({
          "participants.userId": { $all: [hr._id, employee._id] },
          "participants.userType": { $all: ["HR", "Employee"] },
        });

        if (existingConversation) {
          continue;
        }

        // Generate encryption keys
        const { publicKey, privateKey } = generateEncryptionKeys();

        // Create conversation
        const conversation = new Conversation({
          conversationId: generateConversationId(),
          participants: [
            {
              userId: hr._id,
              userType: "HR",
              userRole: hr.role || "HR Manager",
              joinedAt: new Date(),
              isActive: true,
            },
            {
              userId: employee._id,
              userType: "Employee",
              userRole: employee.designation || "Employee",
              joinedAt: new Date(),
              isActive: true,
            },
          ],
          title: `HR-Employee Communication: ${hr.user.name} ↔ ${employee.user.name}`,
          description: `Direct communication between HR ${hr.user.name} and Employee ${employee.user.name}`,
          conversationType: "direct",
          encryptionKeys: {
            publicKey,
            privateKeyEncrypted: privateKey,
            keyVersion: 1,
          },
          settings: {
            allowNewParticipants: false,
            requireApproval: false,
            isArchived: false,
            isPinned: false,
          },
          lastMessageAt: new Date(),
          messageCount: 0,
        });

        await conversation.save();
        conversations.push(conversation);
      }
    }

    console.log(`✅ Created ${conversations.length} HR-Employee conversations`);
  } catch (error) {
    console.error("❌ Error creating HR-Employee conversations:", error);
    throw error;
  }
};

// Main execution
const main = async () => {
  try {
    console.log("🚀 Starting conversation migration script...");

    await connectDB();

    // Create HR-Admin conversations
    await createHRAdminConversations();

    // Create HR-Employee conversations (optional)
    // await createHREmployeeConversations();

    console.log("✅ Migration completed successfully!");
    console.log("\n📝 Next steps:");
    console.log("   1. Update frontend to use new messaging API");
    console.log("   2. Test conversation creation and messaging");
    console.log("   3. Initialize user encryption keys");
    console.log("   4. Deploy the new messaging system");
  } catch (error) {
    console.error("❌ Migration failed:", error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log("👋 Disconnected from MongoDB");
  }
};

// Run the script
if (require.main === module) {
  main();
}

module.exports = {
  createHRAdminConversations,
  createHREmployeeConversations,
};
