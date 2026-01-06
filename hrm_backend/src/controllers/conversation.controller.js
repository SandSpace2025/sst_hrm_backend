const mongoose = require("mongoose");
const Conversation = require("../models/conversation.model");
const Message = require("../models/message.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const websocketService = require("../services/websocket.service");
const { WEBSOCKET_EVENTS } = require("../constants/websocket.events");
const crypto = require("crypto");

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

// Create new conversation
const createConversation = async (req, res) => {
  try {
    const {
      participants,
      title,
      description,
      conversationType = "direct",
    } = req.body;
    const currentUserId = req.userId;
    const currentUserType = req.userRole; // From auth middleware
    // Normalize current user type to match validation matrix (Admin/HR/Employee)
    let normalizedCurrentUserType;
    if (typeof currentUserType === "string") {
      normalizedCurrentUserType =
        currentUserType.toLowerCase() === "hr"
          ? "HR"
          : currentUserType.charAt(0).toUpperCase() +
          currentUserType.slice(1).toLowerCase();
    } else {
      normalizedCurrentUserType = currentUserType;
    }

    // Validate participants
    if (!participants || participants.length < 2) {
      return res.status(400).json({
        message: "At least 2 participants required",
        code: "INVALID_PARTICIPANTS",
      });
    }

    // Validate messaging permissions for each participant
    console.log("🔍 Validating messaging permissions:");
    console.log("   currentUserType:", currentUserType);
    console.log("   normalizedCurrentUserType:", normalizedCurrentUserType);
    console.log(
      "   participants:",
      participants.map((p) => ({ userId: p.userId, userType: p.userType }))
    );

    for (const participant of participants) {
      console.log(
        `🔍 Checking permission: ${normalizedCurrentUserType} -> ${participant.userType}`
      );
      if (
        !validateMessagingPermissions(
          normalizedCurrentUserType,
          participant.userType
        )
      ) {
        console.log(
          `❌ Permission denied: ${normalizedCurrentUserType} cannot message ${participant.userType}`
        );
        return res.status(403).json({
          message: `You are not authorized to create conversations with ${participant.userType}`,
          code: "MESSAGING_NOT_ALLOWED",
        });
      }
      console.log(
        `✅ Permission granted: ${normalizedCurrentUserType} can message ${participant.userType}`
      );
    }

    // Add current user to participants if not already included
    const allParticipants = [...participants];
    console.log("🔍 Original participants:", participants.length);
    console.log(
      "   participants:",
      participants.map((p) => ({ userId: p.userId, userType: p.userType }))
    );

    const currentUserExists = allParticipants.some(
      (p) =>
        p.userId.toString() === currentUserId.toString() &&
        p.userType.toLowerCase() === normalizedCurrentUserType.toLowerCase()
    );

    console.log("🔍 Current user exists in participants:", currentUserExists);
    console.log("   currentUserId:", currentUserId);
    console.log("   currentUserType:", currentUserType);
    console.log("   normalizedCurrentUserType:", normalizedCurrentUserType);

    if (!currentUserExists) {
      allParticipants.push({
        userId: currentUserId,
        userType: normalizedCurrentUserType,
      });
    }

    console.log("🔍 Final allParticipants:", allParticipants.length);
    console.log(
      "   allParticipants:",
      allParticipants.map((p) => ({ userId: p.userId, userType: p.userType }))
    );

    // Check if direct conversation already exists between these participants
    if (conversationType === "direct" && allParticipants.length === 2) {
      const existingConversation = await Conversation.findDirectConversation(
        new mongoose.Types.ObjectId(allParticipants[0].userId),
        allParticipants[0].userType,
        new mongoose.Types.ObjectId(allParticipants[1].userId),
        allParticipants[1].userType
      );

      if (existingConversation) {
        return res.status(200).json({
          message: "Conversation already exists",
          conversation: existingConversation,
          code: "CONVERSATION_EXISTS",
        });
      }
    }

    // Generate conversation ID
    const conversationId = crypto.randomUUID();

    // Create conversation
    const conversation = new Conversation({
      conversationId,
      participants: allParticipants.map((p) => {
        // Normalize userType for conversation participants
        let normalizedUserType;
        if (p.userType.toLowerCase() === "hr") {
          normalizedUserType = "HR";
        } else {
          normalizedUserType =
            p.userType.charAt(0).toUpperCase() +
            p.userType.slice(1).toLowerCase();
        }

        return {
          userId: p.userId,
          userType: normalizedUserType,
          userRole: p.userRole,
          joinedAt: new Date(),
          isActive: true,
        };
      }),
      title:
        title || `Conversation with ${allParticipants.length} participants`,
      description,
      conversationType,
      settings: {
        allowNewParticipants: conversationType === "group",
        requireApproval: false,
        isArchived: false,
        isPinned: false,
      },
    });

    console.log("🔍 Saving conversation...");
    await conversation.save();
    console.log(
      "✅ Conversation saved successfully:",
      conversation.conversationId
    );

    // Emit websocket event for new conversation
    // Broadcast to each participant individually
    for (const participant of allParticipants) {
      websocketService.broadcastToUser(
        participant.userId,
        WEBSOCKET_EVENTS.CONVERSATION_CREATED,
        {
          conversation,
          message: "New conversation created",
        }
      );
    }

    console.log(
      "🚀 Sending success response for conversation:",
      conversation.conversationId
    );
    res.status(201).json({
      message: "Conversation created successfully",
      conversation,
      code: "CONVERSATION_CREATED",
    });
  } catch (error) {
    console.error("Error creating conversation:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "CONVERSATION_CREATE_ERROR",
    });
  }
};

