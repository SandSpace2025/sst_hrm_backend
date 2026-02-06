const Attendance = require("../models/attendance.model");
const moment = require("moment-timezone");
const LeaveRequest = require("../models/leaveRequest.model");
const Employee = require("../models/employee.model");
const attendanceService = require("../services/attendance.service");
const logger = require("../core/logger");

const getStartOfDay = (date) => {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
};

const OFFICE_START_HOUR = 10;
const OFFICE_START_MINUTE = 0;
const GRACE_PERIOD_END_HOUR = 10;
const GRACE_PERIOD_END_MINUTE = 15;

exports.punchIn = async (req, res) => {
  try {
    const userId = req.userId;
    const now = new Date();
    const today = getStartOfDay(now);

    let attendance = await Attendance.findOne({ userId, date: today });

    if (attendance) {
      const lastSession = attendance.sessions[attendance.sessions.length - 1];
      if (lastSession && !lastSession.checkOutTime) {
        return res
          .status(400)
          .json({ message: "Already punched in for today" });
      }

      const newSession = { checkInTime: now };
      if (lastSession && lastSession.checkOutTime) {
        const breakDuration = now - new Date(lastSession.checkOutTime);
        attendance.totalBreakDuration =
          (attendance.totalBreakDuration || 0) + breakDuration;
      }
      attendance.sessions.push(newSession);
      await attendance.save();
    } else {
      attendance = new Attendance({
        userId,
        date: today,
        clockInTime: now,
        status: "Present",
        sessions: [{ checkInTime: now }],
      });

      const officeStartTime = new Date(now);
      officeStartTime.setHours(OFFICE_START_HOUR, OFFICE_START_MINUTE, 0, 0);
      const gracePeriodEndTime = new Date(now);
      gracePeriodEndTime.setHours(
        GRACE_PERIOD_END_HOUR,
        GRACE_PERIOD_END_MINUTE,
        0,
        0,
      );

      let lateMinutes = 0;
      if (now > gracePeriodEndTime) {
        const diffMs = now - officeStartTime;
        if (diffMs > 0) {
          lateMinutes = Math.floor(diffMs / (1000 * 60));
        }
      }
      attendance.lateArrivalPenaltyMinutes = lateMinutes;
      attendance.totalPenaltyMinutes = lateMinutes;

      await attendance.save();
    }

    res.status(200).json({ message: "Punch In Successful", data: attendance });
  } catch (error) {
    logger.error("Punch in failed", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

exports.punchOut = async (req, res) => {
  try {
    const userId = req.userId;
    const now = new Date();
    const today = getStartOfDay(now);

    const attendance = await Attendance.findOne({ userId, date: today });
    if (!attendance) {
      return res
        .status(404)
        .json({ message: "No attendance record found for today." });
    }

    const lastSessionIndex = attendance.sessions.length - 1;
    const lastSession = attendance.sessions[lastSessionIndex];

    if (!lastSession || lastSession.checkOutTime) {
      return res
        .status(400)
        .json({ message: "Already punched out or no active session." });
    }

    // Close session
    lastSession.checkOutTime = now;
    lastSession.duration = now - new Date(lastSession.checkInTime);
    attendance.clockOutTime = now;

    // Recalculate total duration
    attendance.totalDuration = attendance.sessions.reduce(
      (acc, curr) => acc + (curr.duration || 0),
      0,
    );

    // Update status based on duration
    const totalHours = attendance.totalDuration / (1000 * 60 * 60);
    let newStatus = attendance.status;
    if (totalHours >= 8) {
      newStatus = "Present";
    } else if (totalHours >= 4) {
      newStatus = "Half Day";
    } else {
      newStatus = "Absent";
    }
    attendance.status = newStatus;

    // Fetch approved leave
    const approvedLeave = await attendanceService.getApprovedLeave(
      userId,
      today,
    );
    if (approvedLeave && approvedLeave.leaveType === "work_from_home") {
      if (attendance.status !== "Present") attendance.status = "Present";
    }

    // Calculate penalty
    attendanceService.calculateShortfallAndPenalty(attendance, approvedLeave);

    await attendance.save();
    res.status(200).json({ message: "Punch Out Successful", data: attendance });
  } catch (error) {
    logger.error("Punch out failed", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

exports.getTodayStatus = async (req, res) => {
  try {
    const userId = req.userId;
    const today = getStartOfDay(new Date());
    const attendance = await Attendance.findOne({ userId, date: today });
    res.status(200).json({ data: attendance });
  } catch (error) {
    logger.error("Get today status failed", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

exports.getHistory = async (req, res) => {
  try {
    const userId = req.userId;
    const { month, year } = req.query;

    let query = { userId };
    if (month && year) {
      const startDate = new Date(year, month - 1, 1);
      const endDate = new Date(year, month, 0, 23, 59, 59);
      query.date = { $gte: startDate, $lte: endDate };
    }

    const history = await Attendance.find(query).sort({ date: -1 });
    res.status(200).json({ data: history });
  } catch (error) {
    logger.error("Get attendance history failed", {
      error: error.message,
      stack: error.stack,
      userId: req.userId,
    });
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

exports.updateAttendance = async (req, res) => {
  try {
    const { id } = req.params;
    const { clockInTime, clockOutTime, status, notes } = req.body;

    const attendance = await Attendance.findById(id);
    if (!attendance) {
      return res.status(404).json({ message: "Attendance record not found" });
    }

    if (clockInTime) {
      attendance.clockInTime = new Date(clockInTime);
      if (attendance.sessions.length > 0)
        attendance.sessions[0].checkInTime = new Date(clockInTime);
    }

    if (clockOutTime) {
      attendance.clockOutTime = new Date(clockOutTime);
      if (attendance.sessions.length > 0) {
        const lastSession = attendance.sessions[attendance.sessions.length - 1];
        lastSession.checkOutTime = new Date(clockOutTime);
        if (lastSession.checkInTime) {
          lastSession.duration =
            lastSession.checkOutTime - lastSession.checkInTime;
        }
      }
    }

    if (status) attendance.status = status;
    if (notes) attendance.notes = notes;

    // Recalculate duration
    if (attendance.sessions.length > 0) {
      attendance.totalDuration = attendance.sessions.reduce(
        (acc, curr) => acc + (curr.duration || 0),
        0,
      );
    }

    // Recalculate late penalty
    if (attendance.sessions.length > 0 && attendance.sessions[0].checkInTime) {
      const firstCheckIn = new Date(attendance.sessions[0].checkInTime);
      const officeStartTime = new Date(firstCheckIn);
      officeStartTime.setHours(OFFICE_START_HOUR, OFFICE_START_MINUTE, 0, 0);
      const gracePeriodEndTime = new Date(firstCheckIn);
      gracePeriodEndTime.setHours(
        GRACE_PERIOD_END_HOUR,
        GRACE_PERIOD_END_MINUTE,
        0,
        0,
      );

      let lateMinutes = 0;
      if (firstCheckIn > gracePeriodEndTime) {
        const diffMs = firstCheckIn - officeStartTime;
        if (diffMs > 0) lateMinutes = Math.floor(diffMs / (1000 * 60));
      }
      attendance.lateArrivalPenaltyMinutes = lateMinutes;
    }

    // Auto-update status if derived from duration
    let currentStatus = status || attendance.status;
    if (!status && attendance.totalDuration > 0) {
      const totalHours = attendance.totalDuration / (1000 * 60 * 60);
      if (totalHours >= 8) currentStatus = "Present";
      else if (totalHours >= 4) currentStatus = "Half Day";
      else {
        if (currentStatus !== "Leave" && currentStatus !== "On Duty")
          currentStatus = "Absent";
      }
      attendance.status = currentStatus;
    }

    // Fetch approved leave
    const approvedLeave = await attendanceService.getApprovedLeave(
      attendance.userId,
      attendance.date,
    );
    if (approvedLeave && approvedLeave.leaveType === "work_from_home") {
      if (attendance.status !== "Present" && !status)
        attendance.status = "Present";
    }

    // Calculate penalty
    attendanceService.calculateShortfallAndPenalty(attendance, approvedLeave);

    await attendance.save();
    res
      .status(200)
      .json({ message: "Attendance updated successfully", data: attendance });
  } catch (error) {
    logger.error("Update attendance failed", {
      error: error.message,
      stack: error.stack,
      attendanceId: req.params.id,
    });
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};
