const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const employeeSchema = new Schema(
  {
    user: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
    },
    name: {
      type: String,
      trim: true,
      default: "",
    },
    subOrganisation: {
      type: String,
      required: true,
      trim: true,
    },
    employeeId: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    profilePic: {
      type: String,
      default: "",
    },
    phone: {
      type: String,
      default: "",
    },
    jobTitle: {
      type: String,
      default: "",
    },
    bloodGroup: {
      type: String,
      default: "",
    },
    joinDate: {
      type: Date,
      default: null,
    },
    // EOD Warning System
    eodWarningCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    payCutFlag: {
      type: Boolean,
      default: false,
    },
    // Leave Management System
    leaveBalance: {
      casualLeave: {
        type: Number,
        default: 2, // 2 per month, carries over
      },
      workFromHome: {
        type: Number,
        default: 1, // 1 per month, resets monthly
      },
      permissionHours: {
        type: Number,
        default: 3, // 3 hours per month, resets monthly
      },
    },
    leaveHistory: {
      lastResetDate: {
        type: Date,
        default: Date.now,
      },
      totalCasualLeavesUsed: {
        type: Number,
        default: 0,
      },
      totalSickLeavesUsed: {
        type: Number,
        default: 0,
      },
      totalWFHUsed: {
        type: Number,
        default: 0,
      },
      totalPermissionHoursUsed: {
        type: Number,
        default: 0,
      },
    },
    // Messaging Permissions System
    messagingPermissions: {
      canMessage: {
        type: Boolean,
        default: false,
      },
      grantedBy: {
        type: Schema.Types.ObjectId,
        ref: "Admin",
        default: null,
      },
      grantedAt: {
        type: Date,
        default: null,
      },
      expiresAt: {
        type: Date,
        default: null,
      },
      lastRequestedAt: {
        type: Date,
        default: null,
      },
      requestedFrom: {
        type: Schema.Types.ObjectId,
        ref: "Admin",
        default: null,
      },
    },
  },
  {
    timestamps: true,
  }
);

const Employee = mongoose.model("Employee", employeeSchema);

module.exports = Employee;
