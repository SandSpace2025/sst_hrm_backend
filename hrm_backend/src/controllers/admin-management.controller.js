const mongoose = require("mongoose");
const User = require("../models/user.model");
const Admin = require("../models/admin.model");
const logger = require("../core/logger");

/**
 * @description Create a new Admin User and their associated Admin profile.
 * This is a protected action intended for manual creation by an existing admin.
 */
exports.createAdmin = async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res
      .status(400)
      .send({ message: "Email and password are required." });
  }

  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const existingUser = await User.findOne({ email }).session(session);
    if (existingUser) {
      await session.abortTransaction();
      session.endSession();
      return res
        .status(409)
        .send({ message: "Failed! Email is already in use." });
    }

    const newUser = new User({
      email,
      password, // The password will be hashed by the pre-save hook in user.model.js
      role: "admin",
    });
    const savedUser = await newUser.save({ session });

    const newAdminProfile = new Admin({
      user: savedUser._id,
    });
    await newAdminProfile.save({ session });

    await session.commitTransaction();
    session.endSession();

    res.status(201).send({ message: "Admin user registered successfully!" });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    logger.error("Admin creation failed", {
      error: err.message,
      stack: err.stack,
      email: req.body.email,
    });
    res.status(500).send({
      message: err.message || "An error occurred during admin creation.",
    });
  }
};
