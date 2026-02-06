const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const payrollSchema = new Schema(
  {
    employee: {
      type: Schema.Types.ObjectId,
      ref: "Employee",
      ref: "Employee",
      required: false,
    },
    transactionId: {
      type: String,
      default: null,
    },
    hr: {
      type: Schema.Types.ObjectId,
      ref: "HR",
      required: false,
    },
    totalPay: {
      type: Number,
      required: [true, "Total pay is required."],
    },
    bonus: {
      type: Number,
      default: 0,
    },
    // Calculated breakdown and additional payslip info
    calculatedFields: {
      basicPay: { type: Number, default: null },
      hra: { type: Number, default: null },
      specialAllowance: { type: Number, default: null },
      netSalary: { type: Number, default: null },
      bonus: { type: Number, default: 0 },
      conveyance: { type: Number, default: null },
      monthlyCTC: { type: Number, default: null },
      grossSalary: { type: Number, default: null },
    },
    // Deductions
    deductions: {
      pf: { type: Number, default: 0 },
      esi: { type: Number, default: 0 },
      pt: { type: Number, default: 0 },
      lop: { type: Number, default: 0 },
      penalty: { type: Number, default: 0 },
    },
    // Payslip details like PAN/Bank info
    payslipDetails: {
      pan: { type: String, default: null },
      bankName: { type: String, default: null },
      accountNumber: { type: String, default: null },
      pfNumber: { type: String, default: null },
      uan: { type: String, default: null },
      paidDays: { type: Number, default: null },
      lopDays: { type: Number, default: 0 },
    },
    payPeriod: {
      type: Date,
      required: [true, "Pay period is required."],
    },
  },
  { timestamps: true },
);

// Ensure either employee or hr is provided, but not both
payrollSchema.pre("validate", function (next) {
  if ((!this.employee && !this.hr) || (this.employee && this.hr)) {
    return next(
      new Error("Either employee or hr must be specified, but not both"),
    );
  }
  next();
});

// Check for duplicate payroll records before saving
payrollSchema.pre("save", async function (next) {
  try {
    const Payroll = this.constructor;
    const query = {
      payPeriod: this.payPeriod,
    };

    if (this.employee) {
      query.employee = this.employee;
    } else if (this.hr) {
      query.hr = this.hr;
    }

    const existingPayroll = await Payroll.findOne(query);
    if (
      existingPayroll &&
      existingPayroll._id.toString() !== this._id.toString()
    ) {
      return next(
        new Error("Payroll record already exists for this user and period"),
      );
    }

    next();
  } catch (error) {
    next(error);
  }
});

// Create compound indexes for both employee and hr
// Temporarily remove unique constraints to avoid conflicts

const Payroll = mongoose.model("Payroll", payrollSchema);

module.exports = Payroll;
