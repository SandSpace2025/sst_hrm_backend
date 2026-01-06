const User = require("../models/user.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Payroll = require("../models/payroll.model"); // Import the Payroll model
const mongoose = require("mongoose");
const Message = require("../models/message.model");

/**
 * @description Get a summary of user counts for the admin dashboard.
 */
exports.getDashboardSummary = async (req, res) => {
  try {
    const adminUserId = req.userId;
    const adminProfile = await require("../models/admin.model").findOne({
      user: adminUserId,
    });
    let unreadSenderIds = [];
    let unreadMessages = 0;

    if (adminProfile) {
      unreadSenderIds = await Message.find({
        receiver: adminProfile._id,
        receiverModel: "Admin",
        isRead: false,
        isApproved: true,
      }).distinct("sender.userId");

      unreadMessages = unreadSenderIds.length;
    }
    const [adminCount, hrCount, employeeCount] = await Promise.all([
      User.countDocuments({ role: "admin" }),
      User.countDocuments({ role: "hr" }),
      User.countDocuments({ role: "employee" }),
    ]);
    res.status(200).send({
      adminsOnline: adminCount,
      hrsOnline: hrCount,
      employeesOnline: employeeCount,
      pendingLeaveRequests: 8,
      eodReportsToReview: 12,
      unreadMessages,
      unreadSenderIds,
    });
  } catch (err) {
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Get a list of all HR or Employee profiles.
 */
exports.getUsersByRole = async (req, res) => {
  const { role } = req.params;
  if (role !== "hr" && role !== "employee") {
    return res.status(400).send({
      message:
        "Invalid role specified. Only 'hr' and 'employee' are supported.",
    });
  }
  try {
    const profiles =
      role === "hr"
        ? await HR.find().populate("user", "-password")
        : await Employee.find().populate("user", "-password");
    res.status(200).send(profiles);
  } catch (err) {
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Create a new User and their associated HR/Employee profile.
 */
exports.createUser = async (req, res) => {
  const {
    name,
    email,
    password,
    role,
    subOrganisation,
    employeeId,
    jobTitle,
    bloodGroup,
  } = req.body;
  const creatorRole = req.userRole;
  let newUser = null;
  try {
    if (!name || !email || !password || !role) {
      return res.status(400).send({ message: "Missing required fields." });
    }
    if (role === "employee" && !subOrganisation) {
      return res
        .status(400)
        .send({ message: "Sub-organisation is required for employees." });
    }
    if (role === "employee" && !jobTitle) {
      return res
        .status(400)
        .send({ message: "Job title is required for employees." });
    }
    if (role === "hr" && !employeeId) {
      return res
        .status(400)
        .send({ message: "Employee ID is required for HR." });
    }
    if (creatorRole === "hr" && (role === "admin" || role === "hr")) {
      return res
        .status(403)
        .send({ message: "HR users cannot create Admin or other HR users." });
    }
    if (role === "employee") {
      if (!employeeId) {
        return res.status(400).send({ message: "Employee ID is required." });
      }
      // Check for conflicts with both Employee and HR SST IDs
      const existingEmployee = await Employee.findOne({ employeeId });
      const existingHr = await HR.findOne({ employeeId });
      if (existingEmployee || existingHr) {
        return res
          .status(409)
          .send({ message: "Conflict: Employee ID already exists." });
      }
    }
    if (role === "hr") {
      if (!employeeId) {
        return res
          .status(400)
          .send({ message: "Employee ID is required for HR." });
      }
      // Check for conflicts with both HR and Employee SST IDs
      const existingHr = await HR.findOne({ employeeId });
      const existingEmployee = await Employee.findOne({ employeeId });
      if (existingHr || existingEmployee) {
        return res
          .status(409)
          .send({ message: "Conflict: Employee ID already exists." });
      }
    }
    newUser = new User({ email, password, role });
    await newUser.save();
    if (role === "hr") {
      const newHrProfile = new HR({
        user: newUser._id,
        name,
        email,
        subOrganisation: subOrganisation || "SandSpace Technologies Pvt Ltd.",
        employeeId: employeeId,
        bloodGroup,
      });
      await newHrProfile.save();
    } else if (role === "employee") {
      const newEmployeeProfile = new Employee({
        user: newUser._id,
        name,
        email,
        subOrganisation,
        employeeId,
        jobTitle,
        bloodGroup,
      });
      await newEmployeeProfile.save();
    }
    res.status(201).send({ message: "User was registered successfully!" });
  } catch (err) {
    if (newUser && newUser._id) {
      await User.deleteOne({ _id: newUser._id }).catch((deleteErr) =>
        console.error("Failed to cleanup user after error:", deleteErr)
      );
    }
    if (err.code === 11000) {
      return res
        .status(400)
        .send({ message: "Failed! Email is already in use!" });
    }
    console.error("User creation failed:", err);
    res.status(500).send({
      message: err.message || "An error occurred during user creation.",
    });
  }
};

/**
 * @description Update a user's profile details (name, email, phone, jobTitle). Role changes are ignored.
 */
exports.updateUser = async (req, res) => {
  const { id } = req.params;
  const { name, email, phone, role, jobTitle, bloodGroup } = req.body;
  const updaterRole = req.userRole;

  if (!name && !email && !phone && !role && !jobTitle && !bloodGroup) {
    return res.status(400).send({ message: "No update fields provided." });
  }

  try {
    const userToUpdate = await User.findById(id);
    if (!userToUpdate) {
      return res.status(404).send({ message: "User not found." });
    }

    if (
      updaterRole === "hr" &&
      (userToUpdate.role === "admin" || userToUpdate.role === "hr")
    ) {
      return res
        .status(403)
        .send({ message: "HR users can only update employee profiles." });
    }

    const userUpdatePayload = {};
    if (email) userUpdatePayload.email = email;

    const profileUpdatePayload = {};
    if (name) profileUpdatePayload.name = name;
    if (email) profileUpdatePayload.email = email;
    if (phone) profileUpdatePayload.phone = phone;
    if (jobTitle) profileUpdatePayload.jobTitle = jobTitle;
    if (bloodGroup) profileUpdatePayload.bloodGroup = bloodGroup;

    const updatePromises = [];

    if (Object.keys(userUpdatePayload).length > 0) {
      updatePromises.push(User.updateOne({ _id: id }, userUpdatePayload));
    }

    if (Object.keys(profileUpdatePayload).length > 0) {
      if (userToUpdate.role === "employee") {
        updatePromises.push(
          Employee.updateOne({ user: id }, profileUpdatePayload)
        );
      } else if (userToUpdate.role === "hr") {
        updatePromises.push(HR.updateOne({ user: id }, profileUpdatePayload));
      }
    }

    await Promise.all(updatePromises);

    res.status(200).send({ message: "User updated successfully!" });
  } catch (err) {
    if (err.code === 11000) {
      return res
        .status(400)
        .send({ message: "Failed! Email is already in use!" });
    }
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Delete a user and their corresponding profile and payroll data.
 */
exports.deleteUser = async (req, res) => {
  const { id } = req.params;
  const deleterRole = req.userRole;

  try {
    const userToDelete = await User.findById(id);
    if (!userToDelete) {
      return res.status(404).send({ message: "User not found." });
    }

    if (
      deleterRole === "hr" &&
      (userToDelete.role === "admin" || userToDelete.role === "hr")
    ) {
      return res
        .status(403)
        .send({ message: "HR users can only delete employees." });
    }

    if (userToDelete.role === "employee") {
      // Find the employee profile to get its ID for cascading delete
      const employeeProfile = await Employee.findOne({
        user: userToDelete._id,
      });

      if (employeeProfile) {
        // Delete all associated payroll records
        await Payroll.deleteMany({ employee: employeeProfile._id });
        // Delete the employee profile itself
        await Employee.deleteOne({ _id: employeeProfile._id });
      }
    } else if (userToDelete.role === "hr") {
      await HR.deleteOne({ user: userToDelete._id });
    }

    // Finally, delete the core user document
    await User.deleteOne({ _id: id });

    res
      .status(200)
      .send({ message: "User and all related data deleted successfully." });
  } catch (err) {
    console.error("Error deleting user:", err);
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Mark a conversation with a user as seen (read)
 */
exports.markConversationAsSeen = async (req, res) => {
  const adminUserId = req.userId;
  const { userId, userType } = req.params;

  try {
    const adminProfile = await require("../models/admin.model").findOne({
      user: adminUserId,
    });

    if (!adminProfile) {
      return res.status(404).send({ message: "Admin profile not found." });
    }

    // Determine sender userId based on userType if needed, but the Message schema stores sender.userId directly
    // The query should match messages where:
    // 1. receiver is the Admin's PROFILE ID (or User ID depending on how messages are stored? Message model says receiver: { type: mongoose.Schema.Types.ObjectId, refPath: 'receiverModel' })
    // Let's look at getDashboardSummary (line 21): receiver: adminProfile._id, receiverModel: "Admin"
    // So we use adminProfile._id.

    // And the SENDER is the user we are chatting with.
    // sender.userId should match the passed userId.
    // sender.userType should match the passed userType (normalized?)

    // NOTE: userType passed in URL is usually 'employee' or 'hr'.
    // Message schema stores sender.userType as 'HR', 'Employee', etc. Capitalized?
    // Let's check getDashboardSummary again... it does distinct("sender.userId").
    // To match sender, we should robustly match userType.

    // In employee.controller.js, I fixed "sender.userType": normalizedUserType.
    let normalizedUserType = userType;
    if (userType.toLowerCase() === "hr") normalizedUserType = "HR";
    if (userType.toLowerCase() === "employee") normalizedUserType = "Employee";
    if (userType.toLowerCase() === "admin") normalizedUserType = "Admin";


    const result = await Message.updateMany(
      {
        receiver: adminProfile._id,
        "receiverModel": "Admin",
        "sender.userId": userId,
        "sender.userType": normalizedUserType,
        isRead: false,
      },
      {
        $set: { isRead: true },
      }
    );

    res.status(200).send({
      message: "Conversation marked as seen.",
      updatedCount: result.modifiedCount,
    });
  } catch (err) {
    console.error("Error marking conversation as seen:", err);
    res.status(500).send({ message: err.message });
  }
};
