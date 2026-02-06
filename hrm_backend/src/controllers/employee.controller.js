const User = require("../models/user.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Admin = require("../models/admin.model");
const Payroll = require("../models/payroll.model");
const PayslipRequest = require("../models/payslipRequest.model");
const Announcement = require("../models/announcement.model");
const Message = require("../models/message.model");
const EOD = require("../models/eod.model");
const mongoose = require("mongoose");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const websocketService = require("../services/websocket.service");
const { WEBSOCKET_EVENTS } = require("../constants/websocket.events");
const payrollService = require("../services/payroll.service");
const logger = require("../core/logger");

// Import LeaveRequest if it exists, otherwise handle gracefully
let LeaveRequest;
try {
  LeaveRequest = require("../models/leaveRequest.model");
} catch (err) {
  LeaveRequest = null;
}

/**
 * @description Get employee dashboard summary
 */
exports.getEmployeeDashboardSummary = async (req, res) => {
  try {
    const employeeUserId = req.userId;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    const employeeProfileId = employeeProfile._id;
    const unreadSenderIds = await Message.find({
      receiver: employeeProfileId,
      receiverModel: "Employee",
      isRead: false,
      isApproved: true,
    }).distinct("sender.userId");

    const unreadMessages = await Message.countDocuments({
      receiver: employeeProfileId,
      receiverModel: "Employee",
      isRead: false,
      isApproved: true,
    });

    // Get leave balance - calculate effective balance (DB balance - pending requests)
    let leaveBalance = 0;
    if (LeaveRequest) {
      // Count pending casual leaves (all time, or properly scoped if needed)
      // We subtract pending leaves because they are not yet deducted from the DB balance
      const pendingCasualLeaves = await LeaveRequest.countDocuments({
        employee: employeeProfileId,
        leaveType: "casual",
        status: "pending",
      });

      // Get total casual leaves available (from employee profile DB - which is already decremented for approved leaves)
      const currentDbBalance = employeeProfile.leaveBalance?.casualLeave || 0;

      // Calculate remaining balance
      leaveBalance = Math.max(0, currentDbBalance - pendingCasualLeaves);
    } else if (employeeProfile.leaveBalance?.casualLeave) {
      // Fallback to profile data if LeaveRequest model not available
      leaveBalance = employeeProfile.leaveBalance.casualLeave;
    }

    // Get pending leave requests count (all pending)
    let pendingLeaves = 0;
    if (LeaveRequest) {
      // Count all pending leave requests
      pendingLeaves = await LeaveRequest.countDocuments({
        employee: employeeProfileId,
        status: "pending",
      });
    }

    // Get pending EOD count - check if employee has submitted EOD for today
    let pendingEOD = 0;
    try {
      // Use the same date logic as EOD controller for consistency
      const moment = require("moment-timezone");
      const currentIST = moment().tz("Asia/Kolkata");
      const todayDateString = currentIST.format("YYYY-MM-DD");

      const todayEOD = await EOD.findOne({
        employee: employeeProfileId,
        date: {
          $gte: new Date(todayDateString + "T00:00:00.000Z"),
          $lt: new Date(todayDateString + "T23:59:59.999Z"),
        },
      });

      // If no EOD found for today, it's pending
      pendingEOD = todayEOD ? 0 : 1;
    } catch (eodError) {
      logger.error("Error checking pending EOD", {
        error: eodError.message,
        stack: eodError.stack,
        employeeId: employeeProfileId,
      });
      pendingEOD = 0;
    }

    // Calculate date 5 days ago
    const fiveDaysAgo = new Date();
    fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);

    // Get announcements from the last 5 days for employees
    const recentAnnouncements = await Announcement.find({
      audience: { $in: ["all", "employees"] },
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
          let populated = false;

          // Try Admin first
          try {
            const admin = await Admin.findById(announcement.createdBy)
              .select("fullName designation")
              .lean();
            if (admin) {
              announcement.createdBy = admin;
              populated = true;
            }
          } catch (adminError) {
            // Continue to next attempt
          }

          // Try HR if Admin didn't work
          if (!populated) {
            try {
              const hr = await HR.findById(announcement.createdBy)
                .select("name email")
                .lean();
              if (hr) {
                announcement.createdBy = hr;
                populated = true;
              }
            } catch (hrError) {
              // Continue to next attempt
            }
          }

          // Try Admin by user field if still not populated
          if (!populated) {
            try {
              const adminByUser = await Admin.findOne({
                user: announcement.createdBy,
              })
                .select("fullName designation")
                .lean();
              if (adminByUser) {
                announcement.createdBy = adminByUser;
                populated = true;
              }
            } catch (adminByUserError) {
              // Continue to next attempt
            }
          }

          // Try HR by user field as last resort
          if (!populated) {
            try {
              const hrByUser = await HR.findOne({
                user: announcement.createdBy,
              })
                .select("name email")
                .lean();
              if (hrByUser) {
                announcement.createdBy = hrByUser;
                populated = true;
              }
            } catch (hrByUserError) {
              // Continue silently
            }
          }
        }
      } catch (populateError) {
        logger.error("Error populating announcement creator", {
          error: populateError.message,
          stack: populateError.stack,
          announcementId: announcement._id,
        });
      }
    }

    res.status(200).json({
      pendingEOD,
      leaveBalance,
      pendingLeaves,
      unreadMessages,
      unreadSenderIds,
      eodWarningCount: employeeProfile.eodWarningCount || 0,
      payCutFlag: employeeProfile.payCutFlag || false,
      recentAnnouncements,
    });
  } catch (err) {
    logger.error("Error getting employee dashboard summary", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get employee profile
 */
exports.getEmployeeProfile = async (req, res) => {
  try {
    const employeeUserId = req.userId;

    const employeeProfile = await Employee.findOne({
      user: employeeUserId,
    }).populate("user", "email role");

    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    res.status(200).json(employeeProfile);
  } catch (err) {
    logger.error("Error getting employee profile", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update employee profile
 */
exports.updateEmployeeProfile = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { name, phone } = req.body;

    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;
    if (req.body.bloodGroup) updateData.bloodGroup = req.body.bloodGroup;

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ message: "No update fields provided" });
    }

    const updatedProfile = await Employee.findOneAndUpdate(
      { user: employeeUserId },
      updateData,
      { new: true, runValidators: true },
    ).populate("user", "email role");

    if (!updatedProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    res.status(200).json({
      message: "Profile updated successfully",
      profile: updatedProfile,
    });
  } catch (err) {
    logger.error("Error updating employee profile", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Apply for leave
 */
exports.applyForLeave = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { leaveType, startDate, endDate, reason } = req.body;

    if (!leaveType || !startDate || !endDate || !reason) {
      return res.status(400).json({
        message:
          "Missing required fields: leaveType, startDate, endDate, and reason are required",
      });
    }

    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    if (!LeaveRequest) {
      return res.status(400).json({
        message: "Leave request system not available",
      });
    }

    const leaveRequest = new LeaveRequest({
      employee: employeeProfile._id,
      leaveType,
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      reason,
      status: "pending",
      submittedDate: new Date(),
    });

    await leaveRequest.save();

    res.status(201).json({
      message: "Leave request submitted successfully",
      leaveRequest,
    });
  } catch (err) {
    logger.error("Error applying for leave", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get leave requests for employee
 */
exports.getLeaveRequests = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    if (!LeaveRequest) {
      return res.status(200).json({
        leaveRequests: [],
        total: 0,
        page: parseInt(page),
        limit: parseInt(limit),
      });
    }

    const leaveRequests = await LeaveRequest.find({
      employee: employeeProfile._id,
    })
      .sort({ submittedDate: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
    });

    res.status(200).json({
      leaveRequests,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting leave requests", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get payslips for employee
 */
exports.getPayslips = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { year, month, page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Build query for payslips
    let query = { employee: employeeProfile._id };
    if (year) query.year = parseInt(year);
    if (month) query.month = month;

    // Fetch payslips with healing
    const rawPayslips = await Payroll.find(query)
      .sort({ year: -1, month: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const payslips = rawPayslips.map((p) => {
      const payslip = p.toObject();
      if (!payslip.calculatedFields) return payslip;

      const basic = payslip.calculatedFields.basicPay || 0;
      if (basic > 0) {
        // ALWAYS Heal missing or zero components
        // We use loose equality check for safety (null/undefined/0)
        let needsRecalculation = false;

        if (
          !payslip.calculatedFields.hra ||
          payslip.calculatedFields.hra == 0
        ) {
          payslip.calculatedFields.hra = Math.round(basic * 0.575);
          needsRecalculation = true;
        }
        if (
          !payslip.calculatedFields.conveyance ||
          payslip.calculatedFields.conveyance == 0
        ) {
          payslip.calculatedFields.conveyance = Math.round(basic * 0.275);
          needsRecalculation = true;
        }
        if (
          !payslip.calculatedFields.specialAllowance ||
          payslip.calculatedFields.specialAllowance == 0
        ) {
          payslip.calculatedFields.specialAllowance = Math.round(basic * 0.15);
          needsRecalculation = true;
        }

        // Check if Total Pay matches sum of components (Healing Stale Totals)
        const currentTotal = payslip.totalPay || 0;
        const gross =
          (payslip.calculatedFields.basicPay || 0) +
          (payslip.calculatedFields.hra || 0) +
          (payslip.calculatedFields.conveyance || 0) +
          (payslip.calculatedFields.specialAllowance || 0);

        const deductions =
          (payslip.deductions?.pf || 0) +
          (payslip.deductions?.esi || 0) +
          (payslip.deductions?.pt || 0) +
          (payslip.deductions?.lopAmount || 0) +
          (payslip.deductions?.penalty || 0);

        const calculatedTotal = gross + (payslip.bonus || 0) - deductions;

        if (
          needsRecalculation ||
          Math.abs(currentTotal - calculatedTotal) > 1
        ) {
          payslip.totalPay = calculatedTotal;
          payslip.calculatedFields.netSalary = calculatedTotal;
          payslip.calculatedFields.grossSalary = gross;
        }
      }
      return payslip;
    });

    const total = await Payroll.countDocuments(query);

    res.status(200).json({
      payslips,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting payslips", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get salary breakdown preview based on attendance
 */
exports.getSalaryBreakdownPreview = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { month, year } = req.query;

    if (!month || !year) {
      return res.status(400).json({ message: "Month and Year are required" });
    }

    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // 1. Get Base Pay from latest Payroll or PayslipRequest
    let basePay = 0;

    // Try Payroll first
    const latestPayroll = await Payroll.findOne({
      employee: employeeProfile._id,
    }).sort({ year: -1, month: -1 });

    if (latestPayroll && latestPayroll.totalPay) {
      basePay = latestPayroll.totalPay;
    }

    // Fallback to PayslipRequest if needed
    if (!basePay) {
      const latestRequest = await PayslipRequest.findOne({
        employee: employeeProfile._id,
        status: "approved",
      }).sort({ endYear: -1, endMonth: -1 });
      if (latestRequest && latestRequest.basePay) {
        basePay = latestRequest.basePay;
      }
    }

    if (!basePay) {
      return res.status(200).json({
        hasData: false,
        message: "No salary history found",
      });
    }

    // 2. Check if attendance exists for this month
    const hasAttendance = await payrollService.hasAttendanceRecords(
      employeeUserId,
      month,
      year,
    );

    if (!hasAttendance) {
      return res.status(200).json({
        hasData: false,
        message: "No data found try another month",
      });
    }

    // 3. Calculate Penalty
    /* DYNAMIC PENALTY COMMENTED OUT
    const penalty = await payrollService.calculateDynamicPenalty(
      employeeUserId,
      month,
      year,
      basePay
    );
    */
    const penalty = 0;

    // 4. Calculate Components
    // Check if manual payroll info exists
    let components = {};
    let deductions = {};

    if (
      employeeProfile.payrollInfo &&
      employeeProfile.payrollInfo.basicPay > 0
    ) {
      // Use manual info
      const basicPay = employeeProfile.payrollInfo.basicPay;
      components = {
        basicPay: basicPay,
        hra: employeeProfile.payrollInfo.hra || Math.round(basicPay * 0.575),
        conveyance:
          employeeProfile.payrollInfo.conveyance ||
          Math.round(basicPay * 0.275),
        specialAllowance:
          employeeProfile.payrollInfo.specialAllowance ||
          Math.round(basicPay * 0.15),
      };

      deductions = {
        pt: employeeProfile.payrollInfo.pt || 0,
        pf: employeeProfile.payrollInfo.pf || 0,
        esi: employeeProfile.payrollInfo.esi || 0,
      };
    } else {
      // Fallback/Dynamic
      components = payrollService.calculateSalaryComponents(basePay);
      const standardDeductions = payrollService.calculateDeductions();
      deductions = {
        pt: standardDeductions.pt,
        pf: standardDeductions.pf,
        esi: standardDeductions.esi,
      };
    }

    // 6. Calculate LOP Days
    const lopDays = await payrollService.calculateLOPDays(
      employeeUserId,
      month,
      year,
    );

    // 7. Calculate Net (Simplified Preview)
    // Note: Deduct LOP amount?
    // Usually LOP Amount = (BasePay / DaysInMonth) * lopDays.
    // For now, let's assuming BasePay is already "Gross".
    // If we need to subtract LOP amount:
    const daysInMonth = new Date(
      year,
      new Date(`${month} 1, ${year}`).getMonth() + 1,
      0,
    ).getDate();
    // Use manual basic pay logic or total base pay?
    // Usually LOP is on GROSS.

    // Recalculate BasePay if manual info is used (sum of components)
    let currentBasePay = basePay;
    if (
      employeeProfile.payrollInfo &&
      employeeProfile.payrollInfo.basicPay > 0
    ) {
      currentBasePay =
        (components.basicPay || 0) +
        (components.hra || 0) +
        (components.conveyance || 0) +
        (components.specialAllowance || 0);
    } else {
      // Also sum components for dynamic calculation to stay consistent
      currentBasePay =
        (components.basicPay || 0) +
        (components.hra || 0) +
        (components.conveyance || 0) +
        (components.specialAllowance || 0);
    }

    const salaryPerDay = currentBasePay / daysInMonth;
    const lopDeduction = Math.round(salaryPerDay * lopDays);

    const netSalary =
      currentBasePay -
      penalty -
      deductions.pt -
      deductions.pf -
      deductions.esi -
      lopDeduction;

    res.status(200).json({
      hasData: true,
      basicPay: components.basicPay,
      hra: components.hra,
      conveyance: components.conveyance,
      specialAllowance: components.specialAllowance,
      penalty: penalty,
      pt: deductions.pt,
      pf: deductions.pf,
      esi: deductions.esi,
      lopDays: lopDays,
      lopAmount: lopDeduction,
      netSalary: Math.max(0, netSalary), // Ensure non-negative
      isPreview: true,
      message: "This is a preview based on attendance",
    });
  } catch (err) {
    logger.error("Error getting salary preview", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get HR contacts for messaging
 */
exports.getHRContacts = async (req, res) => {
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

    const hrContacts = await HR.find(query)
      .select("name email phone employeeId subOrganisation profilePic")
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await HR.countDocuments(query);

    // Debug logging for HR contacts

    res.status(200).json({
      hrContacts,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    logger.error("Error getting HR contacts", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

exports.getAdminContacts = async (req, res) => {
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

    const adminContacts = await Admin.aggregate(pipeline);
    const total = await Admin.countDocuments(matchStage);

    res.status(200).json({
      adminContacts,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    logger.error("Error getting admin contacts", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get employee contacts for messaging (peer list)
 */
exports.getEmployeeContactsForMessaging = async (req, res) => {
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

    // Exclude self from contacts
    const currentEmployee = await Employee.findOne({ user: req.userId }).select(
      "_id",
    );
    if (currentEmployee) {
      query._id = { $ne: currentEmployee._id };
    }

    const employees = await Employee.find(query)
      .select(
        "name email phone employeeId subOrganisation profilePic user jobTitle",
      )
      .sort({ name: 1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Employee.countDocuments(query);

    const employeeContacts = employees.map((e) => ({
      _id: e._id,
      name: e.name,
      email: e.email,
      phone: e.phone,
      employeeId: e.employeeId,
      subOrganisation: e.subOrganisation,
      profilePic: e.profilePic,
      user: e.user, // include base user id for presence mapping
      jobTitle: e.jobTitle,
    }));

    res.status(200).json({
      employeeContacts,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    logger.error("Error getting employee contacts", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Mark all notifications as read (update clear time)
 */
exports.markNotificationsAsRead = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { clearTime } = req.body; // Optional: accept client time, or use server time

    const clearTimestamp = clearTime ? new Date(clearTime) : new Date();

    const employeeProfile = await Employee.findOneAndUpdate(
      { user: employeeUserId },
      { lastNotificationClearTime: clearTimestamp },
      { new: true },
    );

    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    res.status(200).json({
      message: "Notifications marked as read",
      lastNotificationClearTime: employeeProfile.lastNotificationClearTime,
    });
  } catch (err) {
    logger.error("Error marking notifications as read", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Send message to HR (Employee to HR - no approval needed)
 */
exports.sendMessageToHR = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const employeeUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Load employee profile and email
    const employeeProfile = await Employee.findOne({
      user: employeeUserId,
    }).populate("user", "email");
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Load HR
    const hr = await HR.findById(recipientId);
    if (!hr) {
      return res.status(404).json({ message: "HR not found" });
    }

    // Deterministic conversation id (basic, no encryption)
    const conversationId = `Employee:${employeeProfile._id}|HR:${hr._id}`;

    // Create message aligned to Message schema
    const message = new Message({
      conversationId,
      sender: {
        userId: employeeProfile._id,
        userType: "Employee",
        name: employeeProfile.name,
        email: employeeProfile.user?.email || "",
      },
      receiver: hr._id,
      receiverModel: "HR",
      content,
      messageType: "text",
      priority: priority || "normal",
      requiresApproval: false,
      isApproved: true,
    });

    await message.save();

    // Emit basic websocket event
    websocketService.broadcastToUser(
      hr.user.toString(),
      WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
      {
        messageId: message._id.toString(),
        conversationId,
        sender: {
          _id: employeeProfile._id.toString(),
          userId: employeeProfile._id.toString(),
          userType: "Employee",
          name: employeeProfile.name,
          email: employeeProfile.user?.email,
        },
        receiver: {
          _id: hr._id.toString(),
          userId: hr._id.toString(),
          userType: "HR",
          name: hr.name,
          email: hr.email,
        },
        content: message.content,
        messageType: message.messageType,
        priority: message.priority,
        createdAt: message.createdAt.toISOString(),
      },
    );

    websocketService.broadcastToUser(
      employeeUserId.toString(),
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        messageId: message._id.toString(),
        conversationId,
        content: message.content,
        createdAt: message.createdAt.toISOString(),
      },
    );

    res
      .status(201)
      .json({ message: "Message sent successfully", data: message });
  } catch (err) {
    logger.error("Error sending message to HR", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Send message to Admin (Employee to Admin - requires approval)
 */
exports.sendMessageToAdmin = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const employeeUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Find employee profile and email
    const employeeProfile = await Employee.findOne({
      user: employeeUserId,
    }).populate("user", "email");
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Find admin
    const admin = await Admin.findById(recipientId);
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }
    // Deterministic conversation id
    const conversationId = `Employee:${employeeProfile._id}|Admin:${admin._id}`;

    // Create message (admin approval still tracked via isApproved)
    const message = new Message({
      conversationId,
      sender: {
        userId: employeeProfile._id,
        userType: "Employee",
        name: employeeProfile.name,
        email: employeeProfile.user?.email || "",
      },
      receiver: admin._id,
      receiverModel: "Admin",
      content,
      messageType: "text",
      priority: priority || "normal",
      requiresApproval: true,
      isApproved: false,
    });

    await message.save();

    websocketService.broadcastToUser(
      admin.user.toString(),
      WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
      {
        messageId: message._id.toString(),
        conversationId,
        sender: {
          _id: employeeProfile._id.toString(),
          userId: employeeProfile._id.toString(),
          userType: "Employee",
          name: employeeProfile.name,
          email: employeeProfile.user?.email,
        },
        receiver: {
          _id: admin._id.toString(),
          userId: admin._id.toString(),
          userType: "Admin",
          fullName: admin.fullName,
          email: admin.email,
        },
        content: message.content,
        messageType: message.messageType,
        priority: message.priority,
        isApproved: message.isApproved,
        createdAt: message.createdAt.toISOString(),
      },
    );

    websocketService.broadcastToUser(
      employeeUserId.toString(),
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        messageId: message._id.toString(),
        conversationId,
        content: message.content,
        createdAt: message.createdAt.toISOString(),
      },
    );

    res.status(201).json({
      message: "Message sent successfully",
      data: message,
      requiresApproval: true,
    });
  } catch (err) {
    logger.error("Error sending message to admin", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Send message to another Employee (peer messaging)
 */
exports.sendMessageToEmployee = async (req, res) => {
  try {
    const { recipientId, subject, content, priority } = req.body;
    const employeeUserId = req.userId;

    if (!recipientId || !subject || !content) {
      return res.status(400).json({
        message:
          "Missing required fields: recipientId, subject, and content are required",
      });
    }

    // Find sender employee profile and email
    const employeeProfile = await Employee.findOne({
      user: employeeUserId,
    }).populate("user", "email");
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Find recipient employee profile
    const targetEmployee = await Employee.findById(recipientId).populate(
      "user",
      "email",
    );
    if (!targetEmployee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Deterministic, order-independent conversation id for employee-to-employee
    const a = employeeProfile._id.toString();
    const b = targetEmployee._id.toString();
    const conversationId =
      a < b ? `Employee:${a}|Employee:${b}` : `Employee:${b}|Employee:${a}`;

    const message = new Message({
      conversationId,
      sender: {
        userId: employeeProfile._id,
        userType: "Employee",
        name: employeeProfile.name,
        email: employeeProfile.user?.email || "",
      },
      receiver: targetEmployee._id,
      receiverModel: "Employee",
      content,
      messageType: "text",
      priority: priority || "normal",
      requiresApproval: false,
      isApproved: true,
    });

    await message.save();

    // Notify recipient and sender
    websocketService.broadcastToUser(
      targetEmployee.user.toString(),
      WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
      {
        messageId: message._id.toString(),
        conversationId,
        sender: {
          _id: employeeProfile._id.toString(),
          userId: employeeProfile._id.toString(),
          userType: "Employee",
          name: employeeProfile.name,
          email: employeeProfile.user?.email,
        },
        receiver: {
          _id: targetEmployee._id.toString(),
          userId: targetEmployee._id.toString(),
          userType: "Employee",
          name: targetEmployee.name,
          email: targetEmployee.user?.email,
        },
        content: message.content,
        messageType: message.messageType,
        priority: message.priority,
        createdAt: message.createdAt.toISOString(),
      },
    );

    websocketService.broadcastToUser(
      employeeUserId.toString(),
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        messageId: message._id.toString(),
        conversationId,
        content: message.content,
        createdAt: message.createdAt.toISOString(),
      },
    );

    res
      .status(201)
      .json({ message: "Message sent successfully", data: message });
  } catch (err) {
    logger.error("Error sending message to employee", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get employee messages (inbox)
 */
exports.getEmployeeMessages = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    const employeeProfileId = employeeProfile._id;

    // Get messages where employee is sender or receiver
    // Include messages regardless of approval status so employee can see their sent messages
    const messages = await Message.find({
      $or: [
        { sender: employeeProfileId, senderModel: "Employee" },
        {
          receiver: employeeProfileId,
          receiverModel: "Employee",
          isApproved: true,
        }, // Only show received messages if approved
      ],
      isArchived: false,
    })
      .populate("sender", "name email fullName employeeId")
      .populate("receiver", "name email fullName employeeId")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Message.countDocuments({
      $or: [
        { sender: employeeProfileId, senderModel: "Employee" },
        {
          receiver: employeeProfileId,
          receiverModel: "Employee",
          isApproved: true,
        },
      ],
      isArchived: false,
    });

    res.status(200).json({
      messages,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting employee messages", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get conversation with specific user
 */
exports.getConversation = async (req, res) => {
  try {
    const { userId, userType } = req.params;
    const employeeUserId = req.userId;

    // Employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Determine logic to match sender/receiver directly
    // This is more robust than conversationId string matching
    let targetProfileId = userId;
    let targetModel = "Admin"; // Default

    const lowerType = userType.toLowerCase();

    if (lowerType === "hr") {
      targetModel = "HR";
      // Robustness: Check if this is a valid HR profile ID. If not, maybe it's a User ID.
      if (mongoose.Types.ObjectId.isValid(userId)) {
        const possibleHr = await HR.findById(userId).select("_id");
        if (!possibleHr) {
          const possibleHrByUser = await HR.findOne({ user: userId }).select(
            "_id",
          );
          if (possibleHrByUser) {
            targetProfileId = possibleHrByUser._id.toString();
          }
        }
      }
    } else if (lowerType === "employee") {
      targetModel = "Employee";
      // Resolve peer as profile _id or base user id
      try {
        const peerById = await Employee.findById(userId).select("_id");
        if (!peerById) {
          const peerByUser = await Employee.findOne({ user: userId }).select(
            "_id",
          );
          if (peerByUser) {
            targetProfileId = peerByUser._id.toString();
          }
        }
      } catch (_) {}
    } else {
      targetModel = "Admin";
      if (mongoose.Types.ObjectId.isValid(userId)) {
        const possibleAdmin = await Admin.findById(userId).select("_id");
        if (!possibleAdmin) {
          const possibleAdminByUser = await Admin.findOne({
            user: userId,
          }).select("_id");
          if (possibleAdminByUser) {
            targetProfileId = possibleAdminByUser._id.toString(); // Use consistent variable
          }
        }
      }
    }

    const conversation = await Message.find({
      $or: [
        {
          "sender.userId": employeeProfile._id,
          "sender.userType": "Employee",
          receiver: targetProfileId,
          receiverModel: targetModel,
        },
        {
          "sender.userId": targetProfileId,
          "sender.userType": targetModel,
          receiver: employeeProfile._id,
          receiverModel: "Employee",
        },
      ],
      isArchived: false,
    })
      .sort({ createdAt: 1 })
      .lean();

    res.status(200).json({ conversation, total: conversation.length });
  } catch (err) {
    logger.error("Error getting conversation", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Mark message as read
 */
exports.markMessageAsRead = async (req, res) => {
  try {
    const { messageId } = req.params;
    const employeeUserId = req.userId;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    // Check if employee is the receiver
    if (
      message.receiver.toString() !== employeeProfile._id.toString() ||
      message.receiverModel !== "Employee"
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
    logger.error("Error marking message as read", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Mark conversation as seen (all messages in conversation)
 */
exports.markConversationAsSeen = async (req, res) => {
  try {
    const { userId, userType } = req.params;
    const employeeUserId = req.userId;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    const employeeProfileId = employeeProfile._id;

    // Normalize userType
    let normalizedUserType = userType;
    if (userType.toLowerCase() === "admin") {
      normalizedUserType = "Admin";
    } else if (userType.toLowerCase() === "hr") {
      normalizedUserType = "HR";
    }

    // Mark all unread messages in this conversation as seen
    const result = await Message.updateMany(
      {
        "sender.userId": userId,
        "sender.userType": normalizedUserType,
        receiver: employeeProfileId,
        receiverModel: "Employee",
        isRead: false,
        isApproved: true,
      },
      { isRead: true, readAt: new Date() },
    );

    res.status(200).json({
      message: "Conversation marked as seen",
      updatedCount: result.modifiedCount,
    });
  } catch (err) {
    logger.error("Error marking conversation as seen", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get announcements for employees
 */
exports.getAnnouncements = async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const skip = (page - 1) * limit;

    const announcements = await Announcement.find({
      isActive: true,
      audience: { $in: ["all", "employees"] },
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Populate based on model type using the same robust logic as dashboard summary
    for (const announcement of announcements) {
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
          let populated = false;

          // Try Admin first
          try {
            const admin = await Admin.findById(announcement.createdBy)
              .select("fullName designation")
              .lean();
            if (admin) {
              announcement.createdBy = admin;
              populated = true;
            }
          } catch (adminError) {
            // Continue to next attempt
          }

          // Try HR if Admin didn't work
          if (!populated) {
            try {
              const hr = await HR.findById(announcement.createdBy)
                .select("name email")
                .lean();
              if (hr) {
                announcement.createdBy = hr;
                populated = true;
              }
            } catch (hrError) {
              // Continue to next attempt
            }
          }

          // Try Admin by user field if still not populated
          if (!populated) {
            try {
              const adminByUser = await Admin.findOne({
                user: announcement.createdBy,
              })
                .select("fullName designation")
                .lean();
              if (adminByUser) {
                announcement.createdBy = adminByUser;
                populated = true;
              }
            } catch (adminByUserError) {
              // Continue to next attempt
            }
          }

          // Try HR by user field as last resort
          if (!populated) {
            try {
              const hrByUser = await HR.findOne({
                user: announcement.createdBy,
              })
                .select("name email")
                .lean();
              if (hrByUser) {
                announcement.createdBy = hrByUser;
                populated = true;
              }
            } catch (hrByUserError) {
              // Continue silently
            }
          }
        }
      } catch (populateError) {
        logger.error("Error populating announcement creator", {
          error: populateError.message,
          stack: populateError.stack,
          announcementId: announcement._id,
        });
      }
    }

    const total = await Announcement.countDocuments({
      isActive: true,
      audience: { $in: ["all", "employees"] },
    });

    res.status(200).json({
      announcements,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting announcements", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
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
    const filename = `profile-${req.userId}-${uniqueSuffix}${path.extname(
      file.originalname,
    )}`;
    cb(null, filename);
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
      path.extname(file.originalname).toLowerCase(),
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files are allowed"));
    }
  },
});

/**
 * @description Upload profile image
 */
/**
 * @description Upload profile image
 */
exports.uploadProfileImage = [
  upload.single("profileImage"),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: "No image file provided" });
      }

      const employeeUserId = req.userId;
      const employeeProfile = await Employee.findOne({ user: employeeUserId });

      if (!employeeProfile) {
        // Delete the uploaded file if employee not found
        fs.unlinkSync(req.file.path);
        return res.status(404).json({ message: "Employee profile not found" });
      }

      // Delete old profile picture if it exists
      if (employeeProfile.profilePic) {
        const oldImagePath = path.join(
          __dirname,
          "../../",
          employeeProfile.profilePic.startsWith("/")
            ? employeeProfile.profilePic.slice(1)
            : employeeProfile.profilePic,
        );

        // Check if file exists before attempting to delete
        if (fs.existsSync(oldImagePath)) {
          try {
            fs.unlinkSync(oldImagePath);
          } catch (deleteError) {
            logger.error("Error deleting old profile image", {
              error: deleteError.message,
              stack: deleteError.stack,
              path: oldImagePath,
            });
          }
        }
      }

      // Update profile picture path
      const imageUrl = `/uploads/profiles/${req.file.filename}`;
      employeeProfile.profilePic = imageUrl;
      await employeeProfile.save();

      res.status(200).json({
        message: "Profile image uploaded successfully",
        imageUrl: imageUrl,
      });
    } catch (err) {
      logger.error("Error uploading profile image", {
        error: err.message,
        stack: err.stack,
        userId: req.userId,
      });

      // Clean up uploaded file on error
      if (req.file && req.file.path) {
        try {
          fs.unlinkSync(req.file.path);
        } catch (cleanupError) {
          logger.error("Error cleaning up file", {
            error: cleanupError.message,
            stack: cleanupError.stack,
            path: req.file.path,
          });
        }
      }

      res.status(500).json({ message: err.message });
    }
  },
];
