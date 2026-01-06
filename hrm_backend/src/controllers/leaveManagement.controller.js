const LeaveRequest = require("../models/leaveRequest.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Admin = require("../models/admin.model");
const BlackoutDate = require("../models/blackoutDate.model");
const moment = require("moment-timezone");

// Helper function to get IST date
const getISTDate = (date = null) => {
  if (date) {
    return moment(date).tz("Asia/Kolkata").toDate();
  }
  return moment().tz("Asia/Kolkata").toDate();
};

// Helper to reset monthly leave balances
const resetMonthlyLeaveBalances = async (employeeId) => {
  const employee = await Employee.findById(employeeId);
  if (!employee) return;

  const lastReset = moment(employee.leaveHistory.lastResetDate);
  const now = moment().tz("Asia/Kolkata");

  // Check if a month has passed
  if (now.diff(lastReset, "months") >= 1) {
    // Reset WFH and permission hours (don't touch casual leave - it carries over)
    employee.leaveBalance.workFromHome = 1;
    employee.leaveBalance.permissionHours = 3;

    // Add 2 casual leaves for the new month (carries over)
    employee.leaveBalance.casualLeave += 2;

    employee.leaveHistory.lastResetDate = now.toDate();
    await employee.save();
  }
};

// Helper to deduct leave balance
const deductLeaveBalance = async (leaveRequest) => {
  const employee = await Employee.findById(leaveRequest.employee);
  if (!employee) return;

  const { leaveType, durationType, permissionHours } = leaveRequest;

  if (leaveType === "casual") {
    if (employee.leaveBalance.casualLeave > 0) {
      employee.leaveBalance.casualLeave -= 1;
      employee.leaveHistory.totalCasualLeavesUsed += 1;
    }
  } else if (leaveType === "work_from_home") {
    if (employee.leaveBalance.workFromHome > 0) {
      employee.leaveBalance.workFromHome -= 1;
      employee.leaveHistory.totalWFHUsed += 1;
    }
  } else if (leaveType === "permission" && durationType === "hours") {
    if (employee.leaveBalance.permissionHours >= permissionHours) {
      employee.leaveBalance.permissionHours -= permissionHours;
      employee.leaveHistory.totalPermissionHoursUsed += permissionHours;
    }
  } else if (leaveType === "sick") {
    employee.leaveHistory.totalSickLeavesUsed += 1;
  }

  await employee.save();
};

// Helper to refund leave balance (when cancelled)
const refundLeaveBalance = async (leaveRequest) => {
  const employee = await Employee.findById(leaveRequest.employee);
  if (!employee) return;

  const { leaveType, durationType, permissionHours } = leaveRequest;

  if (leaveType === "casual") {
    employee.leaveBalance.casualLeave += 1;
    employee.leaveHistory.totalCasualLeavesUsed = Math.max(
      0,
      employee.leaveHistory.totalCasualLeavesUsed - 1
    );
  } else if (leaveType === "work_from_home") {
    employee.leaveBalance.workFromHome += 1;
    employee.leaveHistory.totalWFHUsed = Math.max(
      0,
      employee.leaveHistory.totalWFHUsed - 1
    );
  } else if (leaveType === "permission" && durationType === "hours") {
    employee.leaveBalance.permissionHours += permissionHours;
    employee.leaveHistory.totalPermissionHoursUsed = Math.max(
      0,
      employee.leaveHistory.totalPermissionHoursUsed - permissionHours
    );
  } else if (leaveType === "sick") {
    employee.leaveHistory.totalSickLeavesUsed = Math.max(
      0,
      employee.leaveHistory.totalSickLeavesUsed - 1
    );
  }

  await employee.save();
};

/**
 * @description Get all leave requests (HR/Admin)
 */
exports.getAllLeaveRequests = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      status,
      leaveType,
      employeeId,
      startDate,
      endDate,
    } = req.query;
    const skip = (page - 1) * limit;

    // Build query
    let query = {};

    if (status) {
      query.status = status;
    }

    if (leaveType) {
      query.leaveType = leaveType;
    }

    if (employeeId) {
      query.employee = employeeId;
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
      .populate("employee", "name email employeeId jobTitle subOrganisation")
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
 * @description Approve leave request (HR)
 */
exports.approveLeaveRequestHR = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { leaveRequestId } = req.params;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find leave request
    const leaveRequest = await LeaveRequest.findById(leaveRequestId).populate(
      "employee",
      "name email employeeId"
    );
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Check if already approved or rejected
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: `Leave request is already ${leaveRequest.status}`,
      });
    }

    // Update HR approval
    leaveRequest.hrApproval = {
      status: "approved",
      approvedBy: hrProfile._id,
      approvedAt: getISTDate(),
      rejectionReason: null,
    };

    // Check if both approvals are required
    if (leaveRequest.requiresBothApprovals) {
      // Need admin approval too
      if (
        !leaveRequest.adminApproval ||
        leaveRequest.adminApproval.status !== "approved"
      ) {
        leaveRequest.status = "pending"; // Still pending admin approval
        await leaveRequest.save();

        return res.status(200).json({
          message: "HR approval granted. Awaiting admin approval.",
          leaveRequest,
        });
      } else {
        // Both approved
        leaveRequest.status = "approved";
      }
    } else {
      // Only HR approval needed
      leaveRequest.status = "approved";
    }

    await leaveRequest.save();

    // Deduct leave balance
    await deductLeaveBalance(leaveRequest);

    // TODO: Send notification to employee

    res.status(200).json({
      message: "Leave request approved successfully",
      leaveRequest,
    });
  } catch (err) {
    console.error("Error approving leave request (HR):", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Reject leave request (HR)
 */
exports.rejectLeaveRequestHR = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { leaveRequestId } = req.params;
    const { rejectionReason } = req.body;

    if (!rejectionReason) {
      return res.status(400).json({
        message: "Rejection reason is required",
      });
    }

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find leave request
    const leaveRequest = await LeaveRequest.findById(leaveRequestId).populate(
      "employee",
      "name email employeeId"
    );
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Check if already approved or rejected
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: `Leave request is already ${leaveRequest.status}`,
      });
    }

    // Update HR approval
    leaveRequest.hrApproval = {
      status: "rejected",
      approvedBy: hrProfile._id,
      approvedAt: getISTDate(),
      rejectionReason,
    };

    leaveRequest.status = "rejected";
    await leaveRequest.save();

    // TODO: Send notification to employee

    res.status(200).json({
      message: "Leave request rejected",
      leaveRequest,
    });
  } catch (err) {
    console.error("Error rejecting leave request (HR):", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Approve leave request (Admin)
 */
exports.approveLeaveRequestAdmin = async (req, res) => {
  try {
    const adminUserId = req.userId;
    const { leaveRequestId } = req.params;

    // Find Admin profile
    const adminProfile = await Admin.findOne({ user: adminUserId });
    if (!adminProfile) {
      return res.status(404).json({ message: "Admin profile not found" });
    }

    // Find leave request
    const leaveRequest = await LeaveRequest.findById(leaveRequestId).populate(
      "employee",
      "name email employeeId"
    );
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Check if already approved or rejected
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: `Leave request is already ${leaveRequest.status}`,
      });
    }

    // Update Admin approval
    leaveRequest.adminApproval = {
      status: "approved",
      approvedBy: adminProfile._id,
      approvedAt: getISTDate(),
      rejectionReason: null,
    };

    // Check if both approvals are required
    if (leaveRequest.requiresBothApprovals) {
      // Need HR approval too
      if (
        !leaveRequest.hrApproval ||
        leaveRequest.hrApproval.status !== "approved"
      ) {
        leaveRequest.status = "pending"; // Still pending HR approval
        await leaveRequest.save();

        return res.status(200).json({
          message: "Admin approval granted. Awaiting HR approval.",
          leaveRequest,
        });
      } else {
        // Both approved
        leaveRequest.status = "approved";
      }
    } else {
      // Only Admin approval needed
      leaveRequest.status = "approved";
    }

    await leaveRequest.save();

    // Deduct leave balance
    await deductLeaveBalance(leaveRequest);

    // TODO: Send notification to employee

    res.status(200).json({
      message: "Leave request approved successfully",
      leaveRequest,
    });
  } catch (err) {
    console.error("Error approving leave request (Admin):", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Reject leave request (Admin)
 */
exports.rejectLeaveRequestAdmin = async (req, res) => {
  try {
    const adminUserId = req.userId;
    const { leaveRequestId } = req.params;
    const { rejectionReason } = req.body;

    if (!rejectionReason) {
      return res.status(400).json({
        message: "Rejection reason is required",
      });
    }

    // Find Admin profile
    const adminProfile = await Admin.findOne({ user: adminUserId });
    if (!adminProfile) {
      return res.status(404).json({ message: "Admin profile not found" });
    }

    // Find leave request
    const leaveRequest = await LeaveRequest.findById(leaveRequestId).populate(
      "employee",
      "name email employeeId"
    );
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Check if already approved or rejected
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: `Leave request is already ${leaveRequest.status}`,
      });
    }

    // Update Admin approval
    leaveRequest.adminApproval = {
      status: "rejected",
      approvedBy: adminProfile._id,
      approvedAt: getISTDate(),
      rejectionReason,
    };

    leaveRequest.status = "rejected";
    await leaveRequest.save();

    // TODO: Send notification to employee

    res.status(200).json({
      message: "Leave request rejected",
      leaveRequest,
    });
  } catch (err) {
    console.error("Error rejecting leave request (Admin):", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Cancel ongoing leave (HR/Admin only - after approval)
 */
exports.cancelOngoingLeave = async (req, res) => {
  try {
    const userId = req.userId;
    const userRole = req.userRole;
    const { leaveRequestId } = req.params;
    const { cancellationReason } = req.body;

    if (!cancellationReason) {
      return res.status(400).json({
        message: "Cancellation reason is required",
      });
    }

    // Find user profile based on role
    let userProfile;
    if (userRole === "hr") {
      userProfile = await HR.findOne({ user: userId });
    } else if (userRole === "admin") {
      userProfile = await Admin.findOne({ user: userId });
    }

    if (!userProfile) {
      return res.status(404).json({ message: "User profile not found" });
    }

    // Find leave request
    const leaveRequest = await LeaveRequest.findById(leaveRequestId);
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Check if leave is approved (can only cancel approved leaves)
    if (leaveRequest.status !== "approved") {
      return res.status(400).json({
        message: `Cannot cancel leave with status: ${leaveRequest.status}. Only approved leaves can be cancelled.`,
      });
    }

    // Cancel leave request
    leaveRequest.status = "cancelled";
    leaveRequest.cancelledBy = userRole;
    leaveRequest.cancelledAt = getISTDate();
    leaveRequest.cancellationReason = cancellationReason;

    await leaveRequest.save();

    // Refund leave balance
    await refundLeaveBalance(leaveRequest);

    // TODO: Send notification to employee

    res.status(200).json({
      message: "Leave cancelled successfully",
      leaveRequest,
    });
  } catch (err) {
    console.error("Error cancelling ongoing leave:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Create blackout date (HR/Admin)
 */
exports.createBlackoutDate = async (req, res) => {
  try {
    const userId = req.userId;
    const userRole = req.userRole;
    const { startDate, endDate, reason } = req.body;

    if (!startDate || !endDate || !reason) {
      return res.status(400).json({
        message:
          "Missing required fields: startDate, endDate, and reason are required",
      });
    }

    // Find user profile based on role
    let userProfile;
    let createdByModel;

    if (userRole === "hr") {
      userProfile = await HR.findOne({ user: userId });
      createdByModel = "HR";
    } else if (userRole === "admin") {
      userProfile = await Admin.findOne({ user: userId });
      createdByModel = "Admin";
    }

    if (!userProfile) {
      return res.status(404).json({ message: "User profile not found" });
    }

    // Validate dates
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (end < start) {
      return res.status(400).json({
        message: "End date cannot be before start date",
      });
    }

    // Create blackout date
    const blackoutDate = new BlackoutDate({
      startDate: start,
      endDate: end,
      reason,
      createdBy: userProfile._id,
      createdByModel,
      isActive: true,
    });

    await blackoutDate.save();

    res.status(201).json({
      message: "Blackout date created successfully",
      blackoutDate,
    });
  } catch (err) {
    console.error("Error creating blackout date:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update blackout date (HR/Admin)
 */
exports.updateBlackoutDate = async (req, res) => {
  try {
    const { blackoutDateId } = req.params;
    const { startDate, endDate, reason, isActive } = req.body;

    const blackoutDate = await BlackoutDate.findById(blackoutDateId);
    if (!blackoutDate) {
      return res.status(404).json({ message: "Blackout date not found" });
    }

    if (startDate) blackoutDate.startDate = new Date(startDate);
    if (endDate) blackoutDate.endDate = new Date(endDate);
    if (reason) blackoutDate.reason = reason;
    if (isActive !== undefined) blackoutDate.isActive = isActive;

    // Validate dates if both are being updated
    if (blackoutDate.endDate < blackoutDate.startDate) {
      return res.status(400).json({
        message: "End date cannot be before start date",
      });
    }

    await blackoutDate.save();

    res.status(200).json({
      message: "Blackout date updated successfully",
      blackoutDate,
    });
  } catch (err) {
    console.error("Error updating blackout date:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Delete blackout date (HR/Admin)
 */
exports.deleteBlackoutDate = async (req, res) => {
  try {
    const { blackoutDateId } = req.params;

    const blackoutDate = await BlackoutDate.findByIdAndDelete(blackoutDateId);
    if (!blackoutDate) {
      return res.status(404).json({ message: "Blackout date not found" });
    }

    res.status(200).json({
      message: "Blackout date deleted successfully",
    });
  } catch (err) {
    console.error("Error deleting blackout date:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get leave statistics for dashboard (HR/Admin)
 */
exports.getLeaveStatistics = async (req, res) => {
  try {
    // Total pending leave requests
    const pendingLeaves = await LeaveRequest.countDocuments({
      status: "pending",
    });

    // Total approved leaves this month
    const currentMonthStart = moment()
      .tz("Asia/Kolkata")
      .startOf("month")
      .toDate();
    const currentMonthEnd = moment().tz("Asia/Kolkata").endOf("month").toDate();

    const approvedThisMonth = await LeaveRequest.countDocuments({
      status: "approved",
      startDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
    });

    // Leave requests requiring both approvals
    const requiresBothApprovals = await LeaveRequest.countDocuments({
      requiresBothApprovals: true,
      status: "pending",
    });

    // Leaves by type
    const leavesByType = await LeaveRequest.aggregate([
      {
        $match: {
          status: "approved",
          startDate: { $gte: currentMonthStart, $lte: currentMonthEnd },
        },
      },
      {
        $group: {
          _id: "$leaveType",
          count: { $sum: 1 },
        },
      },
    ]);

    res.status(200).json({
      pendingLeaves,
      approvedThisMonth,
      requiresBothApprovals,
      leavesByType,
    });
  } catch (err) {
    console.error("Error getting leave statistics:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get employee leave summary (HR/Admin)
 */
exports.getEmployeeLeaveSummary = async (req, res) => {
  try {
    const { employeeId } = req.params;

    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Check and reset monthly balances if needed
    await resetMonthlyLeaveBalances(employeeId);

    // Get updated employee data
    const updatedEmployee = await Employee.findById(employeeId);

    // Get leave requests
    const leaveRequests = await LeaveRequest.find({
      employee: employeeId,
    })
      .sort({ submittedDate: -1 })
      .limit(10);

    res.status(200).json({
      employee: {
        name: updatedEmployee.name,
        email: updatedEmployee.email,
        employeeId: updatedEmployee.employeeId,
        leaveBalance: updatedEmployee.leaveBalance,
        leaveHistory: updatedEmployee.leaveHistory,
      },
      recentLeaveRequests: leaveRequests,
    });
  } catch (err) {
    console.error("Error getting employee leave summary:", err);
    res.status(500).json({ message: err.message });
  }
};
