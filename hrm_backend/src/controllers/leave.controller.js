const LeaveRequest = require("../models/leaveRequest.model");
const Employee = require("../models/employee.model");
const BlackoutDate = require("../models/blackoutDate.model");
const websocketService = require("../services/websocket.service");
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const moment = require("moment-timezone");

// Helper function to get IST date
const getISTDate = (date = null) => {
  if (date) {
    return moment(date).tz("Asia/Kolkata").toDate();
  }
  return moment().tz("Asia/Kolkata").toDate();
};

// Helper function to check if date is a blackout date
const isBlackoutDate = async (startDate, endDate) => {
  const blackoutDates = await BlackoutDate.find({
    isActive: true,
    $or: [
      {
        startDate: { $lte: endDate },
        endDate: { $gte: startDate },
      },
    ],
  });

  return blackoutDates.length > 0 ? blackoutDates : null;
};

// Helper function to calculate working days between two dates
const calculateWorkingDays = (startDate, endDate) => {
  let count = 0;
  const start = moment(startDate);
  const end = moment(endDate);

  while (start <= end) {
    const dayOfWeek = start.day();
    // Exclude Sundays (0) - modify based on your company's working days
    if (dayOfWeek !== 0) {
      count++;
    }
    start.add(1, "day");
  }
  return count;
};

// Configure multer for medical certificate uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadPath = path.join(
      __dirname,
      "../../uploads/medical-certificates"
    );
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(
      null,
      `medical-cert-${req.userId}-${uniqueSuffix}${path.extname(
        file.originalname
      )}`
    );
  },
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase()
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files (JPEG, JPG, PNG) are allowed"));
    }
  },
});

/**
 * @description Apply for leave (Employee)
 */
