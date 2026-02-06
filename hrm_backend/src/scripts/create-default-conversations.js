const mongoose = require("mongoose");
const Conversation = require("../models/conversation.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const Employee = require("../models/employee.model");
const User = require("../models/user.model");
const crypto = require("crypto");

// Connect to MongoDB
const connectDB = async () => {
  try {
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/hrm_db"
    );
    console.log("✅ Connected to MongoDB");
  } catch (error) {
    console.error("❌ MongoDB connection error:", error);
    process.exit(1);
  }
};

// Generate conversation ID
const generateConversationId = () => {
  return `conv_${crypto.randomBytes(16).toString("hex")}`;
};

// Generate encryption key
const generateEncryptionKey = () => {
  return crypto.randomBytes(32).toString("hex");
};

// Create default conversations for all users
const createDefaultConversations = async () => {
  try {
    console.log("🚀 Creating default conversations...");

    // Get all users
    const admins = await Admin.find().populate("user");
    const hrs = await HR.find().populate("user");
    const employees = await Employee.find().populate("user");

    console.log(`📊 Found users:`);
    console.log(`   Admins: ${admins.length}`);
    console.log(`   HR: ${hrs.length}`);
    console.log(`   Employees: ${employees.length}`);

    const conversations = [];

    // Create HR-Admin conversations
    for (const hr of hrs) {
      for (const admin of admins) {
        const conversationId = generateConversationId();
        const encryptionKey = generateEncryptionKey();

        const conversation = new Conversation({
          conversationId,
          title: `HR-Admin Communication: ${hr.name} & ${admin.fullName}`,
          description: "Default HR-Admin communication channel",
          conversationType: "direct",
          participants: [
            {
              userId: hr.user._id.toString(),
              userType: "HR",
              name: hr.name,
              email: hr.email,
              joinedAt: new Date(),
            },
            {
              userId: admin.user._id.toString(),
              userType: "Admin",
              name: admin.fullName,
              email: admin.email,
              joinedAt: new Date(),
            },
          ],
          encryptionKey,
          keyVersion: 1,
          createdBy: hr.user._id.toString(),
          createdByType: "HR",
          isActive: true,
        });

        await conversation.save();
        conversations.push(conversation);
        console.log(`✅ Created HR-Admin conversation: ${conversationId}`);
      }
    }

    // Create HR-Employee conversations
    for (const hr of hrs) {
      for (const employee of employees) {
        const conversationId = generateConversationId();
        const encryptionKey = generateEncryptionKey();

        const conversation = new Conversation({
          conversationId,
          title: `HR-Employee Communication: ${hr.name} & ${employee.name}`,
          description: "Default HR-Employee communication channel",
          conversationType: "direct",
          participants: [
            {
              userId: hr.user._id.toString(),
              userType: "HR",
              name: hr.name,
              email: hr.email,
              joinedAt: new Date(),
            },
            {
              userId: employee.user._id.toString(),
              userType: "Employee",
              name: employee.name,
              email: employee.email,
              joinedAt: new Date(),
            },
          ],
          encryptionKey,
          keyVersion: 1,
          createdBy: hr.user._id.toString(),
          createdByType: "HR",
          isActive: true,
        });

        await conversation.save();
        conversations.push(conversation);
        console.log(`✅ Created HR-Employee conversation: ${conversationId}`);
      }
    }

    // Create Employee-Employee conversations (optional)
    for (let i = 0; i < employees.length; i++) {
      for (let j = i + 1; j < employees.length; j++) {
        const employee1 = employees[i];
        const employee2 = employees[j];

        const conversationId = generateConversationId();
        const encryptionKey = generateEncryptionKey();

        const conversation = new Conversation({
          conversationId,
          title: `Employee Communication: ${employee1.name} & ${employee2.name}`,
          description: "Default Employee-Employee communication channel",
          conversationType: "direct",
          participants: [
            {
              userId: employee1.user._id.toString(),
              userType: "Employee",
              name: employee1.name,
              email: employee1.email,
              joinedAt: new Date(),
            },
            {
              userId: employee2.user._id.toString(),
              userType: "Employee",
              name: employee2.name,
              email: employee2.email,
              joinedAt: new Date(),
            },
          ],
          encryptionKey,
          keyVersion: 1,
          createdBy: employee1.user._id.toString(),
          createdByType: "Employee",
          isActive: true,
        });

        await conversation.save();
        conversations.push(conversation);
        console.log(
          `✅ Created Employee-Employee conversation: ${conversationId}`
        );
      }
    }

    console.log(`🎉 Created ${conversations.length} default conversations!`);
    return conversations;
  } catch (error) {
    console.error("❌ Error creating default conversations:", error);
    throw error;
  }
};

// Main execution
const main = async () => {
  try {
    console.log("🚀 Starting default conversation creation...");

    await connectDB();

    // Check if conversations already exist
    const existingConversations = await Conversation.countDocuments();
    if (existingConversations > 0) {
      console.log(`⚠️  Found ${existingConversations} existing conversations`);
      console.log("   Skipping creation to avoid duplicates");
      return;
    }

    await createDefaultConversations();

    console.log("✅ Default conversation creation completed!");
    console.log("\n📝 Next steps:");
    console.log("   1. Restart your backend server");
    console.log("   2. Test messaging in the Flutter app");
    console.log("   3. Check if conversations are loaded");
  } catch (error) {
    console.error("❌ Script failed:", error);
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

module.exports = { createDefaultConversations };
