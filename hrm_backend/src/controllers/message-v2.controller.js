const Message = require("../models/message.model");
const Conversation = require("../models/conversation.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const websocketService = require("../services/websocket.service");
const { WEBSOCKET_EVENTS } = require("../constants/websocket.events");
const logger = require("../core/logger");

// Helper function to get user information (Robust: Checks Auth ID, Doc ID, AND Cross-Collection)
const getUserInfo = async (userId, userType) => {
  try {
    let user;
    const queryAuthId = { user: userId };
    let finalType = userType;

    // Helper to try find user in a specific model
    const findInModel = async (Model) => {
      let u = await Model.findOne(queryAuthId);
      if (!u) u = await Model.findById(userId);
      return u;
    };

    // 1. Try Primary Type
    const typeLower = userType.toLowerCase();
    if (typeLower === "admin") user = await findInModel(Admin);
    else if (typeLower === "hr") user = await findInModel(HR);
    else if (typeLower === "employee") user = await findInModel(Employee);

    // 2. Brute Force Fallback (if not found in expected type)
    if (!user) {
      // Try other collections
      if (!user) {
        user = await findInModel(Employee);
        if (user) finalType = "employee";
      }
      if (!user) {
        user = await findInModel(HR);
        if (user) finalType = "hr";
      }
      if (!user) {
        user = await findInModel(Admin);
        if (user) finalType = "admin";
      }
    }

    if (user) {
      // Map based on final found type
      const finalTypeLower = finalType.toLowerCase();
      if (finalTypeLower === "admin")
        return { name: user.fullName || "Admin", email: user.email };
      if (finalTypeLower === "hr")
        return { name: user.name || "HR", email: user.email };
      if (finalTypeLower === "employee")
        return { name: user.name || "Employee", email: user.email };
    }

    return {
      name: "Unknown User",
      email: "unknown@example.com",
    };
  } catch (error) {
    logger.error("Error getting user info", { error: error.message });
    return {
      name: "Unknown User",
      email: "unknown@example.com",
    };
  }
};

// Helper function to validate messaging permissions
const validateMessagingPermissions = (senderType, receiverType) => {
  const sender = senderType.toLowerCase();
  const receiver = receiverType.toLowerCase();

  // Admin and HR can message anyone
  if (sender === "admin" || sender === "hr") {
    return true;
  }

  // Employee restrictions
  if (sender === "employee") {
    // Employee can only message HR and other employees
    // Employee CANNOT message admin
    if (receiver === "hr" || receiver === "employee") {
      return true;
    }
    return false;
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
      normalizedSenderUserType,
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
            participant.userType,
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
        (p) => p.userId.toString() !== senderUserId.toString() && p.isActive,
      )
      .map((p) => ({ userId: p.userId, userType: p.userType }));

    let receiverId;
    let receiverModel;

    if (otherParticipants.length > 0) {
      receiverId = otherParticipants[0].userId;
      receiverModel = otherParticipants[0].userType;
    } else {
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
      content: content,
      messageType,
      replyTo,
      isReply: !!replyTo,
    });

    // Emit websocket event to other participants (iterate recipients)
    if (otherParticipants.length > 0) {
      // Check for duplicates in participants (Split Brain / Targeting integrity check)
      const uniqueIds = new Set(
        otherParticipants.map((p) => p.userId.toString()),
      );
      if (uniqueIds.size !== otherParticipants.length) {
        logger.warn(
          `Duplicate participants detected in conversation ${conversationId}. This may cause double delivery.`,
        );
      }

      const payload = {
        messageId: message._id,
        conversationId,
        sender: message.sender,
        content: content,
        messageType,
        createdAt: message.createdAt,
        message: "New message received",
      };

      for (const participant of otherParticipants) {
        if (participant?.userId) {
          websocketService.broadcastToUser(
            participant.userId.toString(),
            WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
            payload,
          );
        } else {
          logger.warn(
            `Participant with missing userId encountered in conversation ${conversationId}`,
          );
        }
      }
    } else {
      logger.warn(
        `No other participants found for conversation ${conversationId}. Message ${message._id} was saved but may not be delivered to anyone.`,
      );
    }

    // Send confirmation to sender
    websocketService.broadcastToUser(
      senderUserId.toString(),
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        messageId: message._id,
        conversationId,
        message: "Message sent successfully",
      },
    );

    // Return the full message object
    res.status(201).json({
      message: "Message sent successfully",
      messageId: message._id,
      messageData: message.toObject(),
      code: "MESSAGE_SENT",
    });
  } catch (error) {
    logger.error("Error sending message", { error: error.message });
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

    const conversation = await Conversation.findOne({
      conversationId,
      "participants.userId": userId,
      "participants.userType": new RegExp(`^${normalizedUserType}$`, "i"),
      "participants.isActive": true,
    });

    if (!conversation) {
      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }

    let conversationIds = [conversationId];

    const uniqueParticipantIds = [
      ...new Set(conversation.participants.map((p) => p.userId.toString())),
    ];

    if (conversation.conversationType === "direct") {
      try {
        // Identify the "other" participant
        const otherParticipant = conversation.participants.find(
          (p) => p.userId.toString() !== userId.toString(),
        );

        if (otherParticipant) {
          const otherUserInfo = await getUserInfo(
            otherParticipant.userId,
            otherParticipant.userType,
          );
          const otherUserEmail = otherUserInfo.email;

          if (otherUserEmail && otherUserEmail !== "unknown@example.com") {
            const myConversations = await Conversation.find({
              conversationType: "direct",
              "participants.userId": userId,
            });

            for (const myConv of myConversations) {
              if (conversationIds.includes(myConv.conversationId)) continue;

              const otherP = myConv.participants.find(
                (p) => p.userId.toString() !== userId.toString(),
              );
              if (otherP) {
                const info = await getUserInfo(otherP.userId, otherP.userType);
                if (info.email === otherUserEmail) {
                  conversationIds.push(myConv.conversationId);
                }
              }
            }
          }
        }
      } catch (err) {
        logger.error("Error finding related conversations", {
          error: err.message,
        });
      }
    }

    const skip = (page - 1) * limit;

    // Get messages
    const messages = await Message.find({
      conversationId: { $in: conversationIds },
      isArchived: false,
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Return messages as-is (no decryption needed)
    const messageObjects = messages.map((message) => message.toObject());

    // Update last seen
    await conversation.updateLastSeen(userId, normalizedUserType);

    const convObj = conversation.toObject();
    const participantsWithDetails = await Promise.all(
      convObj.participants.map(async (p) => {
        try {
          // Use the robust getUserInfo (local to this file)
          const userInfo = await getUserInfo(p.userId, p.userType);
          return {
            ...p,
            name: p.name || userInfo.name,
            email: userInfo.email || "no-email-found",
          };
        } catch (e) {
          logger.error(`Msg List Enrichment Failed for ${p.userId}`, {
            error: e.message,
          });
          return p;
        }
      }),
    );
    const enrichedConversation = {
      ...convObj,
      participants: participantsWithDetails,
    };

    res.json({
      messages: messageObjects,
      conversation: enrichedConversation,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(conversation.messageCount / limit),
        totalItems: conversation.messageCount,
        itemsPerPage: parseInt(limit),
      },
      code: "MESSAGES_RETRIEVED",
    });
  } catch (error) {
    logger.error("Error getting messages", { error: error.message });
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
      },
    );

    res.json({
      message: "Message marked as read",
      code: "MESSAGE_READ",
    });
  } catch (error) {
    logger.error("Error marking message as read", { error: error.message });
    res.status(500).json({
      message: "Internal server error",
      code: "MESSAGE_READ_ERROR",
    });
  }
};

module.exports = {
  sendMessage,
  getConversationMessages,
  markMessageAsRead,
};
