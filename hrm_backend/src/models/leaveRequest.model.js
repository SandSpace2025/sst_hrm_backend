const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const leaveRequestSchema = new Schema(
  {
    employee: {
      type: Schema.Types.ObjectId,
      ref: "Employee",
      required: true,
      index: true,
    },
    leaveType: {
      type: String,
      required: true,
      enum: ["casual", "sick", "work_from_home", "permission"],
    },
    durationType: {
      type: String,
      required: true,
      enum: ["full_day", "half_day", "hours"], // hours for permissions
    },
    startDate: {
      type: Date,
      required: true,
      index: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    // For half-day leaves
    halfDayPeriod: {
      type: String,
      enum: ["first_half", "second_half", null],
      default: null,
    },
    // For permission (in hours)
    permissionHours: {
      type: Number,
      min: 0,
      max: 8,
      default: null,
    },
    permissionStartTime: {
      type: String, // Format: "HH:mm" (24-hour format)
      default: null,
    },
    permissionEndTime: {
      type: String, // Format: "HH:mm" (24-hour format)
      default: null,
    },
    reason: {
      type: String,
      required: true,
      trim: true,
    },
    medicalCertificate: {
      type: String, // File path for medical certificate
      default: null,
    },
    status: {
      type: String,
      enum: ["pending", "approved", "rejected", "cancelled"],
      default: "pending",
      index: true,
    },
    // Approval workflow
    hrApproval: {
      status: {
        type: String,
        enum: ["pending", "approved", "rejected", null],
        default: null,
      },
      approvedBy: {
        type: Schema.Types.ObjectId,
        ref: "HR",
        default: null,
      },
      approvedAt: {
        type: Date,
        default: null,
      },
      rejectionReason: {
        type: String,
        default: null,
      },
    },
    adminApproval: {
      status: {
        type: String,
        enum: ["pending", "approved", "rejected", null],
        default: null,
      },
      approvedBy: {
        type: Schema.Types.ObjectId,
        ref: "Admin",
        default: null,
      },
      approvedAt: {
        type: Date,
        default: null,
      },
      rejectionReason: {
        type: String,
        default: null,
      },
    },
    requiresBothApprovals: {
      type: Boolean,
      default: false,
    },
    submittedDate: {
      type: Date,
      default: Date.now,
    },
    cancelledBy: {
      type: String,
      enum: ["employee", "hr", "admin", null],
      default: null,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
    cancellationReason: {
      type: String,
      default: null,
    },
    // Track if this is paid or unpaid
    isPaid: {
      type: Boolean,
      default: false,
    },
    // Total days for this leave request
    totalDays: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

// Calculate total days for leave
leaveRequestSchema.methods.calculateLeaveDays = function () {
  if (this.durationType === "full_day") {
    const days =
      Math.ceil((this.endDate - this.startDate) / (1000 * 60 * 60 * 24)) + 1;
    return days;
  } else if (this.durationType === "half_day") {
    return 0.5;
  } else if (this.durationType === "hours") {
    return this.permissionHours / 8; // Convert hours to day fraction
  }
  return 0;
};

// Check if leave duration exceeds 7 days - renamed to avoid conflict
leaveRequestSchema.methods.checkIfBothApprovalsNeeded = function () {
  const days = this.calculateLeaveDays();
  return days > 7;
};

const LeaveRequest = mongoose.model("LeaveRequest", leaveRequestSchema);

module.exports = LeaveRequest;
