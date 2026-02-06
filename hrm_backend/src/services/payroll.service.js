const Attendance = require("../models/attendance.model");
const logger = require("../core/logger");

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
 * Calculate dynamic penalty based on attendance shortfalls
 * @param {string} userId - User ObjectId
 * @param {string} month - Month name (e.g., "December")
 * @param {string|number} year - Year (e.g., 2025)
 * @param {number} basePay - Base monthly salary
 * @returns {Promise<number>} - Calculated penalty amount
 */
exports.calculateDynamicPenalty = async (userId, month, year, basePay) => {
  try {
    const monthIndex = getMonthIndex(month);
    const yearInt = parseInt(year);

    if (monthIndex === -1 || isNaN(yearInt) || !basePay) {
      return 0;
    }

    // 1. Calculate Per-Unit Rates
    const daysInMonth = new Date(yearInt, monthIndex + 1, 0).getDate();
    const salaryPerDay = basePay / daysInMonth;
    const salaryPerHour = salaryPerDay / 8; // 8 hours work day (for rate calc)
    const salaryPerMinute = salaryPerHour / 60;

    // 2. Fetch Attendance for the period
    const startDate = new Date(yearInt, monthIndex, 1);
    const endDate = new Date(yearInt, monthIndex + 1, 0, 23, 59, 59);

    const attendanceRecords = await Attendance.find({
      userId: userId,
      date: { $gte: startDate, $lte: endDate },
    });

    // 3. Calculate Shortfall (Minutes)
    let totalPenaltyMinutes = 0;

    attendanceRecords.forEach((record) => {
      // Skip Sundays (0)
      const curDate = new Date(record.date);
      const dayOfWeek = curDate.getDay();
      if (dayOfWeek === 0) return;

      // --- INTEGRATION: Use Attendance-Level Penalty Calculation ---
      // If the record has the new totalPenaltyMinutes field (checked explicitly for undefined/null),
      // use it as the source of truth. Does not check for truthiness to allow 0.
      if (
        record.totalPenaltyMinutes !== undefined &&
        record.totalPenaltyMinutes !== null
      ) {
        totalPenaltyMinutes += record.totalPenaltyMinutes;
      } else {
        // --- LEGACY FALLBACK LOGIC (Dynamic Calculation) ---
        // 1. Calculate Late Arrival Penalty
        // Office Start: 10:00 AM, Grace End: 10:15 AM
        if (record.clockInTime) {
          const clockIn = new Date(record.clockInTime);
          const officeStart = new Date(clockIn);
          officeStart.setHours(10, 0, 0, 0);

          const graceEnd = new Date(clockIn);
          graceEnd.setHours(10, 15, 0, 0);

          if (clockIn > graceEnd) {
            const lateMs = clockIn - officeStart;
            const lateMins = Math.floor(lateMs / (1000 * 60));
            totalPenaltyMinutes += lateMins;
          }
        }

        // 2. Calculate Shortfall Penalty
        // RULE: Half Day (4h target) vs Full Day (9h target)
        // LUNCH: 1 Hour is non-penalizable (implicitly handled by Target Duration).
        // Full Day: 9 Hours Expected.
        // Half Day: 4 Hours Expected.
        // Penalty = max(0, Expected - Actual).

        let expectedMinutes = 9 * 60; // 540 mins (Full Day Default)
        const durationMinutes = (record.totalDuration || 0) / (1000 * 60);

        // Determine Status
        let isHalfDay = record.status === "Half Day";

        // Safety Fallback: Use duration to identify unmatched Half Days
        if (
          !isHalfDay &&
          durationMinutes >= 4 * 60 &&
          durationMinutes < 8 * 60
        ) {
          isHalfDay = true;
        }

        if (isHalfDay) {
          expectedMinutes = 4 * 60; // 240 mins (Half Day Target)
        }

        // Only penalize if they worked less than expected
        if (durationMinutes < expectedMinutes) {
          const shortfall = expectedMinutes - durationMinutes;
          totalPenaltyMinutes += shortfall;
        }
      }
    });

    // 4. Calculate Total Penalty Amount
    const calculatedPenalty = totalPenaltyMinutes * salaryPerMinute;

    return calculatedPenalty;
  } catch (err) {
    logger.error("Error calculating dynamic penalty", { error: err.message });
    return 0; // Return 0 on error to avoid blocking flow
  }
};

/**
 * Calculate standard salary components
 * @param {number} basePay
 * @returns {Object} - { basicPay, hra, specialAllowance }
 */
exports.calculateSalaryComponents = (basePay) => {
  const basic = Math.round(basePay * 0.5);
  return {
    basicPay: basic,
    hra: Math.round(basic * 0.575),
    conveyance: Math.round(basic * 0.275),
    specialAllowance: Math.round(basic * 0.15),
  };
};

/**
 * Check if attendance records exist for the month
 */
exports.hasAttendanceRecords = async (userId, month, year) => {
  try {
    const monthIndex = getMonthIndex(month);
    const yearInt = parseInt(year);

    if (monthIndex === -1 || isNaN(yearInt)) {
      return false;
    }

    const startDate = new Date(yearInt, monthIndex, 1);
    const endDate = new Date(yearInt, monthIndex + 1, 0, 23, 59, 59);

    const count = await Attendance.countDocuments({
      userId: userId,
      date: { $gte: startDate, $lte: endDate },
    });

    return count > 0;
  } catch (err) {
    logger.error("Error checking attendance existence", { error: err.message });
    return false;
  }
};

/**
 * Calculate standard deductions
 * @returns {Object} - { pt, pf, esi }
 */
exports.calculateDeductions = () => {
  return {
    pt: 150, // Fixed Professional Tax
    pf: 0,
    esi: 0,
  };
};

/**
 * Calculate LOP (Loss of Pay) days based on 'Absent' status
 * @param {string} userId
 * @param {string} month
 * @param {string|number} year
 * @returns {Promise<number>}
 */
exports.calculateLOPDays = async (userId, month, year) => {
  try {
    const monthIndex = getMonthIndex(month);
    const yearInt = parseInt(year);

    if (monthIndex === -1 || isNaN(yearInt)) {
      return 0;
    }

    const startDate = new Date(yearInt, monthIndex, 1);
    const endDate = new Date(yearInt, monthIndex + 1, 0, 23, 59, 59);

    // Count records explicitly marked as 'Absent'
    const absentCount = await Attendance.countDocuments({
      userId: userId,
      date: { $gte: startDate, $lte: endDate },
      status: "Absent",
    });

    return absentCount;
  } catch (err) {
    logger.error("Error calculating LOP days", { error: err.message });
    return 0;
  }
};
