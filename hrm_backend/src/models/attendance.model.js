const mongoose = require("mongoose");

const attendanceSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    date: {
      type: Date,
      required: true,
    },
    clockInTime: {
      type: Date,
      required: true,
    },
    clockOutTime: {
      type: Date,
    },
    sessions: [
      {
        checkInTime: { type: Date, required: true },
        checkOutTime: { type: Date },
        duration: { type: Number, default: 0 }, // in ms
      },
    ],
    totalBreakDuration: {
      type: Number,
      default: 0,
    },
    breakStartTime: {
      // Keeping for backward compatibility or simple break tracking if needed, though sessions array is better
      type: Date,
    },
    breakEndTime: {
      type: Date,
    },
    status: {
      type: String,
      enum: ["Present", "Absent", "Half Day", "Leave", "On Duty"],
      default: "Present",
    },
    totalDuration: {
      type: Number, // In milliseconds
      default: 0,
    },
    // New Penalty Fields
    lateArrivalPenaltyMinutes: {
      type: Number,
      default: 0,
    },
    shortfallPenaltyMinutes: {
      type: Number,
      default: 0,
    },
    totalPenaltyMinutes: {
      type: Number,
      default: 0,
    },
    notes: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index to ensure one record per user per day (optional but recommended)
attendanceSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model("Attendance", attendanceSchema);
