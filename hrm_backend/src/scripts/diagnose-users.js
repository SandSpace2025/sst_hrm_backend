const mongoose = require("mongoose");
const User = require("../models/user.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Admin = require("../models/admin.model");
const dotenv = require("dotenv");

// Load env vars
dotenv.config();

const diagnoseDatabase = async () => {
  try {
    console.log("Connectng to database...");
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/hrm_db"
    );
    console.log("Connected.");

    const users = await User.find({});
    const employees = await Employee.find({});
    const hrs = await HR.find({});
    const admins = await Admin.find({});

    console.log(`\n=== SUMMARY ===`);
    console.log(`Total Users: ${users.length}`);
    console.log(`Total Employees: ${employees.length}`);
    console.log(`Total HRs: ${hrs.length}`);
    console.log(`Total Admins: ${admins.length}`);

    console.log(`\n=== USERS (Auth) ===`);
    users.forEach((u) =>
      console.log(`- ${u.email} [${u.role}] (ID: ${u._id})`)
    );

    console.log(`\n=== EMPLOYEES (Profiles) ===`);
    let orphanedEmployees = 0;
    for (const emp of employees) {
      let status = "OK";
      if (!emp.user) {
        status = "MISSING USER LINK";
        orphanedEmployees++;
      } else {
        const linkedUser = users.find(
          (u) => u._id.toString() === emp.user.toString()
        );
        if (!linkedUser) {
          status = "LINKED USER NOT FOUND";
          orphanedEmployees++;
        }
      }
      console.log(
        `- ${emp.name} (${emp.email}) -> UserID: ${
          emp.user || "NULL"
        } [${status}]`
      );
    }

    if (orphanedEmployees > 0) {
      console.log(
        `\n[CRITICAL] Found ${orphanedEmployees} employees with broken User links.`
      );
      console.log("This explains why they cannot login or fetch data.");
    } else {
      console.log("\n[OK] All employee profiles have valid User links.");
    }

    process.exit(0);
  } catch (err) {
    console.error("Diagnosis failed:", err);
    process.exit(1);
  }
};

diagnoseDatabase();