exports.applyLeave = [
  upload.single("medicalCertificate"),
  async (req, res) => {
    try {
      const employeeUserId = req.userId;
      const {
        leaveType,
        durationType,
        startDate,
        endDate,
        halfDayPeriod,
        permissionHours,
        permissionStartTime,
        permissionEndTime,
        reason,
      } = req.body;

      // Validate required fields
      if (!leaveType || !durationType || !startDate || !endDate || !reason) {
        return res.status(400).json({
          message:
            "Missing required fields: leaveType, durationType, startDate, endDate, and reason are required",
        });
      }

      // Find employee profile
      const employeeProfile = await Employee.findOne({ user: employeeUserId });
      if (!employeeProfile) {
        return res.status(404).json({ message: "Employee profile not found" });
      }

      // Parse dates
      const start = new Date(startDate);
      const end = new Date(endDate);
      const today = getISTDate();

      // Validate date range
      if (end < start) {
        return res.status(400).json({
          message: "End date cannot be before start date",
        });
      }

      // Check 2-day advance notice requirement (except for half_day and hours)
      if (durationType === "full_day") {
        const daysDifference = Math.ceil(
          (start - today) / (1000 * 60 * 60 * 24)
        );
        if (daysDifference < 2) {
          return res.status(400).json({
            message:
              "Full day leaves must be applied at least 2 days in advance",
          });
        }
      }

      // Check blackout dates
      const blackoutConflict = await isBlackoutDate(start, end);
      if (blackoutConflict) {
        return res.status(400).json({
          message: `Leave cannot be applied during blackout period: ${blackoutConflict[0].reason}`,
          blackoutDates: blackoutConflict,
        });
      }

      // Validate permission hours
      if (durationType === "hours") {
        if (!permissionHours || permissionHours <= 0 || permissionHours > 8) {
          return res.status(400).json({
            message: "Permission hours must be between 0 and 8",
          });
        }

        // Check available permission hours
        if (employeeProfile.leaveBalance.permissionHours < permissionHours) {
          return res.status(400).json({
            message: `Insufficient permission hours. Available: ${employeeProfile.leaveBalance.permissionHours} hours`,
          });
        }
      }

      // Validate half day
      if (durationType === "half_day") {
        if (
          !halfDayPeriod ||
          !["first_half", "second_half"].includes(halfDayPeriod)
        ) {
          return res.status(400).json({
            message: "Half day period must be 'first_half' or 'second_half'",
          });
        }
      }

      // Check leave balance for casual and WFH
      // Helper to calculate required balance for this request
      let requiredBalance = 0;
      if (durationType === "full_day") requiredBalance = 1;
      else if (durationType === "half_day") requiredBalance = 0.5;

      // Check leave balance for casual and WFH
      // We must account for pending leaves that haven't been deducted from DB yet
      if (leaveType === "casual") {
        const currentBalance = employeeProfile.leaveBalance?.casualLeave ?? 0;

        // Count pending casual leaves
        const pendingRequests = await LeaveRequest.find({
          employee: employeeUserId,
          leaveType: "casual",
          status: "pending",
        });

        let pendingDeduction = 0;
        for (const req of pendingRequests) {
          if (req.durationType === "full_day") pendingDeduction += 1;
          else if (req.durationType === "half_day") pendingDeduction += 0.5;
        }

        const availableBalance = currentBalance - pendingDeduction;

        if (availableBalance < requiredBalance) {
          return res.status(400).json({
            message: `Insufficient casual leave balance. Available: ${availableBalance} days`,
          });
        }
      } else if (leaveType === "work_from_home") {
        const currentBalance = employeeProfile.leaveBalance?.workFromHome ?? 0;

        // Count pending WFH leaves
        const pendingRequests = await LeaveRequest.find({
          employee: employeeUserId,
          leaveType: "work_from_home",
          status: "pending",
        });

        let pendingDeduction = 0;
        for (const req of pendingRequests) {
          if (req.durationType === "full_day") pendingDeduction += 1;
          else if (req.durationType === "half_day") pendingDeduction += 0.5;
        }

        const availableBalance = currentBalance - pendingDeduction;

        if (availableBalance < requiredBalance) {
          return res.status(400).json({
            message: `Insufficient work from home balance. Available: ${availableBalance} days`,
          });
        }
      }

      // Calculate total days for the leave request
      let totalDays = 0;
      if (durationType === "full_day") {
        // For full day: endDate - startDate (employee takes leave on start date, returns on end date)
        // For 8th to 8th: employee takes leave on 8th, returns on 8th = 1 day (same day)
        // For 8th to 9th: employee takes leave on 8th, returns on 9th = 1 day
        const difference = Math.ceil((end - start) / (1000 * 60 * 60 * 24));
        totalDays = Math.max(1, difference); // Ensure at least 1 day for same-day leaves
      } else if (durationType === "half_day") {
        totalDays = 0.5;
      } else if (durationType === "hours") {
        // Convert hours to day fraction (8 hours = 1 day)
        totalDays = permissionHours / 8;
      }

      // Calculate if leave duration exceeds 7 days
      const leaveDays = calculateWorkingDays(start, end);
      const requiresBothApprovals = leaveDays > 7;

      // Determine if leave is paid (only 1 casual leave per month is paid)
      const isPaid =
        leaveType === "casual" && employeeProfile.leaveBalance.casualLeave > 0;

      // Create leave request
      const leaveRequest = new LeaveRequest({
        employee: employeeProfile._id,
        leaveType,
        durationType,
        startDate: start,
        endDate: end,
        halfDayPeriod: durationType === "half_day" ? halfDayPeriod : null,
        permissionHours: durationType === "hours" ? permissionHours : null,
        permissionStartTime:
          durationType === "hours" ? permissionStartTime : null,
        permissionEndTime: durationType === "hours" ? permissionEndTime : null,
        reason,
        medicalCertificate: req.file
          ? `/uploads/medical-certificates/${req.file.filename}`
          : null,
        status: "pending",
        requiresBothApprovals,
        isPaid,
        totalDays,
        submittedDate: today,
      });

      await leaveRequest.save();

      // Populate employee data for WebSocket notification
      const populatedLeaveRequest = await LeaveRequest.findById(
        leaveRequest._id
      ).populate("employee", "name email employeeId user");

      // Notify HR and Admin via WebSocket
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.HR_ROOM,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_CREATED,
        {
          leaveRequest: populatedLeaveRequest,
          message: "New leave request has been submitted",
          employeeName: populatedLeaveRequest.employee.name,
          leaveType: populatedLeaveRequest.leaveType,
          startDate: populatedLeaveRequest.startDate,
          endDate: populatedLeaveRequest.endDate,
        }
      );

      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.ADMIN_ROOM,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_CREATED,
        {
          leaveRequest: populatedLeaveRequest,
          message: "New leave request has been submitted",
          employeeName: populatedLeaveRequest.employee.name,
          leaveType: populatedLeaveRequest.leaveType,
          startDate: populatedLeaveRequest.startDate,
          endDate: populatedLeaveRequest.endDate,
        }
      );

      // --- Start Notification Logic ---
      try {
        const notificationService = require("../services/notification.service");
        const User = require("../models/user.model");

        // Find all Admin and HR users with tokens
        const approvers = await User.find({
          role: { $in: ["admin", "hr"] },
          fcmToken: { $ne: null, $exists: true }
        }).select("fcmToken");

        const tokens = approvers.map(u => u.fcmToken).filter(t => t);

        if (tokens.length > 0) {
          await notificationService.sendMulticastNotification(
            tokens,
            "New Leave Request",
            `${populatedLeaveRequest.employee.name} requested ${populatedLeaveRequest.leaveType} leave`,
            {
              type: "leave_request_admin", // different type for admin routing if needed
              id: leaveRequest._id.toString()
            }
          );
        }
      } catch (notifErr) {
        console.error("Failed to send new leave request notification:", notifErr);
      }
      // --- End Notification Logic ---

      res.status(201).json({
        message: "Leave request submitted successfully",
        leaveRequest,
      });
    } catch (err) {
      console.error("Error applying for leave:", err);

      // Clean up uploaded file on error
      if (req.file && req.file.path) {
        try {
          fs.unlinkSync(req.file.path);
        } catch (cleanupError) {
          console.error("Error cleaning up file:", cleanupError);
        }
      }

      res.status(500).json({ message: err.message });
    }
  },
];

