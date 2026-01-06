const User = require("../models/user.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Admin = require("../models/admin.model");
const Payroll = require("../models/payroll.model");
const Announcement = require("../models/announcement.model");
const Message = require("../models/message.model");
const mongoose = require("mongoose");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const websocketService = require("../services/websocket.service");
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");

// Import LeaveRequest if it exists, otherwise handle gracefully
let LeaveRequest;
try {
  LeaveRequest = require("../models/leaveRequest.model");
} catch (err) {
  // // console.log("LeaveRequest model not found");
  LeaveRequest = null;
}

/**
 * @description Get employee leave data for HR management
 */
exports.getEmployeeLeaveData = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const hrUserId = req.userId;

    // // console.log("🏢 HR Controller - getEmployeeLeaveData called");
    // // console.log("🏢 HR Controller - Employee ID:", employeeId);
    // // console.log("🏢 HR Controller - HR User ID:", hrUserId);
    // // console.log("🏢 HR Controller - Request headers:", req.headers);

    // Verify HR has access to this employee
    // // console.log("🏢 HR Controller - Looking for HR profile...");
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }
    // // console.log("✅ HR Controller - HR profile found:", hrProfile.name);

    // Find employee
    // // console.log("🏢 HR Controller - Looking for employee...");
    const employee = await Employee.findById(employeeId);
    if (!employee) {
      // // console.log("❌ HR Controller - Employee not found with ID:", employeeId);
      return res.status(404).json({ message: "Employee not found" });
    }

    // Return employee leave data
    const response = {
      employeeId: employee._id,
      employeeName: employee.name,
      leaveBalance: employee.leaveBalance,
      leaveHistory: employee.leaveHistory,
    };

    res.status(200).json(response);
  } catch (err) {
    console.error("❌ HR Controller - Error getting employee leave data:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update employee leave data (HR only)
 */
exports.updateEmployeeLeaveData = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const hrUserId = req.userId;
    const {
      casualLeave,
      workFromHome,
      permissionHours,
      carryOverCasual,
      carryOverWfh,
      carryOverPermission,
    } = req.body;

    // Verify HR has access to this employee
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find employee
    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Update leave balance
    employee.leaveBalance = {
      casualLeave: casualLeave || 1,
      workFromHome: workFromHome || 1,
      permissionHours: permissionHours || 3,
    };

    // Update leave history with carry-over data
    if (!employee.leaveHistory) {
      employee.leaveHistory = {
        lastResetDate: new Date(),
        totalCasualLeavesUsed: 0,
        totalSickLeavesUsed: 0,
        totalWFHUsed: 0,
        totalPermissionHoursUsed: 0,
      };
    }

    // Add carry-over leaves to the current balance
    if (carryOverCasual > 0) {
      employee.leaveBalance.casualLeave += carryOverCasual;
    }
    if (carryOverWfh > 0) {
      employee.leaveBalance.workFromHome += carryOverWfh;
    }
    if (carryOverPermission > 0) {
      employee.leaveBalance.permissionHours += carryOverPermission;
    }

    await employee.save();

    res.status(200).json({
      message: "Employee leave data updated successfully",
      leaveBalance: employee.leaveBalance,
      leaveHistory: employee.leaveHistory,
    });
  } catch (err) {
    console.error("Error updating employee leave data:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get HR dashboard summary with employee count and basic stats
 */
exports.getHRDashboardSummary = async (req, res) => {
  try {
    const hrUserId = req.userId;

    // Find HR profile to get subOrganisation
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const hrSubOrganisation = hrProfile.subOrganisation;
    const hrProfileId = hrProfile._id;

    // Count total employees under both sub-organisations
    const totalEmployees = await Employee.countDocuments({
      subOrganisation: {
        $in: ["Academic Overseas", "SandSpace Technologies Pvt Ltd."],
      },
    });
    const unreadSenderIds = await Message.find({
      receiver: hrProfileId,
      receiverModel: "HR",
      isRead: false,
      isApproved: true,
    }).distinct("sender.userId");
    // Get unread messages for this HR with sender details
    const unreadMessagesData = await Message.find({
      receiver: hrProfileId,
      receiverModel: "HR",
      isRead: false,
      isApproved: true,
    })
      .populate("sender", "name email fullName")
      .sort({ createdAt: -1 })
      .limit(5)
      .lean();

    const unreadMessages = unreadSenderIds.length;

    // Count pending leave approvals for employees under both sub-organisations
    let pendingLeaveApprovals = 0;
    if (LeaveRequest) {
      const employeeIds = await Employee.find({
        subOrganisation: {
          $in: ["Academic Overseas", "SandSpace Technologies Pvt Ltd."],
        },
      }).distinct("_id");

      pendingLeaveApprovals = await LeaveRequest.countDocuments({
        employee: { $in: employeeIds },
        status: "pending",
      });
    }

    // Calculate date 5 days ago
    const fiveDaysAgo = new Date();
    fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);

    // Get announcements from the last 5 days for employees/HR
    const recentAnnouncements = await Announcement.find({
      audience: { $in: ["employees", "all", "hr"] },
      isActive: true,
      createdAt: { $gte: fiveDaysAgo },
    })
      .sort({ createdAt: -1 })
      .select("title message createdAt priority createdBy createdByModel")
      .lean();

    // Populate creator information for each announcement
    for (const announcement of recentAnnouncements) {
      try {
        if (announcement.createdByModel === "Admin") {
          const admin = await Admin.findById(announcement.createdBy)
            .select("fullName designation")
            .lean();
          if (admin) {
            announcement.createdBy = admin;
          }
        } else if (announcement.createdByModel === "HR") {
          const hr = await HR.findById(announcement.createdBy)
            .select("name email")
            .lean();
          if (hr) {
            announcement.createdBy = hr;
          }
        } else {
          // Fallback for legacy announcements - try both models
          try {
            const admin = await Admin.findById(announcement.createdBy)
              .select("fullName designation")
              .lean();
            if (admin) {
              announcement.createdBy = admin;
            }
          } catch (adminError) {
            try {
              const hr = await HR.findById(announcement.createdBy)
                .select("name email")
                .lean();
              if (hr) {
                announcement.createdBy = hr;
              }
            } catch (hrError) {}
          }
        }
      } catch (populateError) {
        console.error(
          "❌ [ERROR] Error populating announcement creator:",
          populateError.message
        );
      }
    }

    res.status(200).json({
      totalEmployees,
      unreadMessages,
      unreadMessagesData,
      pendingLeaveApprovals,
      recentAnnouncements,
      unreadSenderIds,
    });
  } catch (error) {
    console.error("HR Dashboard Summary Error:", error);
    res.status(500).json({
      message: "Failed to fetch dashboard summary",
      error: error.message,
    });
  }
};

/**
 * @description Mark message as read
 */
exports.markMessageAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;
    const hrUserId = req.userId;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Update message as read
    const message = await Message.findByIdAndUpdate(
      messageId,
      { isRead: true },
      { new: true }
    );

    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    res.status(200).json({ message: "Message marked as read" });
  } catch (err) {
    console.error("Error marking message as read:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Mark conversation as seen (all messages in conversation)
 */
exports.markConversationAsSeen = async (req, res) => {
  try {
    const { userId, userType } = req.params;
    const hrUserId = req.userId;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const hrProfileId = hrProfile._id;

    // Normalize userType
    let normalizedUserType = userType;
    if (userType.toLowerCase() === "admin") {
      normalizedUserType = "Admin";
    } else if (userType.toLowerCase() === "employee") {
      normalizedUserType = "Employee";
    }
    // Mark all unread messages in this conversation as seen
    // Mark all unread messages in this conversation as seen
    const result = await Message.updateMany(
      {
        $or: [
          { "sender.userId": userId },
          { "sender.userId": new mongoose.Types.ObjectId(userId) },
          { sender: userId }, // potential legacy format
          { sender: new mongoose.Types.ObjectId(userId) },
        ],
        receiver: hrProfileId,
        receiverModel: "HR",
        isRead: false,
        isApproved: true,
      },
      { isRead: true }
    );

    res.status(200).json({
      message: "Conversation marked as seen",
      updatedCount: result.modifiedCount,
    });
  } catch (err) {
    console.error("Error marking conversation as seen:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get HR profile information
 */
exports.getHRProfile = async (req, res) => {
  try {
    const hrUserId = req.userId;

    const hrProfile = await HR.findOne({ user: hrUserId }).populate(
      "user",
      "email role"
    );

    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    res.status(200).json(hrProfile);
  } catch (err) {
    console.error("Error getting HR profile:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update HR profile
 */
exports.updateHRProfile = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { name, phone, subOrganisation } = req.body;

    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;
    if (subOrganisation) updateData.subOrganisation = subOrganisation;
    if (req.body.bloodGroup !== undefined)
      updateData.bloodGroup = req.body.bloodGroup;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ message: "No update fields provided" });
    }

    const updatedProfile = await HR.findOneAndUpdate(
      { user: hrUserId },
      updateData,
      { new: true, runValidators: true }
    ).populate("user", "email role");

    if (!updatedProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    res.status(200).json({
      message: "HR profile updated successfully",
      profile: updatedProfile,
    });
  } catch (err) {
    console.error("Error updating HR profile:", err);
    if (err.code === 11000) {
      return res.status(400).json({ message: "Email already exists" });
    }
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get all employees for HR management
 */
exports.getEmployees = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { page = 1, limit = 10, search = "" } = req.query;
    const skip = (page - 1) * limit;

    // Get HR profile to filter by subOrganisation
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // // console.log(`🔍 [DEBUG] HR subOrganisation: ${hrProfile.subOrganisation}`);

    // HR can see employees from both sub-organizations (Academic Overseas and SandSpace Technologies)
    let query = {
      subOrganisation: {
        $in: ["Academic Overseas", "SandSpace Technologies Pvt Ltd."],
      },
    };

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { employeeId: { $regex: search, $options: "i" } },
      ];
    }

    const employees = await Employee.find(query)
      .populate("user", "email role")
      .select("-__v")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Employee.countDocuments(query);

    res.status(200).json({
      employees,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("Error getting employees:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Create new employee (HR can only create employees)
 */
exports.createEmployee = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const {
      name,
      email,
      password,
      subOrganisation,
      employeeId,
      jobTitle,
      phone,
      bloodGroup,
    } = req.body;

    if (!name || !email || !password || !employeeId || !jobTitle) {
      return res.status(400).json({
        message:
          "Missing required fields: name, email, password, employeeId, and jobTitle are required",
      });
    }

    // Get HR profile to use their subOrganisation if not provided
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // HR users can create employees in either sub-organisation
    // Use the provided subOrganisation or default to HR's own if not provided
    const finalSubOrganisation = subOrganisation || hrProfile.subOrganisation;

    // Check if employee ID already exists
    const existingEmployee = await Employee.findOne({ employeeId });
    if (existingEmployee) {
      return res.status(409).json({ message: "Employee ID already exists" });
    }

    // Check if HR with same employeeId exists
    const existingHr = await HR.findOne({ employeeId });
    if (existingHr) {
      return res.status(409).json({ message: "Employee ID already exists" });
    }

    // Check if email already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ message: "Email already exists" });
    }

    // Create user account
    const newUser = new User({
      email,
      password,
      role: "employee",
    });
    await newUser.save();

    // Create employee profile
    const newEmployee = new Employee({
      user: newUser._id,
      name,
      email,
      subOrganisation: finalSubOrganisation,
      employeeId,
      jobTitle,
      phone: phone || "",
      bloodGroup: bloodGroup || "",
    });
    await newEmployee.save();

    res.status(201).json({
      message: "Employee created successfully",
      employee: newEmployee,
    });
  } catch (err) {
    console.error("Error creating employee:", err);
    if (err.code === 11000) {
      return res
        .status(400)
        .json({ message: "Email or Employee ID already exists" });
    }
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update employee
 */
exports.updateEmployee = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { employeeId } = req.params;
    const { name, email, phone, jobTitle, subOrganisation, bloodGroup } =
      req.body;

    // Verify HR has access to this employee
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Check if employee belongs to HR's subOrganisation
    if (employee.subOrganisation !== hrProfile.subOrganisation) {
      return res.status(403).json({
        message: "You can only update employees in your sub-organisation",
      });
    }

    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;
    if (jobTitle) updateData.jobTitle = jobTitle;
    if (subOrganisation) updateData.subOrganisation = subOrganisation;
    if (email) updateData.email = email;
    if (bloodGroup) updateData.bloodGroup = bloodGroup;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ message: "No update fields provided" });
    }

    // Update employee profile
    const updatedEmployee = await Employee.findByIdAndUpdate(
      employeeId,
      updateData,
      { new: true, runValidators: true }
    ).populate("user", "email role");

    // Update email in user account if provided
    if (email && employee.user) {
      await User.findByIdAndUpdate(employee.user, { email });
    }

    res.status(200).json({
      message: "Employee updated successfully",
      employee: updatedEmployee,
    });
  } catch (err) {
    console.error("Error updating employee:", err);
    if (err.code === 11000) {
      return res.status(400).json({ message: "Email already exists" });
    }
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Delete employee
 */
exports.deleteEmployee = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { employeeId } = req.params;

    // Verify HR has access to this employee
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Check if employee belongs to HR's subOrganisation
    if (employee.subOrganisation !== hrProfile.subOrganisation) {
      return res.status(403).json({
        message: "You can only delete employees in your sub-organisation",
      });
    }

    // Delete associated payroll records
    await Payroll.deleteMany({ employee: employeeId });

    // Delete employee profile
    await Employee.findByIdAndDelete(employeeId);

    // Delete user account
    if (employee.user) {
      await User.findByIdAndDelete(employee.user);
    }

    res.status(200).json({ message: "Employee deleted successfully" });
  } catch (err) {
    console.error("Error deleting employee:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get employees for messaging
 */
exports.getEmployeesForMessaging = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { search = "", page = 1, limit = 100 } = req.query;
    const skip = (page - 1) * limit;

    // Get HR profile to filter by subOrganisation
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    let query = {
      subOrganisation: {
        $in: ["Academic Overseas", "SandSpace Technologies Pvt Ltd."],
      },
    };

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { employeeId: { $regex: search, $options: "i" } },
      ];
    }

    const employees = await Employee.find(query)
      .select("name email employeeId phone jobTitle subOrganisation")
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Employee.countDocuments(query);

    res.status(200).json({
      employees,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    console.error("Error getting employees for messaging:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get admin users for messaging
 */
exports.getAdminsForMessaging = async (req, res) => {
  try {
    const { search = "", page = 1, limit = 100 } = req.query;
    const skip = (page - 1) * limit;

    // Build aggregation pipeline
    let matchStage = {};
    if (search) {
      matchStage = {
        $or: [
          { fullName: { $regex: search, $options: "i" } },
          { "user.email": { $regex: search, $options: "i" } },
        ],
      };
    }

    const pipeline = [
      { $match: matchStage },
      {
        $lookup: {
          from: "users",
          localField: "user",
          foreignField: "_id",
          as: "user",
        },
      },
      { $unwind: "$user" },
      {
        $project: {
          fullName: 1,
          designation: 1,
          mobileNumber: 1,
          profileImage: 1,
          email: "$user.email",
        },
      },
      { $sort: { fullName: 1 } },
      { $skip: skip },
      { $limit: parseInt(limit) },
    ];

    const admins = await Admin.aggregate(pipeline);
    const total = await Admin.countDocuments(matchStage);

    res.status(200).json({
      admins,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    console.error("Error getting admins for messaging:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Send message to employee (HR to Employee)
 */
exports.sendMessageToEmployee = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const hrUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find the employee
    const employee = await Employee.findById(recipientId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Create deterministic conversationId
    const conversationId = `Employee:${employee._id}|HR:${hrProfile._id}`;

    // Create message
    const message = new Message({
      conversationId,
      sender: {
        userId: hrProfile._id,
        userType: "HR",
        name: hrProfile.name,
        email: hrProfile.email,
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

    // Build standardized payload and notify via WebSocket events
    const messageData = {
      messageId: message._id,
      conversationId,
      sender: message.sender,
      content: message.content,
      messageType: message.messageType,
      createdAt: message.createdAt,
    };

    // Notify the receiver (employee)
    if (employee.user) {
      websocketService.broadcastToUser(
        employee.user.toString(),
        WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
        {
          ...messageData,
          message: "You have received a new message",
        }
      );
    }

    // Notify the sender (HR) confirmation
    if (hrProfile.user) {
      websocketService.broadcastToUser(
        hrProfile.user.toString(),
        WEBSOCKET_EVENTS.MESSAGE_SENT,
        {
          ...messageData,
          message: "Your message has been sent successfully",
        }
      );
    }

    res.status(201).json({
      message: "Message sent successfully",
      data: message,
    });
  } catch (err) {
    console.error("Error sending message to employee:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Send message to admin (HR to Admin)
 */
exports.sendMessageToAdmin = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const hrUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find the admin
    const admin = await Admin.findById(recipientId);
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Create deterministic conversationId
    const conversationId = `Admin:${admin._id}|HR:${hrProfile._id}`;

    // Create message
    const message = new Message({
      conversationId,
      sender: {
        userId: hrProfile._id,
        userType: "HR",
        name: hrProfile.name,
        email: hrProfile.email,
      },
      receiver: admin._id,
      receiverModel: "Admin",
      content,
      messageType: "text",
      priority: priority || "normal",
      isApproved: true,
      isRead: false,
    });

    await message.save();

    // Build standardized payload and notify via WebSocket events
    const messageData = {
      messageId: message._id,
      conversationId,
      sender: message.sender,
      content: message.content,
      messageType: message.messageType,
      createdAt: message.createdAt,
    };

    // Notify the receiver (admin)
    if (admin.user) {
      websocketService.broadcastToUser(
        admin.user.toString(),
        WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
        {
          ...messageData,
          message: "You have received a new message",
        }
      );
    }

    // Notify the sender (HR) confirmation
    if (hrProfile.user) {
      websocketService.broadcastToUser(
        hrProfile.user.toString(),
        WEBSOCKET_EVENTS.MESSAGE_SENT,
        {
          ...messageData,
          message: "Your message has been sent successfully",
        }
      );
    }

    res.status(201).json({
      message: "Message sent successfully",
      data: message,
    });
  } catch (err) {
    console.error("Error sending message to admin:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get HR messages (inbox)
 */
exports.getHRMessages = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const hrProfileId = hrProfile._id;

    const messages = await Message.find({
      $or: [
        { sender: hrProfileId, senderModel: "HR" },
        { receiver: hrProfileId, receiverModel: "HR" },
      ],
      isArchived: false,
      isApproved: true,
    })
      .populate("sender", "name email fullName")
      .populate("receiver", "name email fullName employeeId")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Message.countDocuments({
      $or: [
        { sender: hrProfileId, senderModel: "HR" },
        { receiver: hrProfileId, receiverModel: "HR" },
      ],
      isArchived: false,
      isApproved: true,
    });

    res.status(200).json({
      messages,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("Error getting HR messages:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get conversation with specific user
 */
exports.getConversation = async (req, res) => {
  try {
    const { userId, userType } = req.params;
    const hrUserId = req.userId;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const hrProfileId = hrProfile._id;

    // Determine conversationId based on userType
    let conversationId;
    const lowerType = userType.toLowerCase();

    if (lowerType === "employee") {
      // HR to Employee conversation
      conversationId = `Employee:${userId}|HR:${hrProfileId}`;
    } else if (lowerType === "admin") {
      // HR to Admin conversation
      conversationId = `Admin:${userId}|HR:${hrProfileId}`;
    } else {
      return res.status(400).json({ message: "Invalid userType" });
    }

    console.log(`[HR] Fetching conversation: ${conversationId}`);

    // Get conversation using conversationId
    const conversation = await Message.find({ conversationId })
      .sort({ createdAt: 1 })
      .lean();

    console.log(`[HR] Found ${conversation.length} messages`);

    res.status(200).json({
      conversation,
      total: conversation.length,
    });
  } catch (err) {
    console.error("Error getting conversation:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Mark message as read
 */
exports.markAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;
    const hrUserId = req.userId;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    // Check if HR is the receiver
    if (
      message.receiver.toString() !== hrProfile._id.toString() ||
      message.receiverModel !== "HR"
    ) {
      return res.status(403).json({
        message: "Unauthorized to mark this message as read",
      });
    }

    message.isRead = true;
    message.readAt = new Date();
    await message.save();

    res.status(200).json({
      message: "Message marked as read",
      data: message,
    });
  } catch (err) {
    console.error("Error marking message as read:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Create announcement (HR can create announcements)
 */
exports.createAnnouncement = async (req, res) => {
  try {
    const { title, message, audience, priority } = req.body;
    const hrUserId = req.userId;

    if (!title || !message) {
      return res.status(400).json({
        message: "Title and message are required",
      });
    }

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    const announcement = new Announcement({
      title,
      message,
      audience: audience || "employees",
      priority: priority || "normal",
      createdBy: hrProfile._id,
      createdByModel: "HR",
      isActive: true,
    });

    await announcement.save();

    // Populate based on the model type
    if (announcement.createdByModel === "HR") {
      await announcement.populate({
        path: "createdBy",
        model: "HR",
        select: "fullName email",
      });
    } else if (announcement.createdByModel === "Admin") {
      await announcement.populate({
        path: "createdBy",
        model: "Admin",
        select: "fullName designation",
      });
    }

    // Emit WebSocket event for real-time notification
    const announcementData = {
      id: announcement._id.toString(),
      title: announcement.title,
      message: announcement.message,
      priority: announcement.priority,
      audience: announcement.audience,
      createdBy: {
        _id: announcement.createdBy._id.toString(),
        fullName:
          announcement.createdBy.fullName || announcement.createdBy.name,
        email: announcement.createdBy.email,
      },
      createdAt: announcement.createdAt.toISOString(),
    };

    // Determine target audience and send notifications
    if (announcement.audience === "all") {
      // Notify all users via company_wide room
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );

      // Also emit notification_sent event for better notification handling
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.NOTIFICATION_SENT,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );
    } else {
      // Notify specific audience (employees, hr, admin)
      const targetRoom =
        announcement.audience === "employees"
          ? WEBSOCKET_ROOMS.EMPLOYEE_ROOM
          : announcement.audience === "hr"
          ? WEBSOCKET_ROOMS.HR_ROOM
          : WEBSOCKET_ROOMS.ADMIN_ROOM;

      websocketService.broadcastToRoom(
        targetRoom,
        WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );

      // Also emit notification_sent event for better notification handling
      websocketService.broadcastToRoom(
        targetRoom,
        WEBSOCKET_EVENTS.NOTIFICATION_SENT,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );
    }

    res.status(201).json({
      message: "Announcement created successfully",
      announcement,
    });
  } catch (err) {
    console.error("Error creating announcement:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get announcements
 */
exports.getAnnouncements = async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (page - 1) * limit;

    const query = {
      isActive: true,
      audience: { $in: ["all", "employees", "hr"] },
    };

    if (req.query.onlyMine === "true") {
      const hrUserId = req.userId;
      const hrProfile = await HR.findOne({ user: hrUserId });
      if (hrProfile) {
        query.createdBy = hrProfile._id;
      }
    }

    const announcements = await Announcement.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Populate based on model type
    for (const announcement of announcements) {
      try {
        if (announcement.createdByModel === "Admin") {
          await announcement.populate({
            path: "createdBy",
            model: "Admin",
            select: "fullName designation",
          });
        } else if (announcement.createdByModel === "HR") {
          await announcement.populate({
            path: "createdBy",
            model: "HR",
            select: "fullName email",
          });
        } else {
          // Fallback for announcements without createdByModel (legacy data)
          await announcement.populate({
            path: "createdBy",
            select: "fullName designation email",
          });
        }
      } catch (populateError) {
        console.error("Error populating announcement:", populateError);
        // Continue with other announcements even if one fails
      }
    }

    const total = await Announcement.countDocuments(query);

    res.status(200).json({
      announcements,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("Error getting announcements:", err);
    res.status(500).json({ message: err.message });
  }
};

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadPath = path.join(__dirname, "../../uploads/profiles");
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(
      null,
      `profile-${req.userId}-${uniqueSuffix}${path.extname(file.originalname)}`
    );
  },
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase()
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files are allowed"));
    }
  },
});

// Upload profile image
exports.uploadProfileImage = [
  upload.single("profileImage"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: "No image file provided" });
      }

      const hrUserId = req.userId;
      const hrProfile = await HR.findOne({ user: hrUserId });

      if (!hrProfile) {
        return res.status(404).json({ message: "HR profile not found" });
      }

      // Delete old profile picture if it exists
      if (hrProfile.profilePic) {
        const oldImagePath = path.join(
          __dirname,
          "../../",
          hrProfile.profilePic.startsWith("/")
            ? hrProfile.profilePic.slice(1)
            : hrProfile.profilePic
        );

        if (fs.existsSync(oldImagePath)) {
          try {
            fs.unlinkSync(oldImagePath);
          } catch (delErr) {
            console.error("Error deleting old HR profile image:", delErr);
          }
        }
      }

      // Update profile picture path
      const imageUrl = `/uploads/profiles/${req.file.filename}`;
      hrProfile.profilePic = imageUrl;
      await hrProfile.save();

      res.status(200).json({
        message: "Profile image uploaded successfully",
        imageUrl: imageUrl,
      });
    } catch (err) {
      console.error("Error uploading profile image:", err);
      res.status(500).json({ message: err.message });
    }
  },
];

/**
 * @description Get employees for messaging (HR side)
 */
exports.getEmployeesForMessaging = async (req, res) => {
  try {
    const { search = "", page = 1, limit = 100 } = req.query;
    const skip = (page - 1) * limit;

    let query = {};
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { employeeId: { $regex: search, $options: "i" } },
      ];
    }

    const employees = await Employee.find(query)
      .select("name email phone employeeId profilePic")
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Employee.countDocuments(query);

    // Debug logging for employee contacts

    res.status(200).json({
      employees,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    console.error("Error getting employees for messaging:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get admins for messaging (HR side)
 */
exports.getAdminsForMessaging = async (req, res) => {
  try {
    const { search = "", page = 1, limit = 100 } = req.query;
    const skip = (page - 1) * limit;

    // Build aggregation pipeline
    let matchStage = {};
    if (search) {
      matchStage = {
        $or: [
          { fullName: { $regex: search, $options: "i" } },
          { "user.email": { $regex: search, $options: "i" } },
        ],
      };
    }

    const pipeline = [
      { $match: matchStage },
      {
        $lookup: {
          from: "users",
          localField: "user",
          foreignField: "_id",
          as: "user",
        },
      },
      { $unwind: "$user" },
      {
        $project: {
          fullName: 1,
          designation: 1,
          mobileNumber: 1,
          profileImage: 1,
          email: "$user.email",
        },
      },
      { $sort: { fullName: 1 } },
      { $skip: skip },
      { $limit: parseInt(limit) },
    ];

    const admins = await Admin.aggregate(pipeline);
    const total = await Admin.countDocuments(matchStage);

    // Debug logging for Admin contacts

    res.status(200).json({
      admins,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    console.error("Error getting admins for messaging:", err);
    res.status(500).json({ message: err.message });
  }
};
