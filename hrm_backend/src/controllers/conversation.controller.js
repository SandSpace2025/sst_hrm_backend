const mongoose = require("mongoose");
const Conversation = require("../models/conversation.model");
const Message = require("../models/message.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const websocketService = require("../services/websocket.service");
const { WEBSOCKET_EVENTS } = require("../constants/websocket.events");
const crypto = require("crypto");
const logger = require("../core/logger");

const getUserInfo = async (userId, userType) => {
  try {
    let user;
    const queryAuthId = { user: userId };
    let finalType = userType;

    const findInModel = async (Model) => {
      let u = await Model.findOne(queryAuthId);
      if (!u) u = await Model.findById(userId);
      return u;
    };

    const typeLower = userType.toLowerCase();
    if (typeLower === "admin") user = await findInModel(Admin);
    else if (typeLower === "hr") user = await findInModel(HR);
    else if (typeLower === "employee") user = await findInModel(Employee);

    if (!user) {
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
    logger.error("Get user info failed", {
      error: error.message,
      userId: userId,
      userType: userType,
    });
    return {
      name: "Unknown User",
      email: "unknown@example.com",
    };
  }
};

const validateMessagingPermissions = (senderType, receiverType) => {
  const sender = senderType.toLowerCase();
  const receiver = receiverType.toLowerCase();

  // Admin and HR can message anyone
  if (sender === "admin" || sender === "hr") {
    return true;
  }

  // Employee can only message HR and other employees
  if (sender === "employee") {
    if (receiver === "hr" || receiver === "employee") {
      return true;
    }
    return false;
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
    // Normalize current user type strictly for DB consistency
    let normalizedCurrentUserType;
    const typeLower =
      typeof currentUserType === "string" ? currentUserType.toLowerCase() : "";

    if (typeLower === "hr") normalizedCurrentUserType = "HR";
    else if (typeLower === "admin") normalizedCurrentUserType = "Admin";
    else normalizedCurrentUserType = "Employee";

    if (!participants || participants.length < 2) {
      return res.status(400).json({
        message: "At least 2 participants required",
        code: "INVALID_PARTICIPANTS",
      });
    }

    const allParticipants = [...participants];

    const currentUserExists = allParticipants.some(
      (p) =>
        p.userId.toString() === currentUserId.toString() &&
        p.userType.toLowerCase() === normalizedCurrentUserType.toLowerCase(),
    );

    if (!currentUserExists) {
      allParticipants.push({
        userId: currentUserId,
        userType: normalizedCurrentUserType,
      });
    }

    // Check if direct conversation already exists between these participants
    if (conversationType === "direct" && allParticipants.length === 2) {
      const existingConversation = await Conversation.findDirectConversation(
        new mongoose.Types.ObjectId(allParticipants[0].userId),
        allParticipants[0].userType,
        new mongoose.Types.ObjectId(allParticipants[1].userId),
        allParticipants[1].userType,
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

    await conversation.save();

    // Emit websocket event for new conversation
    // Broadcast to each participant individually
    for (const participant of allParticipants) {
      websocketService.broadcastToUser(
        participant.userId,
        WEBSOCKET_EVENTS.CONVERSATION_CREATED,
        {
          conversation,
          message: "New conversation created",
        },
      );
    }

    res.status(201).json({
      message: "Conversation created successfully",
      conversation,
      code: "CONVERSATION_CREATED",
    });
  } catch (error) {
    logger.error("Create conversation failed", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
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

    // Enrich conversations with participant details
    const enrichedConversations = await Promise.all(
      conversations.map(async (conv) => {
        const convObj = conv.toObject();
        const participantsWithDetails = await Promise.all(
          convObj.participants.map(async (p) => {
            try {
              const userInfo = await getUserInfo(p.userId, p.userType);

              return {
                ...p,
                participantId: p.userId, // Ensure frontend compatibility
                name:
                  userInfo.name !== "Unknown User"
                    ? userInfo.name
                    : p.name || "Unknown",
                email: userInfo.email,
                avatar: userInfo.avatar || p.avatar,
              };
            } catch (e) {
              logger.error("Participant enrichment failed", {
                error: e.message,
                participantId: p.userId,
              });
              return p;
            }
          }),
        );
        return {
          ...convObj,
          participants: participantsWithDetails,
        };
      }),
    );

    const total = await Conversation.countDocuments(query);

    res.json({
      conversations: enrichedConversations,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
      code: "CONVERSATIONS_RETRIEVED",
    });
  } catch (error) {
    logger.error("Get user conversations failed", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
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

    // Enrich conversation with participant details
    const convObj = conversation.toObject();
    const participantsWithDetails = await Promise.all(
      convObj.participants.map(async (p) => {
        try {
          const userInfo = await getUserInfo(p.userId, p.userType);
          return {
            ...p,
            participantId: p.userId,
            name:
              userInfo.name !== "Unknown User"
                ? userInfo.name
                : p.name || "Unknown",
            email: userInfo.email,
            avatar: userInfo.avatar || p.avatar,
          };
        } catch (e) {
          logger.error("Participant enrichment failed", {
            error: e.message,
            participantId: p.userId,
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
      conversation: enrichedConversation,
      code: "CONVERSATION_RETRIEVED",
    });
  } catch (error) {
    logger.error("Get conversation failed", {
      error: error.message,
      stack: error.stack,
      conversationId: req.params.conversationId,
    });
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
      },
    );

    res.json({
      message: "Participant added successfully",
      conversation,
      code: "PARTICIPANT_ADDED",
    });
  } catch (error) {
    logger.error("Add participant failed", {
      error: error.message,
      stack: error.stack,
      conversationId: req.params.conversationId,
    });
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
      },
    );

    res.json({
      message: "Participant removed successfully",
      conversation,
      code: "PARTICIPANT_REMOVED",
    });
  } catch (error) {
    logger.error("Remove participant failed", {
      error: error.message,
      stack: error.stack,
      conversationId: req.params.conversationId,
    });
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
    logger.error("Mark conversation as read failed", {
      error: error.message,
      stack: error.stack,
      conversationId: req.params.conversationId,
    });
    res.status(500).json({
      message: "Internal server error",
      code: "MARK_READ_ERROR",
    });
  }
};

module.exports = {
  createConversation,
  getUserConversations,
  getConversation,
  addParticipant,
  removeParticipant,
  markAsRead,
};