/**
 * @description Get employee's leave requests
 */
exports.getMyLeaveRequests = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const {
      page = 1,
      limit = 20,
      status,
      leaveType,
      startDate,
      endDate,
    } = req.query;
    const skip = (page - 1) * limit;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Build query
    let query = { employee: employeeProfile._id };

    if (status) {
      query.status = status;
    }

    if (leaveType) {
      query.leaveType = leaveType;
    }

    if (startDate || endDate) {
      query.startDate = {};
      if (startDate) {
        query.startDate.$gte = new Date(startDate);
      }
      if (endDate) {
        query.startDate.$lte = new Date(endDate);
      }
    }

    // Fetch leave requests
    const leaveRequests = await LeaveRequest.find(query)
      .populate("hrApproval.approvedBy", "name email")
      .populate("adminApproval.approvedBy", "fullName email")
      .sort({ submittedDate: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await LeaveRequest.countDocuments(query);

    res.status(200).json({
      leaveRequests,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    console.error("Error getting leave requests:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get leave balance
 */
exports.getLeaveBalance = async (req, res) => {
  try {
    const employeeUserId = req.userId;

    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    const employeeProfileId = employeeProfile._id;

    // Helper function to get pending leave count
    const getPendingLeaveCount = async (employeeId, leaveType) => {
      // Count all pending leaves regardless of date
      // (since balance is global/running, any pending request blocks that balance)
      const query = {
        employee: employeeId,
        leaveType: leaveType,
        status: "pending",
      };

      const requests = await LeaveRequest.find(query);

      let deduction = 0;
      for (const req of requests) {
        if (req.durationType === "full_day") deduction += 1;
        else if (req.durationType === "half_day") deduction += 0.5;
        else if (req.durationType === "hours")
          deduction += (req.permissionHours || 0) / 8; // normalize to days
      }
      return deduction;
    };

    // Calculate pending deductions
    const pendingCasual = await getPendingLeaveCount(
      employeeProfileId,
      "casual"
    );
    const pendingWFH = await getPendingLeaveCount(
      employeeProfileId,
      "work_from_home"
    );

    // For permission hours, we handle them separately
    const pendingPermissionHours =
      (
        await LeaveRequest.aggregate([
          {
            $match: {
              employee: employeeProfileId,
              leaveType: "permission",
              status: "pending",
            },
          },
          {
            $group: {
              _id: null,
              totalHours: { $sum: "$permissionHours" },
            },
          },
        ])
      )[0]?.totalHours || 0;

    // Calculate remaining balances
    // Use ?? to handle 0 correctly (0 || 1 is 1, which was the bug)
    // Only subtract PENDING requests, because APPROVED requests are already deducted from the DB field
    const currentCasualBalance = employeeProfile.leaveBalance?.casualLeave ?? 0;
    const currentWFHBalance = employeeProfile.leaveBalance?.workFromHome ?? 0;
    const currentPermissionBalance =
      employeeProfile.leaveBalance?.permissionHours ?? 0;

    const remainingCasualLeaves = Math.max(
      0,
      currentCasualBalance - pendingCasual
    );
    const remainingWFHLeaves = Math.max(0, currentWFHBalance - pendingWFH);
    const remainingPermissionHours = Math.max(
      0,
      currentPermissionBalance - pendingPermissionHours
    );

    res.status(200).json({
      leaveBalance: {
        casualLeave: remainingCasualLeaves,
        workFromHome: remainingWFHLeaves,
        permissionHours: remainingPermissionHours,
      },
      leaveHistory: employeeProfile.leaveHistory,
    });
  } catch (err) {
    console.error("Error getting leave balance:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Cancel leave request (Employee - before approval only)
 */
exports.cancelLeaveRequest = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { leaveRequestId } = req.params;
    const { cancellationReason } = req.body;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Find leave request
    const leaveRequest = await LeaveRequest.findById(leaveRequestId);
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Verify ownership
    if (leaveRequest.employee.toString() !== employeeProfile._id.toString()) {
      return res.status(403).json({
        message: "Unauthorized to cancel this leave request",
      });
    }

    // Check if leave is still pending
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: `Cannot cancel leave request with status: ${leaveRequest.status}. Only pending requests can be cancelled by employees.`,
      });
    }

    // Cancel leave request
    leaveRequest.status = "cancelled";
    leaveRequest.cancelledBy = "employee";
    leaveRequest.cancelledAt = getISTDate();
    leaveRequest.cancellationReason =
      cancellationReason || "Cancelled by employee";

    await leaveRequest.save();

    res.status(200).json({
      message: "Leave request cancelled successfully",
      leaveRequest,
    });
  } catch (err) {
    console.error("Error cancelling leave request:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get blackout dates
 */
exports.getBlackoutDates = async (req, res) => {
  try {
    const { year, month } = req.query;

    let query = { isActive: true };

    // Filter by year and month if provided
    if (year || month) {
      const startDate = moment
        .tz("Asia/Kolkata")
        .year(year || moment().year())
        .month(month ? parseInt(month) - 1 : 0)
        .startOf("month")
        .toDate();

      const endDate = moment
        .tz("Asia/Kolkata")
        .year(year || moment().year())
        .month(month ? parseInt(month) - 1 : 11)
        .endOf("month")
        .toDate();

      query.$or = [
        {
          startDate: { $lte: endDate },
          endDate: { $gte: startDate },
        },
      ];
    }

    const blackoutDates = await BlackoutDate.find(query)
      .populate("createdBy", "name email fullName")
      .sort({ startDate: 1 });

    res.status(200).json({
      blackoutDates,
      total: blackoutDates.length,
    });
  } catch (err) {
    console.error("Error getting blackout dates:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get leave statistics
 */
exports.getLeaveStatistics = async (req, res) => {
  try {
    const employeeUserId = req.userId;

    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Get current month's leave requests
    const currentMonthStart = moment()
      .tz("Asia/Kolkata")
      .startOf("month")
      .toDate();
    const currentMonthEnd = moment().tz("Asia/Kolkata").endOf("month").toDate();

    const currentMonthLeaves = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
      startDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
      status: { $in: ["approved", "pending"] },
    });

    // Get pending leave requests count for current month
    const pendingLeaves = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
      status: "pending",
      submittedDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
    });

    // Get approved leave requests count
    const approvedLeaves = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
      status: "approved",
    });

    // Get rejected leave requests count
    const rejectedLeaves = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
      status: "rejected",
    });

    // Calculate remaining leave balance for current month (reuse existing variables)

    // Calculate used casual leaves for current month
    const usedCasualLeaves = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
      leaveType: "casual",
      status: { $in: ["approved", "pending"] },
      startDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
    });

    // Calculate used WFH leaves for current month
    const usedWFHLeaves = await LeaveRequest.countDocuments({
      employee: employeeProfile._id,
      leaveType: "work_from_home",
      status: { $in: ["approved", "pending"] },
      startDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
    });

    // Calculate used permission hours for current month
    const usedPermissionHours = await LeaveRequest.aggregate([
      {
        $match: {
          employee: employeeProfile._id,
          leaveType: "permission",
          status: { $in: ["approved", "pending"] },
          startDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
        },
      },
      {
        $group: {
          _id: null,
          totalHours: { $sum: "$permissionHours" },
        },
      },
    ]);

    const totalUsedPermissionHours =
      usedPermissionHours.length > 0 ? usedPermissionHours[0].totalHours : 0;

    // Calculate remaining balances
    const totalCasualLeaves = employeeProfile.leaveBalance?.casualLeave || 1;
    const totalWFHLeaves = employeeProfile.leaveBalance?.workFromHome || 1;
    const totalPermissionHours =
      employeeProfile.leaveBalance?.permissionHours || 3;

    // Calculate remaining balances - CORRECT LOGIC
    // Only subtract PENDING requests, because APPROVED requests are already deducted from the DB field

    // Helper to calculate pending deduction (copied from getLeaveBalance logic)
    const getPendingDeduction = async (type) => {
      const pendingReqs = await LeaveRequest.find({
        employee: employeeProfile._id,
        leaveType: type,
        status: "pending"
      });
      let deduction = 0;
      for (const req of pendingReqs) {
        if (req.durationType === "full_day") deduction += 1;
        else if (req.durationType === "half_day") deduction += 0.5;
      }
      return deduction;
    };

    const pendingCasualDeduction = await getPendingDeduction("casual");
    const pendingWFHDeduction = await getPendingDeduction("work_from_home");

    // For permission hours
    const pendingPermissionDeduction = (await LeaveRequest.aggregate([
      {
        $match: {
          employee: employeeProfile._id,
          leaveType: "permission",
          status: "pending"
        }
      },
      { $group: { _id: null, total: { $sum: "$permissionHours" } } }
    ]))[0]?.total || 0;


    const remainingCasualLeaves = Math.max(
      0,
      totalCasualLeaves - pendingCasualDeduction
    );
    const remainingWFHLeaves = Math.max(0, totalWFHLeaves - pendingWFHDeduction);
    const remainingPermissionHours = Math.max(
      0,
      totalPermissionHours - pendingPermissionDeduction
    );

    res.status(200).json({
      leaveBalance: {
        casualLeave: remainingCasualLeaves,
        workFromHome: remainingWFHLeaves,
        permissionHours: remainingPermissionHours,
      },
      leaveHistory: employeeProfile.leaveHistory,
      currentMonthLeaves,
      pendingLeaves,
      approvedLeaves,
      rejectedLeaves,
    });
  } catch (err) {
    console.error("Error getting leave statistics:", err);
    res.status(500).json({ message: err.message });
  }
};
