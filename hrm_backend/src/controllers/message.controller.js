const Message = require("../models/message.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const websocketService = require("../services/websocket.service");
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");

// Send message to employee (admin only) - Updated to use simple messaging
const sendMessageToEmployee = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const adminUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Find admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Find the employee
    const employee = await Employee.findById(recipientId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Create deterministic conversationId
    const conversationId = `Admin:${admin._id}|Employee:${employee._id}`;

    // Create message
    const message = new Message({
      conversationId,
      sender: {
        userId: admin._id,
        userType: "Admin",
        name: admin.fullName,
        email: admin.email || "admin@example.com",
      },
      receiver: employee._id,
      receiverModel: "Employee",
      content,
      messageType: "text",
      priority: priority || "normal",
      isApproved: true,
      isRead: false,
    });

    await message.save();

    // Removed legacy emit (now using standardized events only)

    // Build standardized payload
    const messageData = {
      messageId: message._id,
      conversationId,
      sender: message.sender,
      content: message.content,
      messageType: message.messageType,
      createdAt: message.createdAt,
    };

    // Notify the receiver (standardized event)
    websocketService.broadcastToUser(
      employee.user.toString(), // Convert ObjectId to string
      WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
      {
        ...messageData,
        sender: {
          _id: admin._id.toString(),
          userId: admin._id.toString(),
          userType: "Admin",
          name: admin.fullName,
          email: admin.email || "admin@example.com",
        },
        receiver: {
          _id: employee._id.toString(),
          userId: employee._id.toString(),
          userType: "Employee",
          name: employee.name,
          email: employee.email || "employee@example.com",
        },
        message: "You have received a new message",
      }
    );

    // Notify the sender (confirmation, standardized event)
    websocketService.broadcastToUser(
      admin.user.toString(), // Convert ObjectId to string
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        ...messageData,
        message: "Your message has been sent successfully",
      }
    );

    // --- Start Notification Logic ---
    try {
      if (employee.user) {
        const notificationService = require("../services/notification.service");
        const User = require("../models/user.model");
        const user = await User.findById(employee.user).select("fcmToken");

        if (user && user.fcmToken) {
          await notificationService.sendNotification(
            user.fcmToken,
            `New Message from ${admin.fullName}`,
            content.substring(0, 100) + (content.length > 100 ? "..." : ""),
            {
              type: "message",
              conversationId: conversationId,
              senderId: admin._id.toString(),
              senderName: admin.fullName
            }
          );
        }
      }
    } catch (notifErr) {
      console.error("Failed to send message notification:", notifErr);
    }
    // --- End Notification Logic ---

    // // console.log("Message sent successfully:", message._id);

    res.status(201).json({
      message: "Message sent successfully",
      data: message,
    });
  } catch (error) {
    console.error("Error sending message to employee:", error);
    res.status(500).json({
      message: "Internal server error",
      error: error.message,
    });
  }
};

