const PayslipRequest = require("../models/payslipRequest.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Payroll = require("../models/payroll.model");
const Attendance = require("../models/attendance.model");
const Holiday = require("../models/holiday.model");
const websocketService = require("../services/websocket.service");
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");
const payrollService = require("../services/payroll.service");
const notificationService = require("../services/notification.service");
const User = require("../models/user.model");
const logger = require("../core/logger");

// Helper to generate unique transaction ID
const generateTransactionId = () => {
  const timestamp = Date.now().toString(36).toUpperCase();
  const randomPart = Math.random().toString(36).substring(2, 7).toUpperCase();
  return `TXN-${timestamp}-${randomPart}`;
};

// Helper: Send notification to all HRs
const notifyAllHRs = async (title, body, data) => {
  try {
    const hrUsers = await HR.find().populate("user");
    // We want to target unique Users.
    const uniqueUsers = new Map(); // userId -> User object (with token)

    for (const hr of hrUsers) {
      if (hr.user && hr.user.fcmToken) {
        uniqueUsers.set(hr.user._id.toString(), hr.user);
      }
    }

    // Also include Admins? Usually yes for requests.
    const admins = await require("../models/admin.model")
      .find()
      .populate("user");
    for (const admin of admins) {
      if (admin.user && admin.user.fcmToken) {
        uniqueUsers.set(admin.user._id.toString(), admin.user);
      }
    }

    for (const user of uniqueUsers.values()) {
      if (user.fcmToken) {
        notificationService
          .sendNotification(
            user.fcmToken,
            title,
            body,
            data,
            user._id,
            true, // useDataOnly = true for HR payslip requests
          )
          .catch((e) =>
            logger.error(`Failed to notify HR/Admin ${user._id}`, {
              error: e.message,
            }),
          );
      }
    }
  } catch (error) {
    logger.error("Error notifying HRs", { error: error.message });
  }
};

// Helper: Send notification to Employee
const notifyEmployee = async (employeeId, title, body, data) => {
  try {
    console.log(`[NotifyEmployee] Attempting to notify employee: ${employeeId}`);
    const employee = await Employee.findById(employeeId).populate("user");
    if (employee && employee.user && employee.user.fcmToken) {
      // Fire and forget push notification
      notificationService
        .sendNotification(
          employee.user.fcmToken,
          title,
          body,
          data,
          employee.user._id, // Pass explicit user ID
          true, // useDataOnly = true for Employee payslip updates
        )
        .catch((e) =>
          logger.error("Failed to send employee notification", {
            error: e.message,
          }),
        );
    }
  } catch (error) {
    logger.error("Error notifying Employee", { error: error.message });
  }
};

/**
 * Helper: Get month index from name (0-11)
 */
const getMonthIndex = (monthName) => {
  const months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  return months.findIndex((m) => m.toLowerCase() === monthName.toLowerCase());
};

/**
 * @description Submit a payslip request (Employee)
 */
exports.submitPayslipRequest = async (req, res) => {
  try {
    const { startMonth, startYear, endMonth, endYear, reason } = req.body;
    const employeeUserId = req.userId;

    if (!startMonth || !startYear || !endMonth || !endYear) {
      return res.status(400).json({
        message:
          "Missing required fields: startMonth, startYear, endMonth, and endYear are required",
      });
    }

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Check if there's already a pending request for the same date range
    const existingRequest = await PayslipRequest.findOne({
      employee: employeeProfile._id,
      startMonth,
      startYear,
      endMonth,
      endYear,
      status: { $in: ["pending", "processing"] },
    });

    if (existingRequest) {
      return res.status(400).json({
        message: "You already have a pending request for this date range",
      });
    }

    // Create payslip request with auto-generated reference ID
    const payslipRequest = new PayslipRequest({
      employee: employeeProfile._id,
      startMonth,
      startYear,
      endMonth,
      endYear,
      reason: reason || "",
      status: "pending",
      transactionId: generateTransactionId(), // Generate reference ID immediately
    });

    // Try to prefill payslip defaults from the latest payroll record for this employee
    try {
      const latestPayroll = await Payroll.findOne({
        employee: employeeProfile._id,
      })
        .sort({ payPeriod: -1 })
        .lean();

      if (latestPayroll) {
        // Copy relevant fields if available
        if (latestPayroll.totalPay !== undefined)
          payslipRequest.basePay = latestPayroll.totalPay;
        if (latestPayroll.calculatedFields) {
          // Copy calculatedFields but ensure no null values
          const cf = latestPayroll.calculatedFields;
          const basicPay = cf.basicPay || latestPayroll.totalPay || 0;
          const hra = cf.hra || 0;
          const specialAllowance = cf.specialAllowance || 0;

          // Calculate netSalary if missing or null
          let netSalary = cf.netSalary;
          if (!netSalary || netSalary === null) {
            const deductions = latestPayroll.deductions || {};
            const totalDeductions =
              (deductions.pf || 0) +
              (deductions.esi || 0) +
              (deductions.pt || 0) +
              (deductions.lop || 0) +
              (deductions.penalty || 0);
            netSalary = basicPay + hra + specialAllowance - totalDeductions;
          }

          payslipRequest.calculatedFields = {
            basicPay,
            hra,
            specialAllowance,
            netSalary,
            bonus: cf.bonus || 0,
          };
        }
        if (latestPayroll.deductions)
          payslipRequest.deductions = latestPayroll.deductions;
        if (latestPayroll.payslipDetails)
          payslipRequest.payslipDetails = latestPayroll.payslipDetails;
        console.log("✅ [PREFILL] Prefilled request with payroll data");
        console.log("📋 [PREFILL] Request after prefill:", {
          basePay: payslipRequest.basePay,
          netSalary: payslipRequest.calculatedFields?.netSalary,
        });
      } else if (employeeProfile.payrollInfo) {
        // Fallback: Use Employee Profile Payroll Info
        // Fallback: Use Employee Profile Payroll Info
        const pi = employeeProfile.payrollInfo;
        const basicPay = pi.basicPay || 0;
        const hra = pi.hra || 0;
        const specialAllowance = pi.specialAllowance || 0;
        const pf = pi.pf || 0;
        const esi = pi.esi || 0;
        const pt = pi.pt || 200;

        const totalDeductions = pf + esi + pt;
        const netSalary = basicPay + hra + specialAllowance - totalDeductions;

        payslipRequest.basePay = basicPay + hra + specialAllowance;
        payslipRequest.calculatedFields = {
          basicPay,
          hra,
          specialAllowance,
          netSalary,
          bonus: 0,
        };
        payslipRequest.deductions = {
          pf,
          esi,
          pt,
          lop: 0,
          penalty: 0,
        };
      } else {
        // No payroll record found
      }
    } catch (e) {
      // Non-fatal: log and continue without prefilling
      // Non-fatal: log and continue without prefilling
      logger.error(
        "Error fetching latest payroll for prefilling payslip request",
        {
          error: e.message,
        },
      );
    }

    await payslipRequest.save();

    // Populate employee info
    await payslipRequest.populate("employee", "name email employeeId");

    // Emit WebSocket event ONLY to HR room (employee gets toast confirmation from frontend)
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_CREATED,
      {
        requestId: payslipRequest._id,
        employee: payslipRequest.employee,
        startMonth: payslipRequest.startMonth,
        startYear: payslipRequest.startYear,
        endMonth: payslipRequest.endMonth,
        endYear: payslipRequest.endYear,
        reason: payslipRequest.reason,
        status: payslipRequest.status,
        createdAt: payslipRequest.createdAt,
      },
    );

    // SEND PUSH NOTIFICATION ONLY TO HRs (not to employee who submitted)
    // Fire-and-forget to avoid blocking response
    notifyAllHRs(
      "New Payslip Request",
      `${employeeProfile.name} requested a payslip for ${startMonth} ${startYear} - ${endMonth} ${endYear}`,
      {
        type: "payslip_request_created",
        requestId: payslipRequest._id.toString(),
      },
    );

    res.status(201).json({
      message: "Payslip request submitted successfully",
      data: payslipRequest,
    });
  } catch (err) {
    logger.error("Error submitting payslip request", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get payslip requests for employee
 */
exports.getEmployeePayslipRequests = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { page = 1, limit = 10, status } = req.query;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Build query
    const query = { employee: employeeProfile._id };
    if (status) {
      query.status = status;
    }

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get requests
    const requests = await PayslipRequest.find(query)
      .populate("processedBy", "name email")
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await PayslipRequest.countDocuments(query);

    if (requests.length > 0) {
    }

    // Format requests to include requestedDate
    const formattedRequests = requests.map((request) => {
      const requestObj = request.toObject();
      requestObj.requestedDate = request.createdAt.toISOString().split("T")[0]; // Format as YYYY-MM-DD

      // --- HEALING LOGIC: Fix historical records with missing Conveyance ---
      const cf = requestObj.calculatedFields || {};
      const basicPay = cf.basicPay || 0;

      if (basicPay > 0) {
        const standardHRA = Math.round(basicPay * 0.575);
        const standardConveyance = Math.round(basicPay * 0.275);
        const currentHRA = cf.hra || 0;
        const currentConveyance = cf.conveyance || 0;
        let healed = false;

        // Heal HRA
        if (!currentHRA || currentHRA === 0) {
          cf.hra = standardHRA;
          healed = true;
        }
        // Heal Conveyance
        if (!currentConveyance || currentConveyance === 0) {
          cf.conveyance = standardConveyance;
          healed = true;
        }

        if (healed) {
          requestObj.calculatedFields = cf;

          // Recalculate Net Salary for display
          const totalEarnings =
            (cf.basicPay || 0) +
            (cf.hra || 0) +
            (cf.conveyance || 0) +
            (cf.specialAllowance || 0);
          const totalDeductions =
            (requestObj.deductions?.pf || 0) +
            (requestObj.deductions?.esi || 0) +
            (requestObj.deductions?.pt || 0) +
            (requestObj.deductions?.lop || 0) +
            (requestObj.deductions?.penalty || 0);

          requestObj.calculatedFields.netSalary =
            totalEarnings + (requestObj.bonus || 0) - totalDeductions;

          // Allow BasePay to reflect Gross if needed for UI, or keep as is.
          // But usually list view might show netSalary.
        }
      }
      // -------------------------------------------------------------------

      return requestObj;
    });

    res.status(200).json({
      requests: formattedRequests,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    });
  } catch (err) {
    logger.error("Error getting employee payslip requests", {
      error: err.message,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get all payslip requests for HR
 */
exports.getHRPayslipRequests = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { page = 1, limit = 10, status } = req.query;

    const HR = require("../models/hr.model");
    const User = require("../models/user.model"); // Ensure User model is required

    let isAuthorized = false;

    // 1. Try to find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (hrProfile) {
      isAuthorized = true;
    } else {
      // 2. If not HR, check if Admin
      const user = await User.findById(hrUserId);
      if (user && user.role === "admin") {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      return res
        .status(403)
        .json({ message: "Access denied: HR or Admin profile required" });
    }

    // Build query
    const query = {};
    if (status) {
      if (status.includes(",")) {
        query.status = { $in: status.split(",") };
      } else {
        query.status = status;
      }
    }

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get requests
    const requests = await PayslipRequest.find(query)
      .populate("employee", "name email employeeId")
      .populate("processedBy", "name email")
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await PayslipRequest.countDocuments(query);

    // Format requests to include requestedDate and ensure prefill fields exist
    const formattedRequests = [];
    for (const request of requests) {
      const requestObj = request.toObject();
      requestObj.requestedDate = request.createdAt.toISOString().split("T")[0]; // Format as YYYY-MM-DD

      // If the request does not have payroll prefill fields, try to attach the latest payroll for that employee
      try {
        const hasBasePay =
          requestObj.basePay !== undefined && requestObj.basePay !== null;

        // Consider calculated fields meaningful only if at least one numeric value > 0 exists
        // ... (existing prefill logic continues) ...
      } catch (e) {
        logger.error("Error attaching latest payroll to request", {
          error: e.message,
        });
      }

      // --- HEALING LOGIC: Fix historical records with missing Conveyance ---
      const cf = requestObj.calculatedFields || {};
      const basicPay = cf.basicPay || 0;

      if (basicPay > 0) {
        const standardHRA = Math.round(basicPay * 0.575);
        const standardConveyance = Math.round(basicPay * 0.275);
        const currentHRA = cf.hra || 0;
        const currentConveyance = cf.conveyance || 0;
        let healed = false;

        // Heal HRA
        if (!currentHRA || currentHRA === 0) {
          cf.hra = standardHRA;
          healed = true;
        }
        // Heal Conveyance
        if (!currentConveyance || currentConveyance === 0) {
          cf.conveyance = standardConveyance;
          healed = true;
        }

        if (healed) {
          requestObj.calculatedFields = cf;

          // Recalculate Net Salary for display
          const totalEarnings =
            (cf.basicPay || 0) +
            (cf.hra || 0) +
            (cf.conveyance || 0) +
            (cf.specialAllowance || 0);
          const totalDeductions =
            (requestObj.deductions?.pf || 0) +
            (requestObj.deductions?.esi || 0) +
            (requestObj.deductions?.pt || 0) +
            (requestObj.deductions?.lop || 0) +
            (requestObj.deductions?.penalty || 0);

          requestObj.calculatedFields.netSalary =
            totalEarnings + (requestObj.bonus || 0) - totalDeductions;
        }
      }

      formattedRequests.push(requestObj);
    }

    res.status(200).json({
      requests: formattedRequests,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    });
  } catch (err) {
    logger.error("Error getting HR payslip requests", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update payslip request status (HR)
 */
exports.updatePayslipRequestStatus = async (req, res) => {
  try {
    const { requestId } = req.params;
    const {
      status,
      payslipUrl,
      rejectionReason,
      basePay,
      deductions,
      payslipDetails,
      calculatedFields,
      transactionId, // Added
    } = req.body;
    const hrUserId = req.userId;

    if (!status) {
      return res.status(400).json({
        message: "Status is required",
      });
    }

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find payslip request
    const payslipRequest = await PayslipRequest.findById(requestId);
    if (!payslipRequest) {
      return res.status(404).json({ message: "Payslip request not found" });
    }

    // Update request
    payslipRequest.status = status;
    payslipRequest.processedBy = hrProfile._id;
    payslipRequest.processedAt = new Date();

    // Update payroll data if provided (e.g. when putting on hold)
    if (basePay !== undefined) payslipRequest.basePay = basePay;
    if (deductions !== undefined) payslipRequest.deductions = deductions;
    if (payslipDetails !== undefined)
      payslipRequest.payslipDetails = payslipDetails;
    if (calculatedFields !== undefined)
      payslipRequest.calculatedFields = calculatedFields;
    if (transactionId) payslipRequest.transactionId = transactionId; // Added assignment

    if (payslipUrl) {
      payslipRequest.payslipUrl = payslipUrl;
      // Set expiry to 3 days from now
      payslipRequest.payslipExpiry = new Date(
        Date.now() + 3 * 24 * 60 * 60 * 1000,
      );
    } else if (status === "approved" || status === "completed") {
      // Ensure a downloadable URL exists for approved/completed payslips
      payslipRequest.payslipUrl = `/api/payslip-requests/${payslipRequest._id}/download`;
      // Set expiry to 3 days from now
      payslipRequest.payslipExpiry = new Date(
        Date.now() + 3 * 24 * 60 * 60 * 1000,
      );
    }

    if (rejectionReason) {
      payslipRequest.rejectionReason = rejectionReason;
    }

    await payslipRequest.save();

    // Populate the updated request
    await payslipRequest.populate("employee", "name email employeeId user");
    await payslipRequest.populate("processedBy", "name email");

    // Emit WebSocket events based on status
    const eventData = {
      requestId: payslipRequest._id,
      employee: payslipRequest.employee,
      processedBy: payslipRequest.processedBy,
      status: payslipRequest.status,
      payslipUrl: payslipRequest.payslipUrl,
      rejectionReason: payslipRequest.rejectionReason,
      payslipExpiry: payslipRequest.payslipExpiry,
      processedAt: payslipRequest.processedAt,
    };

    if (status === "approved" || status === "completed") {
      // Notify ONLY the employee (HR gets toast confirmation from frontend)
      websocketService.broadcastToUser(
        payslipRequest.employee.user,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
        {
          requestId: payslipRequest._id,
          status: payslipRequest.status,
          payslipUrl: payslipRequest.payslipUrl,
          payslipExpiry: payslipRequest.payslipExpiry,
          message: "Your payslip request has been approved",
          type: "payslip_approved",
        },
      );

      if (payslipUrl) {
        websocketService.broadcastToUser(
          payslipRequest.employee.user,
          WEBSOCKET_EVENTS.PAYSLIP_GENERATED,
          {
            requestId: payslipRequest._id,
            payslipUrl: payslipUrl,
            message:
              "Your payslip has been generated and is ready for download",
          },
        );
      }

      // SEND PUSH NOTIFICATION TO EMPLOYEE
      notifyEmployee(
        payslipRequest.employee._id,
        "Payslip Request Approved",
        "Your payslip request has been approved and is ready.",
        {
          type: "payslip_approved",
          requestId: payslipRequest._id.toString(),
          status: "approved",
        },
      );
    } else if (status === "rejected") {
      // Notify ONLY the employee (HR gets toast confirmation from frontend)

      // Notify the employee
      websocketService.broadcastToUser(
        payslipRequest.employee.user,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_REJECTED,
        {
          requestId: payslipRequest._id,
          status: payslipRequest.status,
          rejectionReason: payslipRequest.rejectionReason,
          message: "Your payslip request has been rejected",
        },
      );

      // SEND PUSH NOTIFICATION TO EMPLOYEE
      notifyEmployee(
        payslipRequest.employee._id,
        "Payslip Request Rejected",
        `Your payslip request was rejected. Reason: ${payslipRequest.rejectionReason}`,
        {
          type: "payslip_rejected",
          requestId: payslipRequest._id.toString(),
          status: "rejected",
        },
      );
    } else if (status === "on-hold") {
      // Notify ONLY the employee (HR gets toast confirmation from frontend)

      // Notify the employee
      websocketService.broadcastToUser(
        payslipRequest.employee.user,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_ON_HOLD,
        {
          requestId: payslipRequest._id,
          status: payslipRequest.status,
          message: "Your payslip request is currently on hold",
        },
      );

      // SEND PUSH NOTIFICATION TO EMPLOYEE
      notifyEmployee(
        payslipRequest.employee._id,
        "Payslip On Hold",
        "Your payslip request has been put on hold.",
        {
          type: "payslip_on_hold",
          requestId: payslipRequest._id.toString(),
          status: "on-hold",
        },
      );
    }

    res.status(200).json({
      message: "Payslip request status updated successfully",
      data: payslipRequest,
    });
  } catch (err) {
    logger.error("Error updating payslip request status", {
      error: err.message,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get payslip request statistics for HR
 */
exports.getPayslipRequestStats = async (req, res) => {
  try {
    const hrUserId = req.userId;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Get statistics
    const stats = await PayslipRequest.aggregate([
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
    ]);

    const totalRequests = await PayslipRequest.countDocuments();
    const pendingRequests = await PayslipRequest.countDocuments({
      status: "pending",
    });
    const processingRequests = await PayslipRequest.countDocuments({
      status: "processing",
    });
    const completedRequests = await PayslipRequest.countDocuments({
      status: "completed",
    });

    res.status(200).json({
      total: totalRequests,
      pending: pendingRequests,
      processing: processingRequests,
      completed: completedRequests,
      breakdown: stats,
    });
  } catch (err) {
    logger.error("Error getting payslip request stats", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Process payslip request with base pay (HR)
 * HR fills base pay, system auto-calculates other fields
 */
exports.processPayslipWithBasePay = async (req, res) => {
  try {
    const { requestId } = req.params;
    const {
      basePay,
      bonus = 0,
      calculatedFields = {},
      deductions = {},
      payslipDetails = {},
    } = req.body;
    const hrUserId = req.userId;

    if (!basePay || basePay <= 0) {
      logger.error("Base pay validation failed");
      return res.status(400).json({
        message: "Base pay is required and must be greater than 0",
      });
    }

    // Find HR profile
    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      logger.error(`HR profile not found for userId: ${hrUserId}`);
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Find payslip request and populate employee with user field and payroll info
    // console.log("📋 [PAYSLIP] Finding payslip request...");
    const payslipRequest = await PayslipRequest.findById(requestId).populate(
      "employee",
      "name email employeeId user payrollInfo", // Added payrollInfo
    );
    if (!payslipRequest) {
      logger.error(`Payslip request not found: ${requestId}`);
      return res.status(404).json({ message: "Payslip request not found" });
    }

    // Use provided calculatedFields if available, otherwise calculate from basePay
    let basicPay, hra, conveyance, specialAllowance, netSalary;

    if (
      calculatedFields.basicPay !== undefined &&
      calculatedFields.hra !== undefined
    ) {
      // Use provided values from frontend (old payroll format)
      basicPay = calculatedFields.basicPay || 0;
      hra = calculatedFields.hra || 0;
      conveyance = calculatedFields.conveyance || 0;
      specialAllowance = calculatedFields.specialAllowance || 0;
      if (
        calculatedFields.netSalary !== undefined &&
        calculatedFields.netSalary !== null &&
        Number(calculatedFields.netSalary) > 0
      ) {
        netSalary = Number(calculatedFields.netSalary);
      } else {
        // Calculate netSalary from provided values
        const totalDeductionsCalc =
          (deductions.pf || 0) +
          (deductions.esi || 0) +
          (deductions.pt || 0) +
          (deductions.lop || 0) +
          (deductions.penalty || 0);

        netSalary =
          basicPay +
          hra +
          conveyance +
          specialAllowance +
          (bonus || 0) -
          totalDeductionsCalc;
      }

      try {
        await Employee.findByIdAndUpdate(payslipRequest.employee._id, {
          payrollInfo: {
            basicPay: basicPay,
            hra: hra,
            conveyance: conveyance,
            specialAllowance: specialAllowance,
            pf: deductions.pf || 0,
            esi: deductions.esi || 0,
            pt: deductions.pt || 0,
          },
        });
      } catch (err) {
        logger.error("Failed to update Employee payroll info", {
          error: err.message,
        });
      }
    } else {
      const manualPayroll = payslipRequest.employee.payrollInfo;

      if (manualPayroll && manualPayroll.basicPay > 0) {
        basicPay = manualPayroll.basicPay;
        hra = manualPayroll.hra || 0;
        conveyance = manualPayroll.conveyance || 0;
        specialAllowance = manualPayroll.specialAllowance || 0;

        // Manual Deductions
        deductions.pf = manualPayroll.pf || 0;
        deductions.esi = manualPayroll.esi || 0;
        deductions.pt = manualPayroll.pt || 0;

        const providedPenalty = deductions.penalty || 0;
        const providedLop = deductions.lop || 0;

        // Recalculate Total Deductions
        const totalDeductions =
          deductions.pf +
          deductions.esi +
          deductions.pt +
          providedLop +
          providedPenalty;

        // Net Salary
        netSalary =
          basicPay +
          hra +
          conveyance +
          specialAllowance +
          (bonus || 0) -
          totalDeductions;
      } else {
        basicPay = basePay * 0.5;
        hra = basePay * 0.2875;
        conveyance = basePay * 0.1375;
        specialAllowance = basePay * 0.075;

        let calculatedPenalty = 0; // Force 0

        const finalPT = 200;
        netSalary = basePay + (bonus || 0);
        deductions.pt = 200;
        deductions.penalty = 0;
      }
    }

    // Calculate total deductions
    const totalDeductions =
      (deductions.pf || 0) +
      (deductions.esi || 0) +
      (deductions.pt || 0) +
      (deductions.lop || 0) +
      (deductions.penalty || 0);

    if (!basicPay && basePay > 0) {
      basicPay = basePay * 0.5; // Default if completely missing
    }

    // Refine HRA and Conveyance if zero/missing
    if (basicPay > 0) {
      const standardHRA = Math.round(basicPay * 0.575);
      const standardConveyance = Math.round(basicPay * 0.275);

      if (!hra || hra === 0) {
        hra = standardHRA;
      }
      if (!conveyance || conveyance === 0) {
        conveyance = standardConveyance;
      }
    }

    if (netSalary === undefined || netSalary === null) {
      const totalDeductionsCheck =
        (deductions.pf || 0) +
        (deductions.esi || 0) +
        (deductions.pt || 0) +
        (deductions.lop || 0) +
        (deductions.penalty || 0);

      netSalary =
        (basicPay || 0) +
        (hra || 0) +
        (conveyance || 0) +
        (specialAllowance || 0) +
        (bonus || 0) -
        totalDeductionsCheck;
    }

    // Update request with calculated fields
    payslipRequest.basePay = basePay;
    payslipRequest.calculatedFields = {
      basicPay: basicPay || 0,
      hra: hra || 0,
      conveyance: conveyance || 0,
      specialAllowance: specialAllowance || 0,
      netSalary: netSalary || 0,
      bonus: bonus || 0,
    };

    // Update deductions
    payslipRequest.deductions = {
      pf: deductions.pf || 0,
      esi: deductions.esi || 0,
      pt: finalPT, // usage of new variable
      lop: deductions.lop || 0,
      penalty: deductions.penalty || 0,
    };

    // Update payslip details
    if (payslipDetails.pan)
      payslipRequest.payslipDetails.pan = payslipDetails.pan;
    if (payslipDetails.bankName)
      payslipRequest.payslipDetails.bankName = payslipDetails.bankName;
    if (payslipDetails.accountNumber)
      payslipRequest.payslipDetails.accountNumber =
        payslipDetails.accountNumber;
    if (payslipDetails.pfNumber)
      payslipRequest.payslipDetails.pfNumber = payslipDetails.pfNumber;
    if (payslipDetails.uan)
      payslipRequest.payslipDetails.uan = payslipDetails.uan;
    if (payslipDetails.paidDays)
      payslipRequest.payslipDetails.paidDays = payslipDetails.paidDays;
    if (payslipDetails.lopDays)
      payslipRequest.payslipDetails.lopDays = payslipDetails.lopDays;

    // Use provided transactionId or Auto-Generate one
    if (transactionId) {
      payslipRequest.transactionId = transactionId;
    } else if (!payslipRequest.transactionId) {
      // Only generate if not already set (though for 'process' it likely isn't)
      payslipRequest.transactionId = generateTransactionId();
    }

    payslipRequest.status = "approved";
    payslipRequest.processedBy = hrProfile._id;
    payslipRequest.processedAt = new Date();

    // Format: /api/payslip-requests/:requestId/download
    payslipRequest.payslipUrl = `/api/payslip-requests/${payslipRequest._id}/download`;

    await payslipRequest.save();

    await payslipRequest.populate(
      "employee",
      "name email employeeId user jobTitle joinDate",
    );
    await payslipRequest.populate("processedBy", "name email");

    // Notify the employee
    const employeeUserId = payslipRequest.employee?.user;
    if (employeeUserId) {
      const notificationData = {
        requestId: payslipRequest._id.toString(),
        status: payslipRequest.status,
        message: "Payslip Accepted",
        type: "payslip_approved",
        title: "Payslip Accepted",
        payslipUrl: payslipRequest.payslipUrl,
        payslipExpiry: payslipRequest.payslipExpiry,
      };

      websocketService.broadcastToUser(
        employeeUserId,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
        notificationData,
      );
      // Notify that payslip has been generated (if payslipUrl set)
      if (payslipRequest.payslipUrl) {
        websocketService.broadcastToUser(
          employeeUserId,
          WEBSOCKET_EVENTS.PAYSLIP_GENERATED,
          {
            requestId: payslipRequest._id,
            payslipUrl: payslipRequest.payslipUrl,
            payslipExpiry: payslipRequest.payslipExpiry,
            message:
              "Your payslip has been generated and is ready for download",
          },
        );
      }

      // SEND PUSH NOTIFICATION TO EMPLOYEE
      // Fire and forget - do not await strictly to ensure fast response
      notifyEmployee(
        payslipRequest.employee._id,
        "Payslip Processed",
        "Your payslip has been processed successfully.",
        {
          type: "payslip_approved",
          requestId: payslipRequest._id.toString(),
          status: "approved",
        },
      );

      // --- BRIDGE: Create/Update Payroll Record ---
      try {
        const monthMap = {
          January: 0,
          February: 1,
          March: 2,
          April: 3,
          May: 4,
          June: 5,
          July: 6,
          August: 7,
          September: 8,
          October: 9,
          November: 10,
          December: 11,
        };
        const payPeriodDate = new Date(
          parseInt(payslipRequest.startYear),
          monthMap[payslipRequest.startMonth],
          1,
        );

        // Check availability
        const existingPayroll = await Payroll.findOne({
          employee: payslipRequest.employee._id,
          payPeriod: payPeriodDate,
        });

        const payrollData = {
          employee: payslipRequest.employee._id,
          totalPay:
            payslipRequest.calculatedFields?.netSalary ||
            payslipRequest.basePay ||
            0,
          payPeriod: payPeriodDate,
          calculatedFields: payslipRequest.calculatedFields,
          deductions: payslipRequest.deductions,
          payslipDetails: payslipRequest.payslipDetails,
          transactionId: payslipRequest.transactionId, // This will now have the auto-generated one
          bonus: payslipRequest.bonus || 0,
        };

        if (existingPayroll) {
          // Update existing
          Object.assign(existingPayroll, payrollData);
          await existingPayroll.save();
        } else {
          // Create new
          await Payroll.create(payrollData);
        }
      } catch (bridgeErr) {
        logger.error("Error linking to Payroll record", {
          error: bridgeErr.message,
        });
        // Don't fail the request, just log
      }
      // ---------------------------------------------
    } else {
      logger.error("Employee user ID not found, cannot send notification");
    }

    // Notify HR room
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
      {
        requestId: payslipRequest._id,
        employee: payslipRequest.employee,
        processedBy: payslipRequest.processedBy,
        status: payslipRequest.status,
        processedAt: payslipRequest.processedAt,
      },
    );
    res.status(200).json({
      message: "Payslip processed successfully",
      data: payslipRequest,
    });
  } catch (err) {
    logger.error("Error processing payslip with base pay", {
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Download payslip PDF
 */
exports.downloadPayslipPDF = async (req, res) => {
  try {
    const { requestId } = req.params;
    const userId = req.userId;

    // Find payslip request
    const payslipRequest = await PayslipRequest.findById(requestId)
      .populate(
        "employee",
        "name email employeeId user subOrganisation jobTitle joinDate",
      )
      .populate("processedBy", "name email");

    if (!payslipRequest) {
      logger.error("Payslip request not found");
      return res.status(404).json({ message: "Payslip request not found" });
    }

    // Check if user has permission (employee can only download their own, HR/Admin can download any)
    const employeeUserId = payslipRequest.employee?.user?.toString();
    const isEmployee = employeeUserId === userId?.toString();

    // Find user role
    const User = require("../models/user.model");
    const user = await User.findById(userId);
    const isHrOrAdmin = user && (user.role === "hr" || user.role === "admin");

    if (!isEmployee && !isHrOrAdmin) {
      logger.error("Unauthorized access to download payslip");
      return res
        .status(403)
        .json({ message: "Unauthorized to download this payslip" });
    }

    // Check if payslip is approved
    // Check expiry if set
    if (
      payslipRequest.payslipExpiry &&
      new Date() > new Date(payslipRequest.payslipExpiry)
    ) {
      logger.error("Payslip link expired");
      return res
        .status(410)
        .json({ message: "Payslip download link has expired" });
    }

    if (
      payslipRequest.status !== "approved" &&
      payslipRequest.status !== "completed"
    ) {
      logger.error("Payslip not approved");
      return res.status(400).json({ message: "Payslip is not approved yet" });
    }

    // --- HEALING LOGIC: Fix historical records with missing Conveyance ---
    const cf = payslipRequest.calculatedFields || {};
    const basicPay = cf.basicPay || 0;

    if (basicPay > 0) {
      const standardHRA = Math.round(basicPay * 0.575);
      const standardConveyance = Math.round(basicPay * 0.275);
      const currentHRA = cf.hra || 0;
      const currentConveyance = cf.conveyance || 0;
      let healed = false;

      // Heal HRA
      if (!currentHRA || currentHRA === 0) {
        cf.hra = standardHRA;
        healed = true;
      }
      // Heal Conveyance
      if (!currentConveyance || currentConveyance === 0) {
        cf.conveyance = standardConveyance;
        healed = true;
      }

      if (healed) {
        // console.log(`[Download] Healed record ${payslipRequest._id}: HRA=${cf.hra}, Conv=${cf.conveyance}`);
        payslipRequest.calculatedFields = cf;

        // Recalculate Net Salary for display
        const totalEarnings =
          (cf.basicPay || 0) +
          (cf.hra || 0) +
          (cf.conveyance || 0) +
          (cf.specialAllowance || 0);
        const totalDeductions =
          (payslipRequest.deductions?.pf || 0) +
          (payslipRequest.deductions?.esi || 0) +
          (payslipRequest.deductions?.pt || 0) +
          (payslipRequest.deductions?.lop || 0) +
          (payslipRequest.deductions?.penalty || 0);

        payslipRequest.calculatedFields.netSalary =
          totalEarnings + (payslipRequest.bonus || 0) - totalDeductions;
      }
    }
    // -------------------------------------------------------------------

    const payslipGenerator = require("../services/payslip-generator.service");
    let pdfBuffer = null;
    try {
      pdfBuffer = await payslipGenerator.generatePayslipPDF(payslipRequest);
    } catch (genErr) {
      logger.error("PDF generation error", { error: genErr.message });
    }

    if (pdfBuffer && pdfBuffer.length > 0) {
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="payslip_${requestId}.pdf"`,
      );
      return res.send(pdfBuffer);
    }

    // fallback JSON
    res.status(200).json({
      message: "PDF generation failed, returning data as JSON",
      payslip: {
        requestId: payslipRequest._id,
        employee: payslipRequest.employee,
        period: `${payslipRequest.startMonth} ${payslipRequest.startYear} - ${payslipRequest.endMonth} ${payslipRequest.endYear}`,
        basePay: payslipRequest.basePay,
        calculatedFields: payslipRequest.calculatedFields,
        deductions: payslipRequest.deductions,
        payslipDetails: payslipRequest.payslipDetails,
        netSalary: payslipRequest.calculatedFields?.netSalary,
        status: payslipRequest.status,
        processedAt: payslipRequest.processedAt,
      },
    });
  } catch (err) {
    logger.error("Error in payslip download", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get payslip approval history for HR
 */
exports.getPayslipApprovalHistory = async (req, res) => {
  try {
    const hrUserId = req.userId;
    const { page = 1, limit = 20, employeeName } = req.query;

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Build query for approved/completed/rejected payslips
    const query = {
      status: { $in: ["approved", "completed", "rejected"] },
      processedBy: { $exists: true },
      processedAt: { $exists: true },
    };

    // Get approved payslips with populated data first
    let history = await PayslipRequest.find(query)
      .populate("employee", "name email employeeId")
      .populate("processedBy", "name email")
      .sort({ processedAt: -1 });

    // Filter by employee name if provided
    if (employeeName) {
      const searchName = employeeName.toLowerCase();
      history = history.filter((request) => {
        const employeeName = request.employee?.name?.toLowerCase() || "";
        return employeeName.includes(searchName);
      });
    }

    // Apply pagination after filtering
    const total = history.length;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    history = history.slice(skip, skip + parseInt(limit));

    // Format the response
    const formattedHistory = history.map((record) => {
      const recordObj = record.toObject();

      // --- HEALING LOGIC: Fix historical records with missing Conveyance ---
      const cf = recordObj.calculatedFields || {};
      const basicPay = cf.basicPay || 0;

      if (basicPay > 0) {
        const standardHRA = Math.round(basicPay * 0.575);
        const standardConveyance = Math.round(basicPay * 0.275);
        const currentHRA = cf.hra || 0;
        const currentConveyance = cf.conveyance || 0;
        let healed = false;

        // Heal HRA
        if (!currentHRA || currentHRA === 0) {
          cf.hra = standardHRA;
          healed = true;
        }
        // Heal Conveyance
        if (!currentConveyance || currentConveyance === 0) {
          cf.conveyance = standardConveyance;
          healed = true;
        }

        if (healed) {
          // console.log(`[History] Healed record ${recordObj._id}: HRA=${cf.hra}, Conv=${cf.conveyance}`);
          recordObj.calculatedFields = cf;

          // Recalculate Net Salary for display
          const totalEarnings =
            (cf.basicPay || 0) +
            (cf.hra || 0) +
            (cf.conveyance || 0) +
            (cf.specialAllowance || 0);
          const totalDeductions =
            (recordObj.deductions?.pf || 0) +
            (recordObj.deductions?.esi || 0) +
            (recordObj.deductions?.pt || 0) +
            (recordObj.deductions?.lop || 0) +
            (recordObj.deductions?.penalty || 0);

          recordObj.calculatedFields.netSalary =
            totalEarnings + (recordObj.bonus || 0) - totalDeductions;
        }
      }

      return {
        ...recordObj,
        processedDate: record.processedAt.toISOString().split("T")[0],
        processedTime: record.processedAt
          .toISOString()
          .split("T")[1]
          .split(".")[0],
      };
    });

    const response = {
      history: formattedHistory,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    };

    res.status(200).json(response);
  } catch (err) {
    logger.error("Error getting payslip approval history", {
      error: err.message,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Preview payslip PDF without saving
 */
exports.previewPayslip = async (req, res) => {
  try {
    const { requestId } = req.params;
    const {
      basePay,
      bonus = 0,
      calculatedFields = {},
      deductions = {},
      payslipDetails = {},
    } = req.body;

    // Find payslip request and populate employee
    const payslipRequest = await PayslipRequest.findById(requestId).populate(
      "employee",
      "name email employeeId subOrganisation jobTitle joinDate",
    );
    if (!payslipRequest) {
      return res.status(404).json({ message: "Payslip request not found" });
    }

    // Construct a temporary object with the updated data for PDF generation
    // Only override if new value is provided in body
    const previewData = {
      ...payslipRequest.toObject(),
      basePay: basePay ?? payslipRequest.basePay,
      bonus: bonus ?? payslipRequest.bonus,
      calculatedFields:
        Object.keys(calculatedFields).length > 0
          ? calculatedFields
          : payslipRequest.calculatedFields,
      deductions:
        Object.keys(deductions).length > 0
          ? deductions
          : payslipRequest.deductions,
      payslipDetails:
        Object.keys(payslipDetails).length > 0
          ? payslipDetails
          : payslipRequest.payslipDetails,
      startMonth: payslipRequest.startMonth,
      startYear: payslipRequest.startYear,
      employee: payslipRequest.employee,
    };

    let currentBasic = previewData.calculatedFields?.basicPay || 0;
    let currentHRA = previewData.calculatedFields?.hra || 0;
    let currentConveyance = previewData.calculatedFields?.conveyance || 0;
    let currentSpecial = previewData.calculatedFields?.specialAllowance || 0;

    // Healing triggers
    if (currentBasic > 0) {
      const standardHRA = Math.round(currentBasic * 0.575);
      const standardConveyance = Math.round(currentBasic * 0.275);

      // Force update if zero or missing
      if (!currentHRA || currentHRA === 0) {
        currentHRA = standardHRA;
      }
      if (!currentConveyance || currentConveyance === 0) {
        currentConveyance = standardConveyance;
      }

      // Re-update calculatedFields in previewData
      previewData.calculatedFields = {
        ...previewData.calculatedFields,
        hra: currentHRA,
        conveyance: currentConveyance,
      };

      // Recalculate Net Salary implicitly to match visual table
      const totalEarnings =
        currentBasic + currentHRA + currentConveyance + currentSpecial;
      const totalDeductions =
        (previewData.deductions?.pf || 0) +
        (previewData.deductions?.esi || 0) +
        (previewData.deductions?.pt || 0) +
        (previewData.deductions?.lop || 0) +
        (previewData.deductions?.penalty || 0);

      const recalculatedNet =
        totalEarnings + (previewData.bonus || 0) - totalDeductions;

      previewData.calculatedFields.netSalary = recalculatedNet;
    }

    const PayslipGeneratorService = require("../services/payslip-generator.service");
    const pdfBuffer =
      await PayslipGeneratorService.generatePayslipPDF(previewData);

    // Return PDF stream
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `inline; filename=payslip_preview_${requestId}.pdf`,
    );
    res.send(pdfBuffer);
  } catch (err) {
    logger.error("CRITICAL ERROR generating payslip preview", {
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({
      message: err.message,
      stack: process.env.NODE_ENV === "development" ? err.stack : undefined,
    });
  }
};
