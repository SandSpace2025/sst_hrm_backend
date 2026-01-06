const Payroll = require("../models/payroll.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const mongoose = require("mongoose");

const createPayroll = async (req, res) => {
  try {
    const { employeeId, totalPay, bonus, payPeriod, userRole, calculatedFields, deductions, payslipDetails } = req.body;

    console.log('📋 [PAYROLL] createPayroll payload received:');
    console.log('  - employeeId:', employeeId);
    console.log('  - totalPay:', totalPay);
    console.log('  - bonus:', bonus);
    console.log('  - payPeriod:', payPeriod);
    console.log('  - calculatedFields:', JSON.stringify(calculatedFields, null, 2));
    console.log('  - deductions:', JSON.stringify(deductions, null, 2));
    console.log('  - payslipDetails:', JSON.stringify(payslipDetails, null, 2));

    if (!employeeId || totalPay === undefined || !payPeriod) {
      return res.status(400).json({
        message: "Employee/HR ID, total pay, and pay period are required.",
      });
    }

    // --- FIX: Add strict validation for the employeeId ---
    if (!mongoose.Types.ObjectId.isValid(employeeId)) {
      return res
        .status(400)
        .json({ message: "Invalid Employee/HR ID format." });
    }

    // Check if the ID belongs to an Employee or HR
    let employee = null;
    let hr = null;
    let isEmployee = false;

    if (userRole === "employee") {
      employee = await Employee.findById(employeeId);
      if (!employee) {
        return res.status(404).json({ message: "Employee not found." });
      }
      isEmployee = true;
    } else if (userRole === "hr") {
      hr = await HR.findById(employeeId);
      if (!hr) {
        return res.status(404).json({ message: "HR not found." });
      }
      isEmployee = false;
    } else {
      employee = await Employee.findById(employeeId);
      if (employee) {
        isEmployee = true;
      } else {
        hr = await HR.findById(employeeId);
        if (!hr) {
          return res.status(404).json({ message: "Employee or HR not found." });
        }
        isEmployee = false;
      }
    }

    const payPeriodDate = new Date(payPeriod);
    payPeriodDate.setUTCHours(0, 0, 0, 0);

    const startOfMonth = new Date(
      Date.UTC(payPeriodDate.getUTCFullYear(), payPeriodDate.getUTCMonth(), 1)
    );
    const endOfMonth = new Date(
      Date.UTC(
        payPeriodDate.getUTCFullYear(),
        payPeriodDate.getUTCMonth() + 1,
        0
      )
    );

    // Check for existing payroll based on role
    const existingPayroll = await Payroll.findOne({
      [isEmployee ? "employee" : "hr"]: employeeId,
      payPeriod: {
        $gte: startOfMonth,
        $lte: endOfMonth,
      },
    });

    if (existingPayroll) {
      return res.status(409).json({
        message: `Payroll for this ${
          isEmployee ? "employee" : "HR"
        } and month already exists.`,
      });
    }

    const payrollData = {
      totalPay,
      bonus,
      payPeriod: startOfMonth, // Store a consistent date
      // Optional extra fields
      calculatedFields: calculatedFields || {},
      deductions: deductions || {},
      payslipDetails: payslipDetails || {},
    };

    if (isEmployee) {
      payrollData.employee = employeeId;
    } else {
      payrollData.hr = employeeId;
    }

    const payroll = new Payroll(payrollData);
    await payroll.save();
    res.status(201).json(payroll);
  } catch (error) {
    res.status(500).json({
      message: "Server error creating payroll.",
      error: error.message,
    });
  }
};

const getPayrollsForEmployee = async (req, res) => {
  try {
    const { employeeId } = req.params;

    // --- FIX: Add strict validation for the employeeId ---
    if (!mongoose.Types.ObjectId.isValid(employeeId)) {
      return res
        .status(400)
        .json({ message: "Invalid Employee/HR ID format." });
    }

    // Find payrolls for both employee and hr
    const payrolls = await Payroll.find({
      $or: [{ employee: employeeId }, { hr: employeeId }],
    }).sort({
      payPeriod: -1,
    });

    res.status(200).json(payrolls);
  } catch (error) {
    res.status(500).json({
      message: "Server error fetching payrolls.",
      error: error.message,
    });
  }
};

const updatePayroll = async (req, res) => {
  try {
    const { payrollId } = req.params;
    const { totalPay, bonus, calculatedFields, deductions, payslipDetails } = req.body;

    // --- FIX: Add strict validation for the payrollId ---
    if (!mongoose.Types.ObjectId.isValid(payrollId)) {
      return res.status(400).json({ message: "Invalid Payroll ID format." });
    }

    if (totalPay === undefined && bonus === undefined && calculatedFields === undefined && deductions === undefined && payslipDetails === undefined) {
      return res.status(400).json({
        message: "Either total pay or bonus is required for an update.",
      });
    }

    const payroll = await Payroll.findById(payrollId);

    if (!payroll) {
      return res.status(404).json({ message: "Payroll record not found." });
    }

    if (totalPay !== undefined) payroll.totalPay = totalPay;
    if (bonus !== undefined) payroll.bonus = bonus;
    if (calculatedFields !== undefined) payroll.calculatedFields = calculatedFields;
    if (deductions !== undefined) payroll.deductions = deductions;
    if (payslipDetails !== undefined) payroll.payslipDetails = payslipDetails;

    const updatedPayroll = await payroll.save();
    res.status(200).json(updatedPayroll);
  } catch (error) {
    res.status(500).json({
      message: "Server error updating payroll.",
      error: error.message,
    });
  }
};

const deletePayroll = async (req, res) => {
  try {
    const { payrollId } = req.params;

    // --- FIX: Add strict validation for the payrollId ---
    if (!mongoose.Types.ObjectId.isValid(payrollId)) {
      return res.status(400).json({ message: "Invalid Payroll ID format." });
    }

    const payroll = await Payroll.findByIdAndDelete(payrollId);

    if (!payroll) {
      return res.status(404).json({ message: "Payroll record not found." });
    }

    res.status(200).json({ message: "Payroll record deleted successfully." });
  } catch (error) {
    res.status(500).json({
      message: "Server error deleting payroll.",
      error: error.message,
    });
  }
};

module.exports = {
  createPayroll,
  getPayrollsForEmployee,
  updatePayroll,
  deletePayroll,
};
