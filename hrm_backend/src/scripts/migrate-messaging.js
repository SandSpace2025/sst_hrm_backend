const mongoose = require('mongoose');
const Message = require('../models/message.model');
const Conversation = require('../models/conversation.model');
const UserKey = require('../models/user-key.model');
const encryptionService = require('../services/encryption.service');
require('dotenv').config();

/**
 * Migration script to convert old messaging system to new conversation-based system
 * This script should be run once to migrate existing messages
 */

const migrateMessagingSystem = async () => {
  try {
    console.log('🚀 Starting messaging system migration...');

    // Connect to database
    const uri = process.env.MONGO_URI || "mongodb://localhost:27017/hrm_db";
    await mongoose.connect(uri);
    console.log('✓ Connected to MongoDB');

    // Get all existing messages
    const oldMessages = await Message.find({
      conversationId: { $exists: false } // Old messages don't have conversationId
    });

    console.log(`📊 Found ${oldMessages.length} messages to migrate`);

    if (oldMessages.length === 0) {
      console.log('✅ No messages to migrate');
      return;
    }

    // Group messages by sender-receiver pairs
    const messageGroups = {};
    
    for (const message of oldMessages) {
      const key = `${message.sender}-${message.senderModel}-${message.receiver}-${message.receiverModel}`;
      const reverseKey = `${message.receiver}-${message.receiverModel}-${message.sender}-${message.senderModel}`;
      
      // Check if we already have a group for this pair (either direction)
      const existingKey = messageGroups[key] ? key : (messageGroups[reverseKey] ? reverseKey : key);
      
      if (!messageGroups[existingKey]) {
        messageGroups[existingKey] = [];
      }
      messageGroups[existingKey].push(message);
    }

    console.log(`📁 Created ${Object.keys(messageGroups).length} conversation groups`);

    // Create conversations and migrate messages
    let migratedCount = 0;
    let errorCount = 0;

    for (const [groupKey, messages] of Object.entries(messageGroups)) {
      try {
        // Sort messages by creation date
        messages.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        
        const firstMessage = messages[0];
        const participants = [
          {
            userId: firstMessage.sender,
            userType: firstMessage.senderModel
          },
          {
            userId: firstMessage.receiver,
            userType: firstMessage.receiverModel
          }
        ];

        // Create conversation
        const conversation = new Conversation({
          conversationId: require('crypto').randomUUID(),
          participants: participants.map(p => ({
            userId: p.userId,
            userType: p.userType,
            joinedAt: new Date(),
            isActive: true
          })),
          title: `Migrated Conversation - ${participants.length} participants`,
          description: 'Migrated from old messaging system',
          conversationType: 'direct',
          encryptionKeys: {
            publicKey: 'migration-placeholder',
            privateKeyEncrypted: '{}',
            keyVersion: 1,
            algorithm: 'aes-256-gcm'
          },
          settings: {
            allowNewParticipants: false,
            requireApproval: false,
            isArchived: false,
            isPinned: false
          },
          messageCount: messages.length,
          lastMessageAt: messages[messages.length - 1].createdAt,
          lastMessageId: messages[messages.length - 1]._id
        });

        await conversation.save();
        console.log(`✅ Created conversation ${conversation.conversationId}`);

        // Update messages with conversation ID and new structure
        for (const message of messages) {
          // Create new message structure
          const newMessage = {
            conversationId: conversation.conversationId,
            sender: {
              userId: message.sender,
              userType: message.senderModel,
              name: message.senderName || 'Unknown',
              email: message.senderEmail || 'unknown@example.com'
            },
            content: {
              encrypted: message.content || message.subject || 'Migrated message',
              iv: 'migration-iv',
              tag: 'migration-tag',
              algorithm: 'aes-256-gcm'
            },
            messageType: 'text',
            encryption: {
              keyVersion: 1,
              encryptedWith: conversation.conversationId
            },
            priority: message.priority || 'normal',
            status: message.status || 'sent',
            readBy: message.isRead ? [{
              userId: message.receiver,
              userType: message.receiverModel,
              readAt: message.readAt || new Date()
            }] : [],
            replyTo: message.parentMessage,
            isReply: message.isReply || false,
            attachments: message.attachments || [],
            isEdited: false,
            isDeleted: false,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt
          };

          // Update the message document
          await Message.findByIdAndUpdate(message._id, newMessage);
          migratedCount++;
        }

        console.log(`✅ Migrated ${messages.length} messages for conversation ${conversation.conversationId}`);

      } catch (error) {
        console.error(`❌ Error migrating group ${groupKey}:`, error.message);
        errorCount++;
      }
    }

    console.log('\n📊 Migration Summary:');
    console.log(`✅ Successfully migrated: ${migratedCount} messages`);
    console.log(`❌ Errors: ${errorCount} groups`);
    console.log(`📁 Total conversations created: ${Object.keys(messageGroups).length}`);

    // Clean up old message fields (optional)
    console.log('\n🧹 Cleaning up old message fields...');
    await Message.updateMany(
      { conversationId: { $exists: true } },
      { 
        $unset: { 
          sender: 1, 
          senderModel: 1, 
          receiver: 1, 
          receiverModel: 1,
          subject: 1,
          messageType: 1,
          isRead: 1,
          readAt: 1,
          parentMessage: 1
        }
      }
    );

    console.log('✅ Migration completed successfully!');
    console.log('\n📝 Next steps:');
    console.log('1. Initialize encryption keys for all users');
    console.log('2. Test the new messaging system');
    console.log('3. Update frontend to use new API endpoints');
    console.log('4. Remove old message routes after testing');

  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB');
  }
};

// Run migration if called directly
if (require.main === module) {
  migrateMessagingSystem()
    .then(() => {
      console.log('🎉 Migration script completed');
      process.exit(0);
    })
    .catch((error) => {
      console.error('💥 Migration script failed:', error);
      process.exit(1);
    });
}

module.exports = migrateMessagingSystem;
