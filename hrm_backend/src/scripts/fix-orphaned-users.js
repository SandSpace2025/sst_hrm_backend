const mongoose = require("mongoose");
const User = require("../models/user.model");
const Employee = require("../models/employee.model");
const dotenv = require("dotenv");

// Load env vars
dotenv.config();

const fixOrphans = async () => {
  try {
    console.log("Connecting to database...");
    await mongoose.connect(
      process.env.MONGODB_URI || "mongodb://localhost:27017/hrm_db"
    );
    console.log("Connected.");

    const employees = await Employee.find({});

    console.log(
      `Checking ${employees.length} employees for broken User links...`
    );
    let fixedCount = 0;

    for (const emp of employees) {
      let isBroken = false;
      if (!emp.user) {
        isBroken = true;
      } else {
        const linkedUser = await User.findById(emp.user);
        if (!linkedUser) {
          isBroken = true;
        }
      }

      if (isBroken) {
        console.log(`[FIXING] Orphan detected: ${emp.name} (${emp.email})`);

        // 1. Check if a user with this email already exists (but wasn't linked)
        let user = await User.findOne({ email: emp.email });

        if (!user) {
          // 2. Create new user
          console.log(`  -> Creating new User account...`);
          user = new User({
            email: emp.email.toLowerCase(),
            password: "password123", // Default password
            role: "employee",
          });
          await user.save();
        } else {
          console.log(`  -> Found existing unlinked User, relinking...`);
        }

        // 3. Link back to Employee
        emp.user = user._id;
        await emp.save();
        console.log(
          `  -> [SUCCESS] Relinked ${emp.name} to User ID ${user._id}`
        );
        fixedCount++;
      }
    }

    console.log(`\nOperation Complete. Fixed ${fixedCount} orphans.`);
    process.exit(0);
  } catch (err) {
    console.error("Repair failed:", err);
    process.exit(1);
  }
};

fixOrphans();