// Get user conversations
const getUserConversations = async (req, res) => {
  try {
    const userId = req.userId;
    const userType = req.userRole;
    const {
      page = 1,
      limit = 20,
      isArchived = false,
      conversationType,
    } = req.query;

    // Normalize userType for query
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    const skip = (page - 1) * limit;
    const query = {
      "participants.userId": userId,
      "participants.userType": new RegExp(`^${normalizedUserType}$`, "i"),
      "participants.isActive": true,
      "settings.isArchived": isArchived === "true",
      status: "active",
    };

    if (conversationType) {
      query.conversationType = conversationType;
    }

    // Get conversations where user is participant
    const conversations = await Conversation.find(query)
      .populate("lastMessageId")
      .sort({ lastMessageAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Conversation.countDocuments(query);

    res.json({
      conversations,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
      code: "CONVERSATIONS_RETRIEVED",
    });
  } catch (error) {
    console.error("Error getting conversations:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "CONVERSATIONS_ERROR",
    });
  }
};

// Get conversation by ID
const getConversation = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.userId;
    const userType = req.userRole;

    // Normalize userType for query
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    // Find conversation and verify user is participant
    const conversation = await Conversation.findOne({
      conversationId,
      "participants.userId": userId,
      "participants.userType": normalizedUserType,
      "participants.isActive": true,
    });

    if (!conversation) {
      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }

    // Update last seen
    await conversation.updateLastSeen(userId, userType);

    res.json({
      conversation,
      code: "CONVERSATION_RETRIEVED",
    });
  } catch (error) {
    console.error("Error getting conversation:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "CONVERSATION_ERROR",
    });
  }
};

// Add participant to conversation
const addParticipant = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { userId, userType, userRole } = req.body;
    const currentUserId = req.userId;
    const currentUserType = req.userType;

    // Normalize currentUserType for query
    let normalizedCurrentUserType;
    if (currentUserType.toLowerCase() === "hr") {
      normalizedCurrentUserType = "HR";
    } else {
      normalizedCurrentUserType =
        currentUserType.charAt(0).toUpperCase() +
        currentUserType.slice(1).toLowerCase();
    }

    // Find conversation
    const conversation = await Conversation.findOne({
      conversationId,
      "participants.userId": currentUserId,
      "participants.userType": normalizedCurrentUserType,
      "participants.isActive": true,
    });

    if (!conversation) {
      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }

    // Check if conversation allows new participants
    if (!conversation.settings.allowNewParticipants) {
      return res.status(403).json({
        message: "Conversation does not allow new participants",
        code: "PARTICIPANTS_NOT_ALLOWED",
      });
    }

    // Normalize userType for participant
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    // Add participant
    await conversation.addParticipant(userId, normalizedUserType, userRole);

    // Emit websocket event
    websocketService.broadcastToUser(
      userId,
      userType,
      WEBSOCKET_EVENTS.CONVERSATION_UPDATED,
      {
        conversation,
        message: "You have been added to a conversation",
      }
    );

    res.json({
      message: "Participant added successfully",
      conversation,
      code: "PARTICIPANT_ADDED",
    });
  } catch (error) {
    console.error("Error adding participant:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "PARTICIPANT_ADD_ERROR",
    });
  }
};

// Remove participant from conversation
const removeParticipant = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { userId, userType } = req.body;
    const currentUserId = req.userId;
    const currentUserType = req.userType;

    // Normalize currentUserType for query
    let normalizedCurrentUserType;
    if (currentUserType.toLowerCase() === "hr") {
      normalizedCurrentUserType = "HR";
    } else {
      normalizedCurrentUserType =
        currentUserType.charAt(0).toUpperCase() +
        currentUserType.slice(1).toLowerCase();
    }

    // Find conversation
    const conversation = await Conversation.findOne({
      conversationId,
      "participants.userId": currentUserId,
      "participants.userType": normalizedCurrentUserType,
      "participants.isActive": true,
    });

    if (!conversation) {
      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }

    // Normalize userType for participant
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    // Remove participant
    await conversation.removeParticipant(userId, normalizedUserType);

    // Emit websocket event
    websocketService.broadcastToUser(
      userId,
      userType,
      WEBSOCKET_EVENTS.CONVERSATION_UPDATED,
      {
        conversation,
        message: "You have been removed from a conversation",
      }
    );

    res.json({
      message: "Participant removed successfully",
      conversation,
      code: "PARTICIPANT_REMOVED",
    });
  } catch (error) {
    console.error("Error removing participant:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "PARTICIPANT_REMOVE_ERROR",
    });
  }
};

// Mark conversation as read (update last seen)
const markAsRead = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.userId;
    const userType = req.userRole;

    // Normalize userType for query
    let normalizedUserType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    } else {
      normalizedUserType =
        userType.charAt(0).toUpperCase() + userType.slice(1).toLowerCase();
    }

    // Find conversation
    const conversation = await Conversation.findOne({
      conversationId,
      "participants.userId": userId,
      "participants.userType": normalizedUserType,
      "participants.isActive": true,
    });

    if (!conversation) {
      return res.status(404).json({
        message: "Conversation not found",
        code: "CONVERSATION_NOT_FOUND",
      });
    }

    // Update last seen
    await conversation.updateLastSeen(userId, normalizedUserType);

    res.json({
      message: "Conversation marked as read",
      code: "CONVERSATION_MARKED_READ",
    });
  } catch (error) {
    console.error("Error marking conversation as read:", error);
    res.status(500).json({
      message: "Internal server error",
      code: "MARK_READ_ERROR",
    });
  }
};

// Note: Conversation archiving and deletion are disabled for organizational security
// Conversations and messages are permanent records for audit purposes

module.exports = {
  createConversation,
  getUserConversations,
  getConversation,
  addParticipant,
  removeParticipant,
  markAsRead,
  // archiveConversation, unarchiveConversation, deleteConversation removed for organizational security
};
