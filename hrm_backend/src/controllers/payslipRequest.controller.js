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

    // Create payslip request
    const payslipRequest = new PayslipRequest({
      employee: employeeProfile._id,
      startMonth,
      startYear,
      endMonth,
      endYear,
      reason: reason || "",
      status: "pending",
    });

    // Try to prefill payslip defaults from the latest payroll record for this employee
    try {
      const latestPayroll = await Payroll.findOne({
        employee: employeeProfile._id,
      })
        .sort({ payPeriod: -1 })
        .lean();
      console.log("📋 [PREFILL] Latest payroll for employee:", latestPayroll);
      if (latestPayroll) {
        // Copy relevant fields if available
        if (latestPayroll.totalPay !== undefined)
          payslipRequest.basePay = latestPayroll.totalPay;
        if (latestPayroll.calculatedFields)
          payslipRequest.calculatedFields = latestPayroll.calculatedFields;
        if (latestPayroll.deductions)
          payslipRequest.deductions = latestPayroll.deductions;
        if (latestPayroll.payslipDetails)
          payslipRequest.payslipDetails = latestPayroll.payslipDetails;
        console.log("✅ [PREFILL] Prefilled request with payroll data");
        console.log("📋 [PREFILL] Request after prefill:", {
          basePay: payslipRequest.basePay,
          calculatedFields: payslipRequest.calculatedFields,
          deductions: payslipRequest.deductions,
          payslipDetails: payslipRequest.payslipDetails,
        });
      } else {
        console.log("❌ [PREFILL] No payroll record found for employee");
      }
    } catch (e) {
      // Non-fatal: log and continue without prefilling
      console.error(
        "Error fetching latest payroll for prefilling payslip request:",
        e
      );
    }

    await payslipRequest.save();

    // Populate employee info
    await payslipRequest.populate("employee", "name email employeeId");

    // Emit WebSocket event for new payslip request
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
      }
    );

    // Also notify the employee who submitted the request
    websocketService.broadcastToUser(
      employeeUserId,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_CREATED,
      {
        requestId: payslipRequest._id,
        status: payslipRequest.status,
        message: "Your payslip request has been submitted successfully",
      }
    );

    res.status(201).json({
      message: "Payslip request submitted successfully",
      data: payslipRequest,
    });
  } catch (err) {
    console.error("Error submitting payslip request:", err);
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
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await PayslipRequest.countDocuments(query);

    if (requests.length > 0) {
    }

    // Format requests to include requestedDate
    const formattedRequests = requests.map((request) => {
      const requestObj = request.toObject();
      requestObj.requestedDate = request.createdAt.toISOString().split("T")[0]; // Format as YYYY-MM-DD
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
    console.error("Error getting employee payslip requests:", err);
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

    // Find HR profile
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      return res.status(404).json({ message: "HR profile not found" });
    }

    // Build query
    const query = {};
    if (status) {
      query.status = status;
    }

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get requests
    const requests = await PayslipRequest.find(query)
      .populate("employee", "name email employeeId")
      .populate("processedBy", "name email")
      .sort({ createdAt: -1 })
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
        let hasMeaningfulCalculated = false;
        if (requestObj.calculatedFields) {
          const vals = Object.values(requestObj.calculatedFields || {});
          hasMeaningfulCalculated = vals.some(
            (v) => typeof v === "number" && v > 0
          );
        }

        // Consider deductions meaningful only if at least one deduction > 0
        let hasMeaningfulDeductions = false;
        if (requestObj.deductions) {
          const vals = Object.values(requestObj.deductions || {});
          hasMeaningfulDeductions = vals.some(
            (v) => typeof v === "number" && v > 0
          );
        }

        // Consider payslipDetails meaningful if any string field is non-empty or numeric fields > 0
        let hasMeaningfulPayslipDetails = false;
        if (requestObj.payslipDetails) {
          const pd = requestObj.payslipDetails;
          hasMeaningfulPayslipDetails =
            (pd.pan && String(pd.pan).trim() !== "") ||
            (pd.bankName && String(pd.bankName).trim() !== "") ||
            (pd.accountNumber && String(pd.accountNumber).trim() !== "") ||
            (typeof pd.paidDays === "number" && pd.paidDays > 0) ||
            (typeof pd.lopDays === "number" && pd.lopDays > 0);
        }

        const needsAttach =
          !hasBasePay ||
          !hasMeaningfulCalculated ||
          !hasMeaningfulDeductions ||
          !hasMeaningfulPayslipDetails;

        if (needsAttach) {
          // Fetch latest payroll for the employee
          if (requestObj.employee && requestObj.employee._id) {
            const latestPayroll = await Payroll.findOne({
              employee: requestObj.employee._id,
            })
              .sort({ payPeriod: -1 })
              .lean();
            if (latestPayroll) {
              // Attach if missing or not meaningful
              if (!hasBasePay && latestPayroll.totalPay !== undefined) {
                requestObj.basePay = latestPayroll.totalPay;
                console.log(
                  "🔁 [GET-HR-REQUESTS] Attached basePay from latest payroll"
                );
              }
              if (
                (!hasMeaningfulCalculated || !requestObj.calculatedFields) &&
                latestPayroll.calculatedFields
              ) {
                requestObj.calculatedFields = latestPayroll.calculatedFields;
                console.log(
                  "🔁 [GET-HR-REQUESTS] Attached calculatedFields from latest payroll"
                );
              }
              if (
                (!hasMeaningfulDeductions ||
                  !requestObj.deductions ||
                  Object.keys(requestObj.deductions).length === 0) &&
                latestPayroll.deductions
              ) {
                requestObj.deductions = latestPayroll.deductions;
                console.log(
                  "🔁 [GET-HR-REQUESTS] Attached deductions from latest payroll"
                );
              }
              if (
                (!hasMeaningfulPayslipDetails || !requestObj.payslipDetails) &&
                latestPayroll.payslipDetails
              ) {
                requestObj.payslipDetails = latestPayroll.payslipDetails;
                console.log(
                  "🔁 [GET-HR-REQUESTS] Attached payslipDetails from latest payroll"
                );
              }
            }
          }
        }
      } catch (e) {
        console.error("Error attaching latest payroll to request", e);
      }

      console.log("📋 [GET-HR-REQUESTS] Request prefill data:", {
        requestId: requestObj._id,
        basePay: requestObj.basePay,
        calculatedFields: requestObj.calculatedFields,
        deductions: requestObj.deductions,
        payslipDetails: requestObj.payslipDetails,
      });

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
    console.error("Error getting HR payslip requests:", err);
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

    if (payslipUrl) {
      payslipRequest.payslipUrl = payslipUrl;
      // Set expiry to 3 days from now
      payslipRequest.payslipExpiry = new Date(
        Date.now() + 3 * 24 * 60 * 60 * 1000
      );
    } else if (status === "approved" || status === "completed") {
      // Ensure a downloadable URL exists for approved/completed payslips
      payslipRequest.payslipUrl = `/api/payslip-requests/${payslipRequest._id}/download`;
      // Set expiry to 3 days from now
      payslipRequest.payslipExpiry = new Date(
        Date.now() + 3 * 24 * 60 * 60 * 1000
      );
    }

    if (rejectionReason) {
      payslipRequest.rejectionReason = rejectionReason;
    }

    await payslipRequest.save();

    // Populate the updated request
    await payslipRequest.populate("employee", "name email employeeId");
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
      // Notify HR room about approval
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.HR_ROOM,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
        eventData
      );

      // Notify the employee
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
        }
      );

      // Emit payslip generated event if URL is provided
      if (payslipUrl) {
        websocketService.broadcastToUser(
          payslipRequest.employee.user,
          WEBSOCKET_EVENTS.PAYSLIP_GENERATED,
          {
            requestId: payslipRequest._id,
            payslipUrl: payslipUrl,
            message:
              "Your payslip has been generated and is ready for download",
          }
        );
      }
    } else if (status === "rejected") {
      // Notify HR room about rejection
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.HR_ROOM,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_REJECTED,
        eventData
      );

      // Notify the employee
      websocketService.broadcastToUser(
        payslipRequest.employee.user,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_REJECTED,
        {
          requestId: payslipRequest._id,
          status: payslipRequest.status,
          rejectionReason: payslipRequest.rejectionReason,
          message: "Your payslip request has been rejected",
        }
      );
    }

    res.status(200).json({
      message: "Payslip request status updated successfully",
      data: payslipRequest,
    });
  } catch (err) {
    console.error("Error updating payslip request status:", err);
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
    console.error("Error getting payslip request stats:", err);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Process payslip request with base pay (HR)
 * HR fills base pay, system auto-calculates other fields
 */
exports.processPayslipWithBasePay = async (req, res) => {
  try {
    console.log("📋 [PAYSLIP] ====== Processing Payslip Request ======");
    const { requestId } = req.params;
    const {
      basePay,
      bonus = 0,
      calculatedFields = {},
      deductions = {},
      payslipDetails = {},
    } = req.body;
    const hrUserId = req.userId;

    console.log("📋 [PAYSLIP] RequestId:", requestId);
    console.log("📋 [PAYSLIP] HR UserId:", hrUserId);
    console.log("📋 [PAYSLIP] BasePay:", basePay);
    console.log(
      "📋 [PAYSLIP] Request Body:",
      JSON.stringify(req.body, null, 2)
    );

    if (!basePay || basePay <= 0) {
      console.error("❌ [PAYSLIP] Base pay validation failed");
      return res.status(400).json({
        message: "Base pay is required and must be greater than 0",
      });
    }

    // Find HR profile
    console.log("📋 [PAYSLIP] Finding HR profile...");
    const hrProfile = await HR.findOne({ user: hrUserId });
    if (!hrProfile) {
      console.error("❌ [PAYSLIP] HR profile not found for userId:", hrUserId);
      return res.status(404).json({ message: "HR profile not found" });
    }
    console.log("✅ [PAYSLIP] HR profile found:", hrProfile._id);

    // Find payslip request and populate employee with user field
    console.log("📋 [PAYSLIP] Finding payslip request...");
    const payslipRequest = await PayslipRequest.findById(requestId).populate(
      "employee",
      "name email employeeId user"
    );
    if (!payslipRequest) {
      console.error("❌ [PAYSLIP] Payslip request not found:", requestId);
      return res.status(404).json({ message: "Payslip request not found" });
    }
    console.log("✅ [PAYSLIP] Payslip request found:", payslipRequest._id);
    console.log("📋 [PAYSLIP] Employee:", payslipRequest.employee);
    console.log(
      "📋 [PAYSLIP] Employee user ID:",
      payslipRequest.employee?.user
    );

    // Use provided calculatedFields if available, otherwise calculate from basePay
    let basicPay, hra, specialAllowance, netSalary;

    if (
      calculatedFields.basicPay !== undefined &&
      calculatedFields.hra !== undefined
    ) {
      // Use provided values from frontend (old payroll format)
      basicPay = calculatedFields.basicPay || 0;
      hra = calculatedFields.hra || 0;
      specialAllowance = calculatedFields.specialAllowance || 0;
      // Use provided netSalary if available and valid, otherwise calculate it
      if (
        calculatedFields.netSalary !== undefined &&
        calculatedFields.netSalary !== null &&
        calculatedFields.netSalary > 0
      ) {
        netSalary = calculatedFields.netSalary;
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
          specialAllowance +
          (bonus || 0) -
          totalDeductionsCalc;
      }
    } else {
      // Calculate fields based on base pay (new format)
      // Standard breakdown: Basic Pay (65%), HRA (25%), Special Allowance (10%)
      basicPay = basePay;
      hra = 0;
      specialAllowance = 0;

      // --- DYNAMIC PENALTY CALCULATION ---
      let calculatedPenalty = 0;
      if (payslipRequest.startMonth && payslipRequest.startYear) {
        calculatedPenalty = await payrollService.calculateDynamicPenalty(
          payslipRequest.employee.user,
          payslipRequest.startMonth,
          payslipRequest.startYear,
          basePay
        );
      }

      // Calculate total deductions (include existing user-provided penalty OR calculated one)
      // Logic: If user provided a specific penalty in 'deductions', use that.
      // Otherwise, add calculated penalty to existing deductions.
      // --- STANDARD DEDUCTIONS (PT, etc) ---
      const standardDeductions = payrollService.calculateDeductions();

      // Use provided penalty or calculated one
      const providedPenalty = deductions.penalty || 0;
      const finalPenalty =
        providedPenalty > 0 ? providedPenalty : calculatedPenalty;

      // Use provided PT or standard PT
      const finalPT =
        deductions.pt !== undefined && deductions.pt !== null
          ? deductions.pt
          : standardDeductions.pt;

      // Combine all deductions
      const totalDeductions =
        (deductions.pf || 0) +
        (deductions.esi || 0) +
        finalPT +
        (deductions.lop || 0) +
        finalPenalty;

      // Update deductions object to save back
      deductions.penalty = finalPenalty;
      deductions.pt = finalPT;

      // Net salary = base pay + bonus - deductions
      netSalary = basePay + (bonus || 0) - totalDeductions;
    }

    // Calculate total deductions
    const totalDeductions =
      (deductions.pf || 0) +
      (deductions.esi || 0) +
      (deductions.pt || 0) +
      (deductions.lop || 0) +
      (deductions.penalty || 0);

    // Update net salary if not provided or if deductions changed
    if (calculatedFields.netSalary === undefined) {
      // Net Salary = (Basic Pay + HRA + Special Allowance) + Bonus - Total Deductions
      netSalary =
        basicPay +
        hra +
        (specialAllowance || 0) +
        (bonus || 0) -
        totalDeductions;
    }

    // Update request with calculated fields
    payslipRequest.basePay = basePay;
    payslipRequest.calculatedFields = {
      basicPay: basicPay,
      hra: hra,
      specialAllowance: specialAllowance || 0,
      netSalary: netSalary,
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

    payslipRequest.status = "approved";
    payslipRequest.processedBy = hrProfile._id;
    payslipRequest.processedAt = new Date();

    // Generate payslip URL for download
    // Format: /api/payslip-requests/:requestId/download
    payslipRequest.payslipUrl = `/api/payslip-requests/${payslipRequest._id}/download`;
    console.log(
      "📋 [PAYSLIP] Generated payslip URL:",
      payslipRequest.payslipUrl
    );

    console.log("💾 [PAYSLIP] Saving payslip request to database...");
    await payslipRequest.save();
    console.log("✅ [PAYSLIP] Payslip request saved successfully");

    // Populate the updated request
    console.log("📋 [PAYSLIP] Populating employee and processedBy...");
    await payslipRequest.populate(
      "employee",
      "name email employeeId user jobTitle joinDate"
    );
    await payslipRequest.populate("processedBy", "name email");
    console.log("✅ [PAYSLIP] Employee populated:", payslipRequest.employee);
    console.log(
      "📋 [PAYSLIP] Employee user ID:",
      payslipRequest.employee?.user
    );

    // Notify the employee
    const employeeUserId = payslipRequest.employee?.user;
    if (employeeUserId) {
      console.log(
        "📤 [PAYSLIP] Sending notification to employee:",
        employeeUserId
      );
      const notificationData = {
        requestId: payslipRequest._id.toString(),
        status: payslipRequest.status,
        message: "Payslip Accepted",
        type: "payslip_approved",
        title: "Payslip Accepted",
        payslipUrl: payslipRequest.payslipUrl,
        payslipExpiry: payslipRequest.payslipExpiry,
      };
      console.log(
        "📤 [PAYSLIP] Notification data:",
        JSON.stringify(notificationData, null, 2)
      );

      websocketService.broadcastToUser(
        employeeUserId,
        WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
        notificationData
      );
      console.log("✅ [PAYSLIP] Notification sent to employee");
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
          }
        );
        console.log("✅ [PAYSLIP] Payslip generated event sent to employee");
      }
    } else {
      console.error(
        "❌ [PAYSLIP] Employee user ID not found, cannot send notification"
      );
    }

    // Notify HR room
    console.log("📤 [PAYSLIP] Broadcasting to HR room...");
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
      {
        requestId: payslipRequest._id,
        employee: payslipRequest.employee,
        processedBy: payslipRequest.processedBy,
        status: payslipRequest.status,
        processedAt: payslipRequest.processedAt,
      }
    );
    console.log("✅ [PAYSLIP] Broadcasted to HR room");

    console.log("✅ [PAYSLIP] ====== Payslip Processing Complete ======");
    res.status(200).json({
      message: "Payslip processed successfully",
      data: payslipRequest,
    });
  } catch (err) {
    console.error("❌ [PAYSLIP] Error processing payslip with base pay:", err);
    console.error("❌ [PAYSLIP] Error stack:", err.stack);
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Download payslip PDF
 */
exports.downloadPayslipPDF = async (req, res) => {
  try {
    console.log("📥 [PAYSLIP-DOWNLOAD] ====== Download Payslip PDF ======");
    const { requestId } = req.params;
    const userId = req.userId;

    console.log("📥 [PAYSLIP-DOWNLOAD] RequestId:", requestId);
    console.log("📥 [PAYSLIP-DOWNLOAD] UserId:", userId);

    // Find payslip request
    const payslipRequest = await PayslipRequest.findById(requestId)
      .populate(
        "employee",
        "name email employeeId user subOrganisation jobTitle joinDate"
      )
      .populate("processedBy", "name email");

    if (!payslipRequest) {
      console.error("❌ [PAYSLIP-DOWNLOAD] Payslip request not found");
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
      console.error("❌ [PAYSLIP-DOWNLOAD] Unauthorized access");
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
      console.error("❌ [PAYSLIP-DOWNLOAD] Payslip link expired");
      return res
        .status(410)
        .json({ message: "Payslip download link has expired" });
    }

    if (
      payslipRequest.status !== "approved" &&
      payslipRequest.status !== "completed"
    ) {
      console.error("❌ [PAYSLIP-DOWNLOAD] Payslip not approved");
      return res.status(400).json({ message: "Payslip is not approved yet" });
    }

    console.log(
      "✅ [PAYSLIP-DOWNLOAD] Generating PDF with organization-specific template..."
    );

    const payslipGenerator = require("../services/payslip-generator.service");
    let pdfBuffer = null;
    try {
      pdfBuffer = await payslipGenerator.generatePayslipPDF(payslipRequest);
    } catch (genErr) {
      console.error("❌ [PAYSLIP] PDF generation error", genErr);
    }

    if (pdfBuffer && pdfBuffer.length > 0) {
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="payslip_${requestId}.pdf"`
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

    // TODO: When PDF generation is implemented, use:
    // const pdfBuffer = await generatePayslipPDF(payslipRequest);
    // res.setHeader('Content-Type', 'application/pdf');
    // res.setHeader('Content-Disposition', `attachment; filename="payslip_${requestId}.pdf"`);
    // res.send(pdfBuffer);

    console.log("✅ [PAYSLIP-DOWNLOAD] ====== Download Complete ======");
  } catch (err) {
    console.error("❌ [PAYSLIP-DOWNLOAD] Error:", err);
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
    console.error("Error getting payslip approval history:", err);
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
      "name email employeeId subOrganisation jobTitle joinDate"
    );
    if (!payslipRequest) {
      return res.status(404).json({ message: "Payslip request not found" });
    }

    // Construct a temporary object with the updated data for PDF generation
    const previewData = {
      ...payslipRequest.toObject(),
      basePay,
      bonus,
      calculatedFields,
      deductions,
      payslipDetails,
      startMonth: payslipRequest.startMonth,
      startYear: payslipRequest.startYear,
      employee: payslipRequest.employee, // Ensure employee data is present
    };

    // Generate PDF
    const PayslipGeneratorService = require("../services/payslip-generator.service");
    const pdfBuffer = await PayslipGeneratorService.generatePayslipPDF(
      previewData
    );

    // Return PDF stream
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `inline; filename=payslip_preview_${requestId}.pdf`
    );
    res.send(pdfBuffer);
  } catch (err) {
    console.error("Error generating payslip preview:", err);
    res.status(500).json({ message: err.message });
  }
};
