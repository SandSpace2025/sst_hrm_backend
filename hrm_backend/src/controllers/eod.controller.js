const EOD = require("../models/eod.model");
const Employee = require("../models/employee.model");
const moment = require("moment-timezone");
const logger = require("../core/logger");

// Helper function to get current IST time
const getISTTime = () => {
  return moment().tz("Asia/Kolkata");
};

// Helper function to get start of day in IST
const getISTDayStart = (date = null) => {
  if (date) {
    return moment(date).tz("Asia/Kolkata").startOf("day").toDate();
  }
  return moment().tz("Asia/Kolkata").startOf("day").toDate();
};

// Helper function to get end of day in IST
const getISTDayEnd = (date = null) => {
  if (date) {
    return moment(date).tz("Asia/Kolkata").endOf("day").toDate();
  }
  return moment().tz("Asia/Kolkata").endOf("day").toDate();
};

/**
 * @description Create/Submit EOD (Employee only, after 6:45 PM IST)
 */
exports.createEOD = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const {
      // Legacy fields
      project,
      tasksCompleted,
      challenges,
      nextDayPlan,
      // Enhanced fields
      projectName,
      taskDoneToday,
      challengesFaced,
      studentName,
      technology,
      taskType,
      projectStatus,
      deadline,
      daysTaken,
      reportSent,
      personWorkingOnReport,
      reportStatus,
    } = req.body;

    // Validate enhanced required fields
    const missingFields = [];
    if (!projectName || projectName.trim() === "")
      missingFields.push("projectName");
    if (!taskDoneToday || taskDoneToday.trim() === "")
      missingFields.push("taskDoneToday");
    if (!technology || technology.trim() === "")
      missingFields.push("technology");
    if (!taskType || taskType.trim() === "") missingFields.push("taskType");
    if (projectStatus === undefined || projectStatus === null)
      missingFields.push("projectStatus");
    if (!deadline) missingFields.push("deadline");
    if (!reportStatus || reportStatus.trim() === "")
      missingFields.push("reportStatus");

    if (missingFields.length > 0) {
      return res.status(400).json({
        message: `Missing required fields: ${missingFields.join(", ")}`,
        missingFields: missingFields,
      });
    }

    // Validate projectStatus is between 0 and 100
    if (
      typeof projectStatus !== "number" ||
      projectStatus < 0 ||
      projectStatus > 100
    ) {
      return res.status(400).json({
        message: "projectStatus must be a number between 0 and 100",
      });
    }

    // Validate deadline is a valid date
    const deadlineDate = new Date(deadline);
    if (isNaN(deadlineDate.getTime())) {
      return res.status(400).json({
        message: "deadline must be a valid date",
      });
    }

    // Ensure legacy fields are populated for backward compatibility
    const legacyProject = project || projectName || "Project work";
    const legacyTasksCompleted =
      tasksCompleted || taskDoneToday || "Tasks completed today";
    const legacyChallenges = challenges || challengesFaced || "No challenges";
    const legacyNextDayPlan = nextDayPlan || "Work on upcoming tasks";

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Get today's date in IST (but store as date string to avoid timezone conversion)
    const currentIST = getISTTime();
    const todayDateString = currentIST.format("YYYY-MM-DD");

    // Create a date object for the EOD date (this will be stored correctly)
    const eodDate = new Date(todayDateString + "T00:00:00.000Z");

    // Check if EOD already exists for today
    const existingEOD = await EOD.findOne({
      employee: employeeProfile._id,
      date: {
        $gte: new Date(todayDateString + "T00:00:00.000Z"),
        $lt: new Date(todayDateString + "T23:59:59.999Z"),
      },
    });

    if (existingEOD) {
      return res.status(409).json({
        message:
          "EOD for today has already been submitted. You can update it instead.",
        eod: existingEOD,
      });
    }

    // Create new EOD
    const newEOD = new EOD({
      employee: employeeProfile._id,
      date: eodDate,
      // Legacy fields (for backward compatibility)
      project: legacyProject,
      tasksCompleted: legacyTasksCompleted,
      challenges: legacyChallenges,
      nextDayPlan: legacyNextDayPlan,
      // Enhanced fields
      projectName: projectName.trim(),
      taskDoneToday: taskDoneToday.trim(),
      challengesFaced: challengesFaced ? challengesFaced.trim() : "",
      studentName: studentName ? studentName.trim() : "",
      technology: technology.trim(),
      taskType: taskType.trim(),
      projectStatus: projectStatus,
      deadline: deadlineDate,
      daysTaken: daysTaken || 0, // Default to 0 if not provided
      reportSent: reportSent || false,
      personWorkingOnReport: personWorkingOnReport
        ? personWorkingOnReport.trim()
        : "",
      reportStatus: reportStatus.trim(),
      submittedAt: new Date(),
    });

    await newEOD.save();

    res.status(201).json({
      message: "EOD submitted successfully",
      eod: newEOD,
    });
  } catch (err) {
    logger.error("Error creating EOD", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    if (err.code === 11000) {
      return res.status(409).json({
        message: "EOD for today has already been submitted",
      });
    }
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get today's EOD for employee
 */
exports.getTodayEOD = async (req, res) => {
  try {
    const employeeUserId = req.userId;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Get today's date in IST
    const currentIST = getISTTime();
    const todayDateString = currentIST.format("YYYY-MM-DD");

    // Find today's EOD using the same date logic
    const todayEOD = await EOD.findOne({
      employee: employeeProfile._id,
      date: {
        $gte: new Date(todayDateString + "T00:00:00.000Z"),
        $lt: new Date(todayDateString + "T23:59:59.999Z"),
      },
    });

    if (!todayEOD) {
      return res.status(404).json({
        message: "No EOD submitted for today",
        canSubmit: true,
      });
    }

    res.status(200).json({
      eod: todayEOD,
      canEdit: true, // Same day editing allowed
    });
  } catch (err) {
    logger.error("Error getting today's EOD", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get all EODs for employee (with pagination)
 */
exports.getMyEODs = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { page = 1, limit = 20, startDate, endDate } = req.query;
    const skip = (page - 1) * limit;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Build query
    let query = { employee: employeeProfile._id };

    // Add date range filter if provided
    if (startDate || endDate) {
      query.date = {};
      if (startDate) {
        query.date.$gte = getISTDayStart(new Date(startDate));
      }
      if (endDate) {
        // Use $lt instead of $lte since frontend sends next day as endDate
        query.date.$lt = new Date(endDate);
      }
    }

    // Fetch EODs
    const eods = await EOD.find(query)
      .sort({ date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await EOD.countDocuments(query);

    res.status(200).json({
      eods,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting EODs", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Update EOD (only same day, before midnight IST)
 */
exports.updateEOD = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { eodId } = req.params;
    const {
      // Legacy fields
      project,
      tasksCompleted,
      challenges,
      nextDayPlan,
      // Enhanced fields
      projectName,
      taskDoneToday,
      challengesFaced,
      studentName,
      technology,
      taskType,
      projectStatus,
      deadline,
      daysTaken,
      reportSent,
      personWorkingOnReport,
      reportStatus,
    } = req.body;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Find EOD
    const eod = await EOD.findById(eodId);
    if (!eod) {
      return res.status(404).json({ message: "EOD not found" });
    }

    // Verify ownership
    if (eod.employee.toString() !== employeeProfile._id.toString()) {
      return res.status(403).json({
        message: "Unauthorized to update this EOD",
      });
    }

    // Check if EOD is from today (same day editing only)
    const currentIST = getISTTime();
    const todayDateString = currentIST.format("YYYY-MM-DD");
    const eodDate = new Date(eod.date);
    const eodDateString = moment(eodDate)
      .tz("Asia/Kolkata")
      .format("YYYY-MM-DD");

    const isSameDay = eodDateString === todayDateString;

    if (!isSameDay) {
      return res.status(403).json({
        message: "You can only edit today's EOD. Past EODs are read-only.",
      });
    }

    // Validate enhanced required fields (frontend sends all fields on update)
    const missingFields = [];
    const finalProjectName =
      projectName !== undefined ? projectName : eod.projectName;
    const finalTaskDoneToday =
      taskDoneToday !== undefined ? taskDoneToday : eod.taskDoneToday;
    const finalStudentName =
      studentName !== undefined ? studentName : eod.studentName || "";
    const finalTechnology =
      technology !== undefined ? technology : eod.technology;
    const finalTaskType = taskType !== undefined ? taskType : eod.taskType;
    const finalProjectStatus =
      projectStatus !== undefined ? projectStatus : eod.projectStatus;
    const finalDeadline = deadline !== undefined ? deadline : eod.deadline;
    const finalDaysTaken =
      daysTaken !== undefined ? daysTaken : eod.daysTaken || 0;
    const finalReportStatus =
      reportStatus !== undefined ? reportStatus : eod.reportStatus;

    if (
      !finalProjectName ||
      (typeof finalProjectName === "string" &&
        finalProjectName.trim() === "") ||
      (typeof finalProjectName !== "string" && !finalProjectName)
    ) {
      missingFields.push("projectName");
    }
    if (
      !finalTaskDoneToday ||
      (typeof finalTaskDoneToday === "string" &&
        finalTaskDoneToday.trim() === "") ||
      (typeof finalTaskDoneToday !== "string" && !finalTaskDoneToday)
    ) {
      missingFields.push("taskDoneToday");
    }
    if (
      !finalTechnology ||
      (typeof finalTechnology === "string" && finalTechnology.trim() === "") ||
      (typeof finalTechnology !== "string" && !finalTechnology)
    ) {
      missingFields.push("technology");
    }
    if (
      !finalTaskType ||
      (typeof finalTaskType === "string" && finalTaskType.trim() === "") ||
      (typeof finalTaskType !== "string" && !finalTaskType)
    ) {
      missingFields.push("taskType");
    }
    if (finalProjectStatus === undefined || finalProjectStatus === null)
      missingFields.push("projectStatus");
    if (!finalDeadline) missingFields.push("deadline");
    if (
      !finalReportStatus ||
      (typeof finalReportStatus === "string" &&
        finalReportStatus.trim() === "") ||
      (typeof finalReportStatus !== "string" && !finalReportStatus)
    ) {
      missingFields.push("reportStatus");
    }

    if (missingFields.length > 0) {
      return res.status(400).json({
        message: `Missing required fields: ${missingFields.join(", ")}`,
        missingFields: missingFields,
      });
    }

    // Validate projectStatus is between 0 and 100
    if (
      typeof finalProjectStatus !== "number" ||
      finalProjectStatus < 0 ||
      finalProjectStatus > 100
    ) {
      return res.status(400).json({
        message: "projectStatus must be a number between 0 and 100",
      });
    }

    // Validate deadline is a valid date
    const deadlineDate = new Date(finalDeadline);
    if (isNaN(deadlineDate.getTime())) {
      return res.status(400).json({
        message: "deadline must be a valid date",
      });
    }

    // Update legacy fields (for backward compatibility)
    const finalChallengesFaced =
      challengesFaced !== undefined
        ? (challengesFaced || "").trim()
        : eod.challengesFaced || "";
    const finalProjectNameStr =
      typeof finalProjectName === "string"
        ? finalProjectName.trim()
        : String(finalProjectName || "");
    const finalStudentNameStr =
      typeof finalStudentName === "string"
        ? finalStudentName.trim()
        : String(finalStudentName || "");
    const finalTechnologyStr =
      typeof finalTechnology === "string"
        ? finalTechnology.trim()
        : String(finalTechnology || "");
    const finalTaskTypeStr =
      typeof finalTaskType === "string"
        ? finalTaskType.trim()
        : String(finalTaskType || "");
    const finalReportStatusStr =
      typeof finalReportStatus === "string"
        ? finalReportStatus.trim()
        : String(finalReportStatus || "");

    eod.project = project || finalProjectNameStr || "Project work";
    eod.tasksCompleted =
      tasksCompleted || taskDoneTodayStr || "Tasks completed today";
    eod.challenges =
      challenges !== undefined
        ? challenges
        : finalChallengesFaced || "No challenges";
    eod.nextDayPlan = nextDayPlan || "Work on upcoming tasks";

    // Update enhanced fields
    eod.projectName = finalProjectNameStr;
    eod.taskDoneToday = taskDoneTodayStr;
    eod.challengesFaced = finalChallengesFaced;
    eod.studentName = finalStudentNameStr;
    eod.technology = finalTechnologyStr;
    eod.taskType = finalTaskTypeStr;
    eod.projectStatus = finalProjectStatus;
    eod.deadline = deadlineDate;
    eod.daysTaken = finalDaysTaken;
    if (reportSent !== undefined) eod.reportSent = reportSent;
    eod.personWorkingOnReport =
      personWorkingOnReport !== undefined
        ? (personWorkingOnReport || "").trim()
        : eod.personWorkingOnReport || "";
    eod.reportStatus = finalReportStatusStr;

    await eod.save();

    res.status(200).json({
      message: "EOD updated successfully",
      eod,
    });
  } catch (err) {
    logger.error("Error updating EOD", {
      error: err.message,
      stack: err.stack,
      eodId: req.params.eodId,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Delete EOD (only same day, before midnight IST)
 */
exports.deleteEOD = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { eodId } = req.params;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Find EOD
    const eod = await EOD.findById(eodId);
    if (!eod) {
      return res.status(404).json({ message: "EOD not found" });
    }

    // Verify ownership
    if (eod.employee.toString() !== employeeProfile._id.toString()) {
      return res.status(403).json({
        message: "Unauthorized to delete this EOD",
      });
    }

    // Check if EOD is from today (same day deletion only)
    const currentIST = getISTTime();
    const todayDateString = currentIST.format("YYYY-MM-DD");
    const eodDate = new Date(eod.date);
    const eodDateString = moment(eodDate)
      .tz("Asia/Kolkata")
      .format("YYYY-MM-DD");

    const isSameDay = eodDateString === todayDateString;

    if (!isSameDay) {
      return res.status(403).json({
        message:
          "You can only delete today's EOD. Past EODs cannot be deleted.",
      });
    }

    await EOD.findByIdAndDelete(eodId);

    res.status(200).json({
      message: "EOD deleted successfully",
    });
  } catch (err) {
    logger.error("Error deleting EOD", {
      error: err.message,
      stack: err.stack,
      eodId: req.params.eodId,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get all EODs (Admin/HR only)
 */
exports.getAllEODs = async (req, res) => {
  try {
    const { page = 1, limit = 20, startDate, endDate, status } = req.query;
    const skip = (page - 1) * limit;

    // Build query
    let query = {};

    // Filter by status if provided (pending, approved, etc.)
    if (status) {
      // Handle case-insensitive status matching
      query.reportStatus = { $regex: new RegExp(`^${status}$`, "i") };
    }

    // Add date range filter if provided
    if (startDate || endDate) {
      query.date = {};
      if (startDate) {
        query.date.$gte = getISTDayStart(new Date(startDate));
      }
      if (endDate) {
        query.date.$lte = getISTDayEnd(new Date(endDate));
      }
    }

    // Fetch EODs
    const eods = await EOD.find(query)
      .populate("employee", "name email employeeId jobTitle")
      .sort({ date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await EOD.countDocuments(query);

    res.status(200).json({
      eods,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting all EODs", {
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get EODs for specific employee (Admin/HR only)
 */
exports.getEmployeeEODs = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { page = 1, limit = 20, startDate, endDate } = req.query;
    const skip = (page - 1) * limit;

    // Verify employee exists
    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Build query
    let query = { employee: employeeId };

    // Add date range filter if provided
    if (startDate || endDate) {
      query.date = {};
      if (startDate) {
        query.date.$gte = getISTDayStart(new Date(startDate));
      }
      if (endDate) {
        query.date.$lte = getISTDayEnd(new Date(endDate));
      }
    }

    // Fetch EODs
    const eods = await EOD.find(query)
      .populate("employee", "name email employeeId jobTitle")
      .sort({ date: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await EOD.countDocuments(query);

    res.status(200).json({
      eods,
      employee: {
        name: employee.name,
        email: employee.email,
        employeeId: employee.employeeId,
      },
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / limit),
    });
  } catch (err) {
    logger.error("Error getting employee EODs", {
      error: err.message,
      stack: err.stack,
      employeeId: req.params.employeeId,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Check for missed EOD submissions and increment warning count
 * This should be called by a cron job or scheduler
 */
exports.checkMissedEODs = async (req, res) => {
  try {
    // Get yesterday's date in IST
    const yesterdayStart = moment()
      .tz("Asia/Kolkata")
      .subtract(1, "day")
      .startOf("day")
      .toDate();
    const yesterdayEnd = moment()
      .tz("Asia/Kolkata")
      .subtract(1, "day")
      .endOf("day")
      .toDate();

    // Get all active employees
    const allEmployees = await Employee.find({});

    // Get all EODs submitted yesterday
    const submittedEODs = await EOD.find({
      date: { $gte: yesterdayStart, $lte: yesterdayEnd },
    }).distinct("employee");

    // Find employees who didn't submit EOD
    const missedEmployees = allEmployees.filter(
      (emp) => !submittedEODs.includes(emp._id.toString()),
    );

    // Increment warning count for missed employees
    const warnings = [];
    for (const employee of missedEmployees) {
      employee.eodWarningCount += 1;
      await employee.save();

      warnings.push({
        employeeId: employee.employeeId,
        name: employee.name,
        warningCount: employee.eodWarningCount,
        message:
          employee.eodWarningCount >= 3
            ? "3 warnings reached - Pay cut flag should be reviewed by HR/Admin"
            : `Warning ${employee.eodWarningCount}/3 for missed EOD`,
      });
    }

    res.status(200).json({
      message: "Missed EOD check completed",
      totalEmployees: allEmployees.length,
      submittedCount: submittedEODs.length,
      missedCount: missedEmployees.length,
      warnings,
    });
  } catch (err) {
    logger.error("Error checking missed EODs", {
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get EOD statistics for dashboard
 */
exports.getEODStats = async (req, res) => {
  try {
    const employeeUserId = req.userId;

    // Find employee profile
    const employeeProfile = await Employee.findOne({ user: employeeUserId });
    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Get total EODs submitted
    const totalEODs = await EOD.countDocuments({
      employee: employeeProfile._id,
    });

    // Check if today's EOD is submitted
    const currentIST = getISTTime();
    const todayDateString = currentIST.format("YYYY-MM-DD");
    const todayEOD = await EOD.findOne({
      employee: employeeProfile._id,
      date: {
        $gte: new Date(todayDateString + "T00:00:00.000Z"),
        $lt: new Date(todayDateString + "T23:59:59.999Z"),
      },
    });

    // Get current month's EOD count
    const monthStart = moment().tz("Asia/Kolkata").startOf("month").toDate();
    const monthEnd = moment().tz("Asia/Kolkata").endOf("month").toDate();
    const monthlyEODs = await EOD.countDocuments({
      employee: employeeProfile._id,
      date: { $gte: monthStart, $lte: monthEnd },
    });

    res.status(200).json({
      totalEODs,
      todaySubmitted: !!todayEOD,
      monthlyEODs,
      warningCount: employeeProfile.eodWarningCount,
      payCutFlag: employeeProfile.payCutFlag,
    });
  } catch (err) {
    logger.error("Error getting EOD stats", {
      error: err.message,
      stack: err.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: err.message });
  }
};
