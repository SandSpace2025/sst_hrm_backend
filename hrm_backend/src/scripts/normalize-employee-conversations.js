const mongoose = require("mongoose");
const Message = require("../models/message.model");
require("dotenv").config();

async function normalizeEmployeeConversations() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || "mongodb://localhost:27017/hrm", {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log("✅ Connected to MongoDB");

    // First, let's see all messages
    const allMessages = await Message.find({}).limit(5);
    console.log(`📊 Total messages in DB: ${await Message.countDocuments({})}`);
    if (allMessages.length > 0) {
      console.log(`📋 Sample message structure:`, JSON.stringify(allMessages[0], null, 2));
    }

    // Find all employee-to-employee messages
    const employeeMessages = await Message.find({
      conversationId: { $regex: /Employee:.*Employee:/ },
    });

    console.log(`📊 Found ${employeeMessages.length} employee-to-employee messages`);
    
    // Show a sample for debugging
    if (employeeMessages.length > 0) {
      console.log(`📋 Sample conversationId: ${employeeMessages[0].conversationId}`);
    }

    let normalizedCount = 0;
    const updates = [];

    for (const message of employeeMessages) {
      const convId = message.conversationId;
      
      // Extract the two employee IDs
      const match = convId.match(/^Employee:(.+)\|Employee:(.+)$/);
      if (!match) {
        console.log(`⚠️ Could not parse conversationId: ${convId}`);
        continue;
      }

      const [, id1, id2] = match;
      
      // Create canonical (sorted) conversationId
      const canonicalConvId = id1 < id2
        ? `Employee:${id1}|Employee:${id2}`
        : `Employee:${id2}|Employee:${id1}`;

      // If it's already canonical, skip
      if (convId === canonicalConvId) {
        continue;
      }

      // Queue update
      updates.push({
        updateOne: {
          filter: { _id: message._id },
          update: { $set: { conversationId: canonicalConvId } },
        },
      });

      normalizedCount++;
    }

    if (updates.length > 0) {
      console.log(`🔄 Normalizing ${updates.length} conversationIds...`);
      const result = await Message.bulkWrite(updates);
      console.log(`✅ Updated ${result.modifiedCount} messages`);
    } else {
      console.log("✅ All conversationIds are already normalized!");
    }

    console.log(`\n📈 Summary:`);
    console.log(`   Total messages checked: ${employeeMessages.length}`);
    console.log(`   Messages normalized: ${normalizedCount}`);

    await mongoose.connection.close();
    console.log("\n✅ Migration complete!");
  } catch (error) {
    console.error("❌ Migration failed:", error);
    process.exit(1);
  }
}

// Run migration
normalizeEmployeeConversations();

