const LeaveRequest = require("../models/leaveRequest.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const HR = require("../models/hr.model");
const websocketService = require("../services/websocket.service");
const attendanceService = require("../services/attendance.service"); // Import Service
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");

// Helper: Recalculate Attendance for Leave Duration
const recalculateAttendanceForLeave = async (leaveRequest) => {
  try {
    // Find User ID from Employee ID
    const employee = await Employee.findById(leaveRequest.employee);
    if (!employee || !employee.user) return;

    const userId = employee.user;
    const startDate = new Date(leaveRequest.startDate);
    const endDate = new Date(leaveRequest.endDate);

    // Iterate from start to end
    for (
      let d = new Date(startDate);
      d <= endDate;
      d.setDate(d.getDate() + 1)
    ) {
      await attendanceService.recalculateAttendance(userId, new Date(d));
    }
  } catch (err) {
    console.error("Error recalculating attendance for leave:", err);
  }
};

// Get all leave requests with filtering and pagination
const getLeaveRequests = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      status,
      leaveType,
      employeeId,
      startDate,
      endDate,
      sortBy = "createdAt",
      sortOrder = "desc",
    } = req.query;

    const query = {};

    // If user is an employee, restrict to their own leave requests
    if (req.userRole === "employee") {
      const employee = await Employee.findOne({ user: req.userId });
      if (!employee) {
        return res.status(404).json({ message: "Employee profile not found" });
      }
      query.employee = employee._id;
    }

    if (status) {
      query.status = status;
    }

    if (leaveType) {
      query.leaveType = leaveType;
    }

    if (employeeId) {
      query.employee = employeeId;
    }

    if (startDate && endDate) {
      query.startDate = {
        $gte: new Date(startDate),
        $lte: new Date(endDate),
      };
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === "desc" ? -1 : 1;

    const leaveRequests = await LeaveRequest.find(query)
      .populate("employee", "name email employeeId jobTitle")
      .populate({
        path: "hrApproval.approvedBy",
        select: "name",
        options: { strictPopulate: false },
      })
      .populate({
        path: "adminApproval.approvedBy",
        select: "fullName designation",
        options: { strictPopulate: false },
      })
      .sort(sortOptions)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await LeaveRequest.countDocuments(query);

    res.json({
      leaveRequests,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching leave requests:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get a single leave request by ID
const getLeaveRequestById = async (req, res) => {
  try {
    const { id } = req.params;

    const leaveRequest = await LeaveRequest.findById(id)
      .populate("employee", "name email employeeId jobTitle phone")
      .populate({
        path: "hrApproval.approvedBy",
        select: "name",
        options: { strictPopulate: false },
      })
      .populate({
        path: "adminApproval.approvedBy",
        select: "fullName designation",
        options: { strictPopulate: false },
      });

    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    res.json({ leaveRequest });
  } catch (error) {
    console.error("Error fetching leave request:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Update leave request status (approve, reject, hold)
const updateLeaveRequestStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, adminComments } = req.body;
    const userId = req.userId;
    const userRole = req.userRole; // This should be set by auth middleware

    // Validate status
    const validStatuses = ["approved", "rejected"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid status. Must be one of: approved, rejected",
      });
    }

    const leaveRequest = await LeaveRequest.findById(id);
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Check if already reviewed
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: "Leave request has already been reviewed",
      });
    }

    let approverId;
    let updateData;

    // Check if user is Admin or HR and get the appropriate document
    if (userRole === "admin") {
      const admin = await Admin.findOne({ user: userId });
      if (!admin) {
        return res.status(404).json({ message: "Admin not found" });
      }
      approverId = admin._id;

      updateData = {
        status,
        "adminApproval.rejectionReason": adminComments || "",
        "adminApproval.approvedBy": approverId,
        "adminApproval.approvedAt": new Date(),
        "adminApproval.status": status,
      };
    } else if (userRole === "hr") {
      const hr = await HR.findOne({ user: userId });
      if (!hr) {
        return res.status(404).json({ message: "HR not found" });
      }
      approverId = hr._id;

      updateData = {
        status,
        "hrApproval.rejectionReason": adminComments || "",
        "hrApproval.approvedBy": approverId,
        "hrApproval.approvedAt": new Date(),
        "hrApproval.status": status,
      };
    } else {
      return res.status(403).json({
        message: "Access denied. Only Admin or HR can approve leave requests",
      });
    }

    const updatedLeaveRequest = await LeaveRequest.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    )
      .populate("employee", "name email employeeId jobTitle user")
      .populate({
        path: "hrApproval.approvedBy",
        select: "name",
        options: { strictPopulate: false },
      })
      .populate({
        path: "adminApproval.approvedBy",
        select: "fullName designation",
        options: { strictPopulate: false },
      });

    // Update employee leave balance based on status change
    // // console.log("📋 Leave Request Controller - Processing status change");
    // // console.log("📋 Leave Request Controller - New status:", status);

    if (status === "approved") {
      await updateEmployeeLeaveBalance(leaveRequest, "approve");
    } else if (status === "rejected" || status === "cancelled") {
      // If the request was previously approved, restore the leave balance
      if (leaveRequest.status === "approved") {
        await updateEmployeeLeaveBalance(leaveRequest, "restore");
      }
    }

    // Recalculate Attendance
    await recalculateAttendanceForLeave(updatedLeaveRequest);

    // Emit WebSocket events based on status
    const eventData = {
      requestId: updatedLeaveRequest._id,
      employee: updatedLeaveRequest.employee,
      status: updatedLeaveRequest.status,
      startDate: updatedLeaveRequest.startDate,
      endDate: updatedLeaveRequest.endDate,
      leaveType: updatedLeaveRequest.leaveType,
      reason: updatedLeaveRequest.reason,
      adminComments: adminComments,
      approvedBy:
        userRole === "admin"
          ? updatedLeaveRequest.adminApproval?.approvedBy
          : updatedLeaveRequest.hrApproval?.approvedBy,
      approvedAt:
        userRole === "admin"
          ? updatedLeaveRequest.adminApproval?.approvedAt
          : updatedLeaveRequest.hrApproval?.approvedAt,
    };

    // --- Start Notification Logic ---
    try {
      const notificationService = require("../services/notification.service");
      const User = require("../models/user.model");

      // Fetch employee user to get token
      if (updatedLeaveRequest.employee && updatedLeaveRequest.employee.user) {
        const user = await User.findById(
          updatedLeaveRequest.employee.user
        ).select("fcmToken");
        if (user && user.fcmToken) {
          let title = "Leave Request Update";
          let body = `Your leave request has been ${status}`;
          if (status === "rejected" && adminComments) {
            body += `: ${adminComments}`;
          }

          await notificationService.sendNotification(
            user.fcmToken,
            title,
            body,
            {
              type: "leave_request",
              id: updatedLeaveRequest._id.toString(),
              status: status,
            }
          );
        }
      }
    } catch (notifErr) {
      console.error("Failed to send leave update notification:", notifErr);
    }
    // --- End Notification Logic ---

    if (status === "approved") {
      // Notify HR/Admin rooms about approval
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.HR_ROOM,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_APPROVED,
        eventData
      );
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.ADMIN_ROOM,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_APPROVED,
        eventData
      );

      // Notify the employee
      websocketService.broadcastToUser(
        updatedLeaveRequest.employee.user,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_APPROVED,
        {
          requestId: updatedLeaveRequest._id,
          status: updatedLeaveRequest.status,
          startDate: updatedLeaveRequest.startDate,
          endDate: updatedLeaveRequest.endDate,
          leaveType: updatedLeaveRequest.leaveType,
          message: "Your leave request has been approved",
        }
      );

      // Update leave balance for all users
      websocketService.broadcastToUser(
        updatedLeaveRequest.employee.user,
        WEBSOCKET_EVENTS.LEAVE_BALANCE_UPDATED,
        {
          employeeId: updatedLeaveRequest.employee._id,
          leaveType: updatedLeaveRequest.leaveType,
          message: "Your leave balance has been updated",
        }
      );

      // Update leave calendar for all users
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.LEAVE_CALENDAR_UPDATED,
        {
          employee: updatedLeaveRequest.employee,
          startDate: updatedLeaveRequest.startDate,
          endDate: updatedLeaveRequest.endDate,
          leaveType: updatedLeaveRequest.leaveType,
          status: "approved",
        }
      );
    } else if (status === "rejected") {
      // Notify HR/Admin rooms about rejection
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.HR_ROOM,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_REJECTED,
        eventData
      );
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.ADMIN_ROOM,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_REJECTED,
        eventData
      );

      // Notify the employee
      websocketService.broadcastToUser(
        updatedLeaveRequest.employee.user,
        WEBSOCKET_EVENTS.LEAVE_REQUEST_REJECTED,
        {
          requestId: updatedLeaveRequest._id,
          status: updatedLeaveRequest.status,
          rejectionReason: adminComments,
          message: "Your leave request has been rejected",
        }
      );
    }

    res.json({
      message: `Leave request ${status} successfully`,
      leaveRequest: updatedLeaveRequest,
    });
  } catch (error) {
    console.error("Error updating leave request status:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Bulk update leave requests
const bulkUpdateLeaveRequests = async (req, res) => {
  try {
    const { leaveRequestIds, status, adminComments } = req.body;
    const adminId = req.userId;

    if (!Array.isArray(leaveRequestIds) || leaveRequestIds.length === 0) {
      return res.status(400).json({
        message: "Leave request IDs array is required",
      });
    }

    const validStatuses = ["approved", "rejected"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        message: "Invalid status. Must be one of: approved, rejected",
      });
    }

    // Find the admin
    const admin = await Admin.findOne({ user: adminId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Update multiple leave requests
    const updateData = {
      status,
      "adminApproval.rejectionReason": adminComments || "",
      "adminApproval.approvedBy": admin._id,
      "adminApproval.approvedAt": new Date(),
      "adminApproval.status": status,
    };

    const result = await LeaveRequest.updateMany(
      {
        _id: { $in: leaveRequestIds },
        status: "pending", // Only update pending requests
      },
      updateData
    );

    // Trigger Attendance Recalculation for Bulk
    const updatedRequests = await LeaveRequest.find({
      _id: { $in: leaveRequestIds },
    });
    for (const req of updatedRequests) {
      await recalculateAttendanceForLeave(req);
    }

    res.json({
      message: `${result.modifiedCount} leave requests updated successfully`,
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error("Error bulk updating leave requests:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get leave request statistics
const getLeaveRequestStats = async (req, res) => {
  try {
    const stats = await LeaveRequest.aggregate([
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
    ]);

    const totalRequests = await LeaveRequest.countDocuments();
    const pendingRequests = await LeaveRequest.countDocuments({
      status: "pending",
    });
    const approvedRequests = await LeaveRequest.countDocuments({
      status: "approved",
    });
    const rejectedRequests = await LeaveRequest.countDocuments({
      status: "rejected",
    });

    // Get recent activity
    const recentActivity = await LeaveRequest.find()
      .populate("employee", "name employeeId")
      .populate({
        path: "hrApproval.approvedBy",
        select: "name",
        options: { strictPopulate: false },
      })
      .populate({
        path: "adminApproval.approvedBy",
        select: "fullName",
        options: { strictPopulate: false },
      })
      .sort({ createdAt: -1 })
      .limit(5);

    res.json({
      stats: {
        total: totalRequests,
        pending: pendingRequests,
        approved: approvedRequests,
        rejected: rejectedRequests,
      },
      recentActivity,
    });
  } catch (error) {
    console.error("Error fetching leave request stats:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get leave requests by employee
const getLeaveRequestsByEmployee = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { page = 1, limit = 10 } = req.query;

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const leaveRequests = await LeaveRequest.find({ employee: employeeId })
      .populate("employee", "name email employeeId jobTitle")
      .populate({
        path: "hrApproval.approvedBy",
        select: "name",
        options: { strictPopulate: false },
      })
      .populate({
        path: "adminApproval.approvedBy",
        select: "fullName designation",
        options: { strictPopulate: false },
      })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await LeaveRequest.countDocuments({ employee: employeeId });

    res.json({
      leaveRequests,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    console.error("Error fetching leave requests by employee:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Delete leave request (soft delete)
const deleteLeaveRequest = async (req, res) => {
  try {
    const { id } = req.params;

    const leaveRequest = await LeaveRequest.findById(id);
    if (!leaveRequest) {
      return res.status(404).json({ message: "Leave request not found" });
    }

    // Only allow deletion of pending requests
    if (leaveRequest.status !== "pending") {
      return res.status(400).json({
        message: "Cannot delete reviewed leave requests",
      });
    }

    await LeaveRequest.findByIdAndDelete(id);

    res.json({ message: "Leave request deleted successfully" });
  } catch (error) {
    console.error("Error deleting leave request:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get leave calendar (upcoming leaves)
const getLeaveCalendar = async (req, res) => {
  try {
    const { month, year } = req.query;
    const startDate = new Date(
      year || new Date().getFullYear(),
      month || new Date().getMonth(),
      1
    );
    const endDate = new Date(
      year || new Date().getFullYear(),
      (month || new Date().getMonth()) + 1,
      0
    );

    const leaveRequests = await LeaveRequest.find({
      status: "approved",
      $or: [
        {
          startDate: { $gte: startDate, $lte: endDate },
        },
        {
          endDate: { $gte: startDate, $lte: endDate },
        },
        {
          startDate: { $lte: startDate },
          endDate: { $gte: endDate },
        },
      ],
    })
      .populate("employee", "name employeeId jobTitle")
      .sort({ startDate: 1 });

    res.json({ leaveRequests });
  } catch (error) {
    console.error("Error fetching leave calendar:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Helper function to update employee leave balance when a leave request status changes
const updateEmployeeLeaveBalance = async (leaveRequest, action) => {
  console.log("💰 Leave Balance Update - Starting update process");
  console.log("💰 Leave Balance Update - Action:", action);
  console.log("💰 Leave Balance Update - Leave Request ID:", leaveRequest._id);
  console.log("💰 Leave Balance Update - Employee ID:", leaveRequest.employee);

  try {
    const employee = await Employee.findById(leaveRequest.employee);
    if (!employee) {
      console.error(
        "❌ Leave Balance Update - Employee not found for leave request:",
        leaveRequest._id
      );
      return;
    }

    console.log("✅ Leave Balance Update - Employee found:", employee.name);

    const { leaveType, durationType, halfDayPeriod, permissionHours } =
      leaveRequest;
    let leaveDeduction = 0;
    let permissionHoursDeduction = 0;

    console.log("💰 Leave Balance Update - Leave details:");
    console.log("  📋 Leave Type:", leaveType);
    console.log("  📋 Duration Type:", durationType);
    console.log("  📋 Permission Hours:", permissionHours);

    // Calculate leave deduction based on leave type and duration
    if (leaveType === "casual" || leaveType === "sick") {
      if (durationType === "full_day") {
        leaveDeduction = 1;
      } else if (durationType === "half_day") {
        leaveDeduction = 0.5;
      }
    } else if (leaveType === "work_from_home") {
      if (durationType === "full_day") {
        leaveDeduction = 1;
      } else if (durationType === "half_day") {
        leaveDeduction = 0.5;
      }
    } else if (leaveType === "permission") {
      permissionHoursDeduction = permissionHours || 0;
    }

    console.log("💰 Leave Balance Update - Calculated deductions:");
    console.log("  📊 Leave Deduction:", leaveDeduction);
    console.log("  📊 Permission Hours Deduction:", permissionHoursDeduction);

    // Update leave balance and history
    const updateData = {};

    if (action === "approve") {
      // // console.log("💰 Leave Balance Update - Processing approval...");
      // Deduct leaves when approving
      if (leaveType === "casual") {
        const newCasualLeave = Math.max(
          0,
          employee.leaveBalance.casualLeave - leaveDeduction
        );
        const newTotalUsed =
          (employee.leaveHistory?.totalCasualLeavesUsed || 0) + leaveDeduction;
        updateData["leaveBalance.casualLeave"] = newCasualLeave;
        updateData["leaveHistory.totalCasualLeavesUsed"] = newTotalUsed;
        // // console.log("💰 Leave Balance Update - Casual leave update:");
        // // console.log("  📊 Current balance:", employee.leaveBalance.casualLeave);
        // // console.log("  📊 New balance:", newCasualLeave);
        // // console.log("  📊 New total used:", newTotalUsed);
      } else if (leaveType === "sick") {
        updateData["leaveHistory.totalSickLeavesUsed"] =
          (employee.leaveHistory?.totalSickLeavesUsed || 0) + leaveDeduction;
      } else if (leaveType === "work_from_home") {
        updateData["leaveBalance.workFromHome"] = Math.max(
          0,
          employee.leaveBalance.workFromHome - leaveDeduction
        );
        updateData["leaveHistory.totalWFHUsed"] =
          (employee.leaveHistory?.totalWFHUsed || 0) + leaveDeduction;
      } else if (leaveType === "permission") {
        updateData["leaveBalance.permissionHours"] = Math.max(
          0,
          employee.leaveBalance.permissionHours - permissionHoursDeduction
        );
        updateData["leaveHistory.totalPermissionHoursUsed"] =
          (employee.leaveHistory?.totalPermissionHoursUsed || 0) +
          permissionHoursDeduction;
      }
    } else if (action === "restore") {
      // Restore leaves when rejecting/cancelling previously approved request
      if (leaveType === "casual") {
        updateData["leaveBalance.casualLeave"] =
          employee.leaveBalance.casualLeave + leaveDeduction;
        updateData["leaveHistory.totalCasualLeavesUsed"] = Math.max(
          0,
          (employee.leaveHistory?.totalCasualLeavesUsed || 0) - leaveDeduction
        );
      } else if (leaveType === "sick") {
        updateData["leaveHistory.totalSickLeavesUsed"] = Math.max(
          0,
          (employee.leaveHistory?.totalSickLeavesUsed || 0) - leaveDeduction
        );
      } else if (leaveType === "work_from_home") {
        updateData["leaveBalance.workFromHome"] =
          employee.leaveBalance.workFromHome + leaveDeduction;
        updateData["leaveHistory.totalWFHUsed"] = Math.max(
          0,
          (employee.leaveHistory?.totalWFHUsed || 0) - leaveDeduction
        );
      } else if (leaveType === "permission") {
        updateData["leaveBalance.permissionHours"] =
          employee.leaveBalance.permissionHours + permissionHoursDeduction;
        updateData["leaveHistory.totalPermissionHoursUsed"] = Math.max(
          0,
          (employee.leaveHistory?.totalPermissionHoursUsed || 0) -
            permissionHoursDeduction
        );
      }
    }

    // Update the employee document
    const updatedEmployee = await Employee.findByIdAndUpdate(
      employee._id,
      updateData,
      { new: true }
    );
  } catch (error) {
    console.error("Error updating employee leave balance:", error);
  }
};

module.exports = {
  getLeaveRequests,
  getLeaveRequestById,
  updateLeaveRequestStatus,
  bulkUpdateLeaveRequests,
  getLeaveRequestStats,
  getLeaveRequestsByEmployee,
  deleteLeaveRequest,
  getLeaveCalendar,
};
