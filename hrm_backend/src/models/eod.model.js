const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const eodSchema = new Schema(
  {
    employee: {
      type: Schema.Types.ObjectId,
      ref: "Employee",
      required: true,
      index: true,
    },
    date: {
      type: Date,
      required: true,
      index: true,
    },
    // Legacy fields (for backward compatibility)
    project: {
      type: String,
      required: true,
      trim: true,
    },
    tasksCompleted: {
      type: String,
      required: true,
      trim: true,
    },
    challenges: {
      type: String,
      default: "",
      trim: true,
    },
    nextDayPlan: {
      type: String,
      required: true,
      trim: true,
    },
    // Enhanced fields
    projectName: {
      type: String,
      trim: true,
    },
    taskDoneToday: {
      type: String,
      trim: true,
    },
    challengesFaced: {
      type: String,
      trim: true,
    },
    studentName: {
      type: String,
      trim: true,
    },
    technology: {
      type: String,
      trim: true,
    },
    taskType: {
      type: String,
      trim: true,
    },
    projectStatus: {
      type: Number,
      min: 0,
      max: 100,
    },
    deadline: {
      type: Date,
    },
    daysTaken: {
      type: Number,
      min: 0,
    },
    reportSent: {
      type: Boolean,
      default: false,
    },
    personWorkingOnReport: {
      type: String,
      trim: true,
    },
    reportStatus: {
      type: String,
      trim: true,
    },
    submittedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

// Compound index to ensure one EOD per employee per day
eodSchema.index({ employee: 1, date: 1 }, { unique: true });

const EOD = mongoose.model("EOD", eodSchema);

module.exports = EOD;
