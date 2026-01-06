const Message = require("../models/message.model");
const Conversation = require("../models/conversation.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const websocketService = require("../services/websocket.service");
const { WEBSOCKET_EVENTS } = require("../constants/websocket.events");

// Helper function to get user information
const getUserInfo = async (userId, userType) => {
  try {
    let user;
    if (userType === "admin") {
      user = await Admin.findOne({ user: userId });
      return {
        name: user?.fullName || "Admin User",
        email: user?.email || "admin@example.com",
      };
    } else if (userType === "hr") {
      user = await HR.findOne({ user: userId });
      return {
        name: user?.name || "HR User",
        email: user?.email || "hr@example.com",
      };
    } else if (userType === "employee") {
      user = await Employee.findOne({ user: userId });
      return {
        name: user?.name || "Employee User",
        email: user?.email || "employee@example.com",
      };
    }
    return {
      name: "Unknown User",
      email: "unknown@example.com",
    };
  } catch (error) {
    console.error("Error getting user info:", error);
    return {
      name: "Unknown User",
      email: "unknown@example.com",
    };
  }
};

// Helper function to validate messaging permissions
const validateMessagingPermissions = (senderType, receiverType) => {

  // Admin can message anyone
  if (senderType === "Admin") {

    return true;
  }

  // HR can message anyone
  if (senderType === "HR") {

    return true;
  }

  // Employee restrictions
  if (senderType === "Employee") {
    // Employee can only message HR and other employees
    // Employee CANNOT message admin
    if (receiverType === "Admin") {

      return false;
    }

    return true;
  }


  return false;
};

// Send message to conversation
const sendMessage = async (req, res) => {
  try {


    const { conversationId, content, messageType = "text", replyTo } = req.body;
    const senderUserId = req.userId;
    const senderUserType = req.userRole;



    // Validate required fields
    if (!conversationId) {

      return res.status(400).json({
        message: "conversationId is required",
        code: "MISSING_CONVERSATION_ID",
      });
    }

    if (!content) {

      return res.status(400).json({
        message: "content is required",
        code: "MISSING_CONTENT",
      });
    }

    // Get user information

    const userInfo = await getUserInfo(senderUserId, senderUserType);
    const senderName = userInfo.name;
    const senderEmail = userInfo.email;


    // Find conversation

    const conversation = await Conversation.findOne({ conversationId });
    if (!conversation) {

      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }


    // Normalize userType for participant check
    let normalizedSenderUserType;
    if (senderUserType.toLowerCase() === "hr") {
      normalizedSenderUserType = "HR";
    } else {
      normalizedSenderUserType =
        senderUserType.charAt(0).toUpperCase() +
        senderUserType.slice(1).toLowerCase();
    }

    // Check if user is participant

    const isParticipant = conversation.isParticipant(
      senderUserId,
      normalizedSenderUserType
    );

    if (!isParticipant) {

      return res.status(403).json({
        message: "Not authorized to send message",
        code: "NOT_PARTICIPANT",
      });
    }

    // Validate messaging permissions for all participants in the conversation
    for (const participant of conversation.participants) {
      if (participant.userId.toString() !== senderUserId.toString()) {
        if (
          !validateMessagingPermissions(
            normalizedSenderUserType,
            participant.userType
          )
        ) {
          return res.status(403).json({
            message: `You are not authorized to send messages to ${participant.userType}`,
            code: "MESSAGING_NOT_ALLOWED",
          });
        }
      }
    }

    // Get other participants (excluding sender)
    const otherParticipants = conversation.participants
      .filter(
        (p) => p.userId.toString() !== senderUserId.toString() && p.isActive
      )
      .map((p) => ({ userId: p.userId, userType: p.userType }));

    // Determine receiver (Required by Message Model)
    // For direct conversations, it's the other participant.
    // For group conversations, we currently pick the first one or null (which might fail validation if required)
    // TODO: Update Message Model to make receiver optional for Group Chats
    let receiverId;
    let receiverModel;

    if (otherParticipants.length > 0) {
      receiverId = otherParticipants[0].userId;
      receiverModel = otherParticipants[0].userType;
    } else {
      // Self-message or alone? Model requires receiver.
      // Use sender as fallback to prevent crash, although logic implies this shouldn't happen in valid chats.
      receiverId = senderUserId;
      receiverModel = normalizedSenderUserType;
    }

    // Create message (no encryption)
    const message = new Message({
      conversationId,
      sender: {
        userId: senderUserId,
        userType: normalizedSenderUserType,
        name: senderName,
        email: senderEmail,
      },
      receiver: receiverId,
      receiverModel: receiverModel,
      content: content, // Store plain text
      messageType,
      replyTo,
      isReply: !!replyTo,
    });

    await message.save();

    // Update conversation
    await Conversation.findByIdAndUpdate(conversation._id, {
      lastMessageAt: new Date(),
      lastMessageId: message._id,
      $inc: { messageCount: 1 },
    });

    // Emit websocket event to other participants (iterate recipients)
    if (otherParticipants.length > 0) {
      const payload = {
        messageId: message._id,
        conversationId,
        sender: message.sender,
        content: content, // Send plain text content
        messageType,
        createdAt: message.createdAt,
        message: "New message received",
      };
      for (const participant of otherParticipants) {
        if (participant?.userId) {
          websocketService.broadcastToUser(
            participant.userId.toString(),
            WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
            payload
          );
          // Push notifications removed (no Firebase). Rely on websocket + local notifications.
        }
      }
    }


    // Send confirmation to sender
    websocketService.broadcastToUser(
      senderUserId.toString(),
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        messageId: message._id,
        conversationId,
        message: "Message sent successfully",
      }
    );

    // Return the full message object
    res.status(201).json({
      message: "Message sent successfully",
      messageId: message._id,
      messageData: message.toObject(), // Include full message
      code: "MESSAGE_SENT",
    });
  } catch (error) {
    console.error("Error sending message:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "MESSAGE_SEND_ERROR",
    });
  }
};

