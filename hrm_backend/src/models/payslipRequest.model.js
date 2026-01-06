const mongoose = require("mongoose");

const payslipRequestSchema = new mongoose.Schema(
  {
    employee: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Employee",
      required: true,
    },
    startMonth: {
      type: String,
      required: true,
      enum: [
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
      ],
    },
    startYear: {
      type: String,
      required: true,
    },
    endMonth: {
      type: String,
      required: true,
      enum: [
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
      ],
    },
    endYear: {
      type: String,
      required: true,
    },
    reason: {
      type: String,
      default: "",
    },
    status: {
      type: String,
      enum: ["pending", "processing", "approved", "completed", "rejected", "on-hold"],
      default: "pending",
    },
    basePay: {
      type: Number,
      default: null,
    },
    calculatedFields: {
      basicPay: { type: Number, default: null },
      hra: { type: Number, default: null },
      specialAllowance: { type: Number, default: null },
      netSalary: { type: Number, default: null },
      bonus: { type: Number, default: 0 },
    },
    // Deductions
    deductions: {
      pf: { type: Number, default: 0 },
      esi: { type: Number, default: 0 },
      pt: { type: Number, default: 0 },
      lop: { type: Number, default: 0 },
      penalty: { type: Number, default: 0 },
    },
    // Additional payslip details
    payslipDetails: {
      pan: { type: String, default: null },
      bankName: { type: String, default: null },
      accountNumber: { type: String, default: null },
      pfNumber: { type: String, default: null },
      uan: { type: String, default: null },
      paidDays: { type: Number, default: null },
      lopDays: { type: Number, default: 0 },
    },
    processedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "HR",
      default: null,
    },
    processedAt: {
      type: Date,
      default: null,
    },
    payslipExpiry: {
      type: Date,
      default: null,
    },
    payslipUrl: {
      type: String,
      default: null,
    },
    rejectionReason: {
      type: String,
      default: null,
    },
    priority: {
      type: String,
      enum: ["low", "normal", "high", "urgent"],
      default: "normal",
    },
  },
  {
    timestamps: true,
  }
);

// Index for efficient queries
payslipRequestSchema.index({ employee: 1, status: 1 });
payslipRequestSchema.index({ status: 1, createdAt: -1 });
payslipRequestSchema.index({ processedBy: 1, status: 1 });

module.exports = mongoose.model("PayslipRequest", payslipRequestSchema);
