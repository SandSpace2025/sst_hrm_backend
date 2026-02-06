const Attendance = require("../models/attendance.model");
const LeaveRequest = require("../models/leaveRequest.model");
const Employee = require("../models/employee.model");
const logger = require("../core/logger");

// Constants
const REQUIRED_DURATION_MS = 9 * 60 * 60 * 1000;

/**
 * Helper: Normalize date
 */
const getStartOfDay = (date) => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
};

/**
 * Fetch approved leave for user & date
 */
const getApprovedLeave = async (userId, date) => {
  const startOfDay = getStartOfDay(date);
  const endOfDay = new Date(startOfDay);
  endOfDay.setHours(23, 59, 59, 999);

  const employeeDoc = await Employee.findOne({ user: userId });
  if (!employeeDoc) return null;

  return await LeaveRequest.findOne({
    employee: employeeDoc._id,
    status: "approved",
    $or: [{ startDate: { $lte: endOfDay }, endDate: { $gte: startOfDay } }],
  });
};

/**
 * Calculate Penalty Logic (Pure)
 * Modifies optional attendance object arguments
 */
const calculateShortfallAndPenalty = (attendance, approvedLeave) => {
  // 1. Determine Status (if not already set or needing update)
  // Logic: >8h Present, >4h Half Day, else Absent.
  // Unless overridden by manual status (handled by caller logic usually).

  // 2. Adjust Required Duration
  let requiredDurationMs = REQUIRED_DURATION_MS; // Default 9h

  // Half Day Status Logic
  if (attendance.status === "Half Day") {
    requiredDurationMs = 4 * 60 * 60 * 1000;
  }

  // Leave Logic
  if (approvedLeave) {
    if (approvedLeave.leaveType === "work_from_home") {
      requiredDurationMs = 0;
    } else if (
      approvedLeave.leaveType === "permission" &&
      approvedLeave.permissionHours
    ) {
      const permissionMs = approvedLeave.permissionHours * 60 * 60 * 1000;
      requiredDurationMs -= permissionMs;
    } else if (approvedLeave.durationType === "half_day") {
      requiredDurationMs = 4 * 60 * 60 * 1000;
    } else if (approvedLeave.durationType === "full_day") {
      requiredDurationMs = 0;
    }
  }

  if (requiredDurationMs < 0) requiredDurationMs = 0;

  // 3. Calculate Shortfall
  let shortfallMs = requiredDurationMs - (attendance.totalDuration || 0);
  if (shortfallMs < 0) shortfallMs = 0;

  const shortfallMinutes = Math.floor(shortfallMs / (1000 * 60));

  // 4. Update Penalty Fields
  attendance.shortfallPenaltyMinutes = shortfallMinutes;
  attendance.totalPenaltyMinutes =
    (attendance.lateArrivalPenaltyMinutes || 0) + shortfallMinutes;
};

/**
 * Recalculate Attendance for a specific User and Date
 * Used when Leave Status changes
 */
const recalculateAttendance = async (userId, date) => {
  try {
    const today = getStartOfDay(date);
    const attendance = await Attendance.findOne({ userId, date: today });

    if (!attendance) {
      return;
    }

    const approvedLeave = await getApprovedLeave(userId, today);

    // Update Status Wrapper?
    // If WFH, set status Present.
    if (approvedLeave && approvedLeave.leaveType === "work_from_home") {
      if (attendance.status !== "Present") attendance.status = "Present";
    }

    calculateShortfallAndPenalty(attendance, approvedLeave);
    await attendance.save();
    logger.info(`Recalculated attendance for User ${userId} on ${date}`);
  } catch (error) {
    logger.error("Error recalculating attendance", { error: error.message });
  }
};

module.exports = {
  getApprovedLeave,
  calculateShortfallAndPenalty,
  recalculateAttendance,
};