// Get conversation messages
const getConversationMessages = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.userId;
    const userType = req.userRole;
    const { page = 1, limit = 50 } = req.query;



    // Normalize userType for query
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }



    // Verify user is participant
    const conversation = await Conversation.findOne({
      conversationId,
      "participants.userId": userId,
      "participants.userType": new RegExp(`^${normalizedUserType}$`, "i"),
      "participants.isActive": true,
    });


    if (conversation) {

    }

    if (!conversation) {

      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }

    const skip = (page - 1) * limit;



    // Get messages
    const messages = await Message.find({
      conversationId,
      isArchived: false,
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));


    if (messages.length > 0) {

    }

    // Return messages as-is (no decryption needed)
    const messageObjects = messages.map((message) => message.toObject());

    // Update last seen
    await conversation.updateLastSeen(userId, normalizedUserType);



    res.json({
      messages: messageObjects,
      conversation,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(conversation.messageCount / limit),
        totalItems: conversation.messageCount,
        itemsPerPage: parseInt(limit),
      },
      code: "MESSAGES_RETRIEVED",
    });
  } catch (error) {
    console.error("Error getting messages:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "MESSAGES_ERROR",
    });
  }
};

// Mark message as read
const markMessageAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.userId;
    const userType = req.userRole;

    // Find message
    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({
        message: "Message not found",
        code: "MESSAGE_NOT_FOUND",
      });
    }

    // Check if user is participant in conversation
    const conversation = await Conversation.findOne({
      conversationId: message.conversationId,
      "participants.userId": userId,
      "participants.userType": new RegExp(`^${userType}$`, "i"),
      "participants.isActive": true,
    });

    if (!conversation) {
      return res.status(403).json({
        message: "Not authorized to read this message",
        code: "NOT_PARTICIPANT",
      });
    }

    // Mark as read
    await message.markAsRead(userId, userType);

    // Emit websocket event
    websocketService.broadcastToUser(
      message.sender.userId,
      message.sender.userType,
      WEBSOCKET_EVENTS.MESSAGE_READ,
      {
        messageId: message._id,
        conversationId: message.conversationId,
        readBy: { userId, userType },
        readAt: new Date(),
      }
    );

    res.json({
      message: "Message marked as read",
      code: "MESSAGE_READ",
    });
  } catch (error) {
    console.error("Error marking message as read:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "MESSAGE_READ_ERROR",
    });
  }
};

// Note: Message deletion and editing are disabled for organizational security
// Once a message is sent, it cannot be modified or deleted

module.exports = {
  sendMessage,
  getConversationMessages,
  markMessageAsRead,
  // deleteMessage and editMessage removed for organizational security
};
