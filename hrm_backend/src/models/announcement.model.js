const mongoose = require("mongoose");

const announcementSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    message: {
      type: String,
      required: true,
      trim: true,
    },
    audience: {
      type: String,
      enum: ["all", "employees", "hr", "admin"],
      default: "all",
      required: true,
    },
    priority: {
      type: String,
      enum: ["low", "normal", "high", "urgent"],
      default: "normal",
      required: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
    },
    createdByModel: {
      type: String,
      enum: ["Admin", "HR"],
      required: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    scheduledFor: {
      type: Date,
      default: null, // For scheduled announcements
    },
    expiresAt: {
      type: Date,
      default: null, // For announcements with expiration
    },
  },
  {
    timestamps: true,
  }
);

// Index for better query performance
announcementSchema.index({ audience: 1, isActive: 1, createdAt: -1 });
announcementSchema.index({ createdBy: 1, createdAt: -1 });

module.exports = mongoose.model("Announcement", announcementSchema);