// Send message to HR (admin to HR) - Updated to use simple messaging
const sendMessageToHR = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const adminUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Find admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Find the HR user
    const HR = require("../models/hr.model");
    const hrUser = await HR.findById(recipientId);
    if (!hrUser) {
      return res.status(404).json({ message: "HR user not found" });
    }

    // Create deterministic conversationId
    const conversationId = `Admin:${admin._id}|HR:${hrUser._id}`;



    // Create message
    const message = new Message({
      conversationId,
      sender: {
        userId: admin._id,
        userType: "Admin",
        name: admin.fullName,
        email: admin.email || "admin@example.com",
      },
      receiver: hrUser._id,
      receiverModel: "HR",
      content,
      messageType: "text",
      priority: priority || "normal",
      isApproved: true,
      isRead: false,
    });

    await message.save();


    // Removed legacy emit (now using standardized events only)

    // Build standardized payload
    const messageData = {
      messageId: message._id,
      conversationId,
      sender: message.sender,
      content: message.content,
      messageType: message.messageType,
      createdAt: message.createdAt,
    };

    // Notify the receiver (standardized event)
    if (hrUser.user) {
      websocketService.broadcastToUser(
        hrUser.user.toString(),
        WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
        {
          ...messageData,
          sender: {
            _id: admin._id.toString(),
            userId: admin._id.toString(),
            userType: "Admin",
            name: admin.fullName,
            email: admin.email || "admin@example.com",
          },
          receiver: {
            _id: hrUser._id.toString(),
            userId: hrUser._id.toString(),
            userType: "HR",
            name: hrUser.name,
            email: hrUser.email || "hr@example.com",
          },
          message: "You have received a new message",
        }
      );
    }

    // Notify the sender (confirmation, standardized event)
    if (admin.user) {
      websocketService.broadcastToUser(
        admin.user.toString(),
        WEBSOCKET_EVENTS.MESSAGE_SENT,
        {
          ...messageData,
          message: "Your message has been sent successfully",
        }
      );
    }

    // --- Start Notification Logic ---
    try {
      if (hrUser.user) {
        const notificationService = require("../services/notification.service");
        const User = require("../models/user.model");
        const user = await User.findById(hrUser.user).select("fcmToken");

        if (user && user.fcmToken) {
          await notificationService.sendNotification(
            user.fcmToken,
            `New Message from ${admin.fullName}`,
            content.substring(0, 100) + (content.length > 100 ? "..." : ""),
            {
              type: "message",
              conversationId: conversationId,
              senderId: admin._id.toString(),
              senderName: admin.fullName
            }
          );
        }
      }
    } catch (notifErr) {
      console.error("Failed to send message notification:", notifErr);
    }
    // --- End Notification Logic ---

    res.status(201).json({
      message: "Message sent successfully",
      data: message,
    });
  } catch (error) {
    console.error("Error sending message to HR:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get all messages for admin (sent and received)
const getAdminMessages = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      messageType,
      status,
      priority,
      isRead,
      isArchived = false,
      sortBy = "createdAt",
      sortOrder = "desc",
    } = req.query;

    const adminId = req.userId;

    // Find the admin
    const admin = await Admin.findOne({ user: adminId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const query = {
      $or: [
        { sender: admin._id, senderModel: "Admin" },
        { receiver: admin._id, receiverModel: "Admin" },
      ],
      isArchived: isArchived === "true",
    };

    if (messageType) {
      query.messageType = messageType;
    }

    if (status) {
      query.status = status;
    }

    if (priority) {
      query.priority = priority;
    }

    if (isRead !== undefined) {
      query.isRead = isRead === "true";
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === "desc" ? -1 : 1;

    const messages = await Message.find(query)
      .populate("sender", "fullName name email")
      .populate("receiver", "fullName name email employeeId")
      .sort(sortOptions)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Message.countDocuments(query);

    res.json({
      messages,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching admin messages:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get conversation with specific user
const getConversation = async (req, res) => {
  try {
    const { userId, userType } = req.params;
    const { page = 1, limit = 50 } = req.query;

    const adminId = req.userId;

    // Find the admin
    const admin = await Admin.findOne({ user: adminId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Normalize userType to match message model enum values
    let normalizedUserType = userType;
    if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR"; // HR users use "HR" receiverModel
    } else if (userType.toLowerCase() === "employee") {
      normalizedUserType = "Employee";
    } else if (userType.toLowerCase() === "admin") {
      normalizedUserType = "Admin";
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const query = {
      $and: [
        {
          $or: [
            {
              sender: admin._id,
              senderModel: "Admin",
              receiver: userId,
              receiverModel: normalizedUserType,
            },
            {
              sender: userId,
              senderModel: normalizedUserType,
              receiver: admin._id,
              receiverModel: "Admin",
            },
          ],
        },
        { isArchived: false },
        {
          // Show messages where isApproved is true OR undefined (for backward compatibility)
          $or: [{ isApproved: true }, { isApproved: { $exists: false } }],
        },
      ],
    };

    const messages = await Message.find(query)
      .populate("sender", "fullName name email")
      .populate("receiver", "fullName name email employeeId")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Message.countDocuments({
      $and: [
        {
          $or: [
            {
              sender: admin._id,
              senderModel: "Admin",
              receiver: userId,
              receiverModel: normalizedUserType,
            },
            {
              sender: userId,
              senderModel: normalizedUserType,
              receiver: admin._id,
              receiverModel: "Admin",
            },
          ],
        },
        { isArchived: false },
        {
          // Show messages where isApproved is true OR undefined (for backward compatibility)
          $or: [{ isApproved: true }, { isApproved: { $exists: false } }],
        },
      ],
    });

    res.json({
      messages: messages.reverse(), // Show oldest first
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching conversation:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Mark message as read
const markAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    await message.markAsRead();

    res.json({ message: "Message marked as read" });
  } catch (error) {
    console.error("Error marking message as read:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Mark multiple messages as read
const markMultipleAsRead = async (req, res) => {
  try {
    const { messageIds } = req.body;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      return res.status(400).json({ message: "Message IDs array is required" });
    }

    const result = await Message.updateMany(
      { _id: { $in: messageIds } },
      {
        isRead: true,
        readAt: new Date(),
        status: "read",
      }
    );

    res.json({
      message: `${result.modifiedCount} messages marked as read`,
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error("Error marking multiple messages as read:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Archive message
const archiveMessage = async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    await message.archive();

    res.json({ message: "Message archived" });
  } catch (error) {
    console.error("Error archiving message:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Delete message
const deleteMessage = async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    await Message.findByIdAndDelete(messageId);

    res.json({ message: "Message deleted successfully" });
  } catch (error) {
    console.error("Error deleting message:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get message statistics
const getMessageStats = async (req, res) => {
  try {
    const adminId = req.userId;

    // Find the admin
    const admin = await Admin.findOne({ user: adminId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const totalMessages = await Message.countDocuments({
      $or: [
        { sender: admin._id, senderModel: "Admin" },
        { receiver: admin._id, receiverModel: "Admin" },
      ],
    });

    const unreadMessages = await Message.countDocuments({
      receiver: admin._id,
      receiverModel: "Admin",
      isRead: false,
      isArchived: false,
    });

    const sentMessages = await Message.countDocuments({
      sender: admin._id,
      senderModel: "Admin",
    });

    const receivedMessages = await Message.countDocuments({
      receiver: admin._id,
      receiverModel: "Admin",
    });

    const urgentMessages = await Message.countDocuments({
      $or: [
        { sender: admin._id, senderModel: "Admin" },
        { receiver: admin._id, receiverModel: "Admin" },
      ],
      priority: "urgent",
      isArchived: false,
    });

    res.json({
      stats: {
        total: totalMessages,
        unread: unreadMessages,
        sent: sentMessages,
        received: receivedMessages,
        urgent: urgentMessages,
      },
    });
  } catch (error) {
    console.error("Error fetching message stats:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get employees list for messaging
const getEmployeesForMessaging = async (req, res) => {
  try {
    const { search, page = 1, limit = 20 } = req.query;

    const query = {};
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { employeeId: { $regex: search, $options: "i" } },
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const employees = await Employee.find(query)
      .select("name email employeeId jobTitle department profilePic")
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Employee.countDocuments(query);

    res.json({
      employees,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching employees for messaging:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get HR list for messaging
const getHRForMessaging = async (req, res) => {
  try {
    const { search, page = 1, limit = 20 } = req.query;
    const HR = require("../models/hr.model");

    // // console.log("Fetching HR users for messaging, search:", search);

    // Build query to find HR users from the HR collection
    const query = {};

    // Add search filter if provided
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { employeeId: { $regex: search, $options: "i" } },
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Fetch HR users from the HR collection
    const hrUsers = await HR.find(query)
      .select("name email employeeId phone subOrganisation profilePic")
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await HR.countDocuments(query);

    // // console.log(`Found ${total} HR users, returning ${hrUsers.length}`);

    // Format response to match expected structure (using 'name' field)
    const formattedHrUsers = hrUsers.map((hr) => ({
      _id: hr._id,
      fullName: hr.name, // Map 'name' to 'fullName' for consistency
      name: hr.name,
      email: hr.email,
      employeeId: hr.employeeId,
      phone: hr.phone,
      subOrganisation: hr.subOrganisation,
      profilePic: hr.profilePic,
    }));

    res.json({
      hrUsers: formattedHrUsers,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching HR for messaging:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Approve existing messages for employees with valid messaging permissions
const approveEmployeeMessages = async (req, res) => {
  try {
    const Employee = require("../models/employee.model");

    // Find all unapproved employee-to-admin messages
    const unapprovedMessages = await Message.find({
      senderModel: "Employee",
      receiverModel: "Admin",
      isApproved: false,
    }).populate("sender");

    let approvedCount = 0;
    const now = new Date();

    for (const message of unapprovedMessages) {
      if (message.sender && message.sender.messagingPermissions) {
        const hasValidPermission =
          message.sender.messagingPermissions.canMessage &&
          message.sender.messagingPermissions.expiresAt &&
          new Date(message.sender.messagingPermissions.expiresAt) > now;

        if (hasValidPermission) {
          // Update message to be approved
          await Message.findByIdAndUpdate(message._id, {
            isApproved: true,
            requiresApproval: false,
          });
          approvedCount++;
        }
      }
    }

    res.json({
      message: `Approved ${approvedCount} messages for employees with valid permissions`,
      approvedCount,
      totalChecked: unapprovedMessages.length,
    });
  } catch (error) {
    console.error("Error approving employee messages:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get admin conversation using simple conversationId format
const getAdminConversationSimple = async (req, res) => {
  try {
    const { userId, userType } = req.params;
    const adminUserId = req.userId;

    // Find admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Determine conversationId based on userType
    let conversationId;
    const lowerType = userType.toLowerCase();

    if (lowerType === "employee") {
      conversationId = `Admin:${admin._id}|Employee:${userId}`;
    } else if (lowerType === "hr") {
      conversationId = `Admin:${admin._id}|HR:${userId}`;
    } else {
      return res.status(400).json({ message: "Invalid userType" });
    }



    // Get conversation using conversationId
    const conversation = await Message.find({ conversationId })
      .sort({ createdAt: 1 })
      .lean();



    res.status(200).json({
      conversation,
      total: conversation.length,
    });
  } catch (err) {
    console.error("Error getting admin conversation:", err);
    res.status(500).json({ message: err.message });
  }
};

module.exports = {
  sendMessageToEmployee,
  sendMessageToHR,
  getAdminMessages,
  getConversation,
  markAsRead,
  markMultipleAsRead,
  archiveMessage,
  deleteMessage,
  getMessageStats,
  getEmployeesForMessaging,
  getHRForMessaging,
  approveEmployeeMessages,
  getAdminConversationSimple,
};
