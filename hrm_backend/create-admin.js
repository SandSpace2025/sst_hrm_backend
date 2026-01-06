const mongoose = require("mongoose");
const User = require("./src/models/user.model");
const Admin = require("./src/models/admin.model");
const dbConfig = require("./src/config/db.config");

const newAdminEmail = "dev-admin@admin.com";
const newAdminPassword = "admin@123";

const createFirstAdmin = async () => {
  try {
    // // console.log("Connecting to the database...");
    await mongoose.connect(
      `mongodb://${dbConfig.HOST}:${dbConfig.PORT}/${dbConfig.DB}`,
      {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      }
    );
    // // console.log("Successfully connected to MongoDB.");

    // // console.log("Checking if admin already exists...");
    const existingUser = await User.findOne({ email: newAdminEmail });
    if (existingUser) {
      // // console.log("Admin user with this email already exists.");
      return;
    }

    // // console.log("Creating new admin user...");
    const newUser = new User({
      email: newAdminEmail,
      password: newAdminPassword,
      role: "admin",
    });
    const savedUser = await newUser.save();

    const newAdminProfile = new Admin({
      user: savedUser._id,
      fullName: "Initial Administrator",
    });
    await newAdminProfile.save();

    // // console.log("✅ Admin user created successfully!");
  } catch (error) {
    console.error("❌ Error creating admin user:", error);
  } finally {
    // // console.log("Closing database connection.");
    mongoose.disconnect();
  }
};

createFirstAdmin();
