const User = require("../models/user.model");
const Employee = require("../models/employee.model");
const HR = require("../models/hr.model");
const Admin = require("../models/admin.model");
const bcrypt = require("bcryptjs");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const logger = require("../core/logger");

/**
 * @description Get the profile of the currently authenticated user.
 */
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.userId).select("-password");
    if (!user) {
      return res.status(404).send({ message: "User not found." });
    }

    let profileData = {};
    let specificProfile;

    if (user.role === "employee") {
      specificProfile = await Employee.findOne({ user: user._id });
      if (specificProfile) {
        profileData = {
          fullName: specificProfile.name,
          mobileNumber: specificProfile.phone,
          jobTitle: specificProfile.jobTitle,
          subOrganisation: specificProfile.subOrganisation,
          profileImage: specificProfile.profilePic || "",
        };
      }
    } else if (user.role === "hr") {
      specificProfile = await HR.findOne({ user: user._id });
      if (specificProfile) {
        profileData = {
          fullName: specificProfile.name,
          mobileNumber: specificProfile.phone,
          profileImage: specificProfile.profilePic || "",
        };
      }
    } else if (user.role === "admin") {
      specificProfile = await Admin.findOne({ user: user._id });

      // If no admin profile exists, create one
      if (!specificProfile) {
        specificProfile = new Admin({ user: user._id });
        await specificProfile.save();
      }

      if (specificProfile) {
        profileData = {
          fullName: specificProfile.fullName || "",
          mobileNumber: specificProfile.mobileNumber || "",
          designation: specificProfile.designation || "",
          profileImage: specificProfile.profileImage || "",
        };
      }
    }

    const fullProfile = {
      id: user._id,
      email: user.email,
      role: user.role,
      ...profileData,
    };

    res.status(200).send(fullProfile);
  } catch (err) {
    logger.error("Get profile error", { error: err.message });
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Update the profile of the currently authenticated user.
 */
exports.updateProfile = async (req, res) => {
  const { fullName, mobileNumber, designation, profileImage } = req.body;

  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).send({ message: "User not found." });
    }

    const profileUpdatePayload = {};
    if (fullName !== undefined) profileUpdatePayload.fullName = fullName;
    if (mobileNumber !== undefined)
      profileUpdatePayload.mobileNumber = mobileNumber;
    if (designation !== undefined)
      profileUpdatePayload.designation = designation;
    if (profileImage !== undefined) {
      if (user.role === "admin") {
        profileUpdatePayload.profileImage = profileImage;
      } else {
        profileUpdatePayload.profilePic = profileImage;
      }
    }

    if (Object.keys(profileUpdatePayload).length === 0) {
      return res.status(400).send({ message: "No fields to update." });
    }

    if (user.role === "employee") {
      const employeePayload = {};
      if (fullName !== undefined) employeePayload.name = fullName;
      if (mobileNumber !== undefined) employeePayload.phone = mobileNumber;
      if (profileImage !== undefined) employeePayload.profilePic = profileImage;
      await Employee.updateOne({ user: req.userId }, employeePayload);
    } else if (user.role === "hr") {
      const hrPayload = {};
      if (fullName !== undefined) hrPayload.name = fullName;
      if (mobileNumber !== undefined) hrPayload.phone = mobileNumber;
      if (profileImage !== undefined) hrPayload.profilePic = profileImage;
      await HR.updateOne({ user: req.userId }, hrPayload);
    } else if (user.role === "admin") {
      // Check if admin profile exists, create if not
      let adminProfile = await Admin.findOne({ user: req.userId });
      if (!adminProfile) {
        adminProfile = new Admin({ user: req.userId });
        await adminProfile.save();
      }

      await Admin.updateOne({ user: req.userId }, profileUpdatePayload);
    }

    res.status(200).send({ message: "Profile updated successfully." });
  } catch (err) {
    logger.error("Update profile error", { error: err.message });
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Change the password of the currently authenticated user.
 */
exports.changePassword = async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).send({ message: "All fields are required." });
  }

  if (newPassword.length < 6) {
    return res
      .status(400)
      .send({ message: "New password must be at least 6 characters long." });
  }

  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).send({ message: "User not found." });
    }

    const passwordIsValid = bcrypt.compareSync(currentPassword, user.password);

    if (!passwordIsValid) {
      return res.status(401).send({ message: "Invalid current password." });
    }

    user.password = newPassword;
    await user.save();

    res.status(200).send({ message: "Password changed successfully." });
  } catch (err) {
    res.status(500).send({ message: err.message });
  }
};

/**
 * @description Update the FCM token of the currently authenticated user.
 */
exports.updateFcmToken = async (req, res) => {
  const { fcmToken } = req.body;

  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).send({ message: "User not found." });
    }

    // Fix: Remove this token from any OTHER user who might have it (e.g. same device, different login)
    if (fcmToken) {
      await User.updateMany(
        { fcmToken: fcmToken, _id: { $ne: user._id } },
        { $set: { fcmToken: null } },
      );
    }

    user.fcmToken = fcmToken;
    await user.save();

    res.status(200).send({ message: "FCM token updated successfully." });
  } catch (err) {
    logger.error("Update FCM token error", { error: err.message });
    res.status(500).send({ message: err.message });
  }
};

// Configure multer for image uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadPath = path.join(__dirname, "../../uploads/profiles");
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(
      null,
      `profile-${req.userId}-${uniqueSuffix}${path.extname(file.originalname)}`,
    );
  },
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase(),
    );
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error("Only image files (JPEG, JPG, PNG, GIF) are allowed!"));
    }
  },
});

/**
 * @description Upload profile image for the currently authenticated user.
 * Deletes old image file before saving new one.
 */
exports.uploadProfileImage = async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).send({ message: "User not found." });
    }

    if (!req.file) {
      return res.status(400).send({ message: "No image file provided." });
    }

    const newImagePath = `/uploads/profiles/${req.file.filename}`;

    // Get existing profile and delete old image file
    let existingProfile;
    let oldImagePath;

    if (user.role === "admin") {
      existingProfile = await Admin.findOne({ user: req.userId });
      oldImagePath = existingProfile?.profileImage;

      // Create admin profile if it doesn't exist
      if (!existingProfile) {
        existingProfile = new Admin({ user: req.userId });
        await existingProfile.save();
      }
    } else if (user.role === "employee") {
      existingProfile = await Employee.findOne({ user: req.userId });
      oldImagePath = existingProfile?.profilePic;
    } else if (user.role === "hr") {
      existingProfile = await HR.findOne({ user: req.userId });
      oldImagePath = existingProfile?.profilePic;
    }

    // Delete old image file from disk if it exists
    if (oldImagePath) {
      const cleanOldPath = oldImagePath.startsWith("/")
        ? oldImagePath.slice(1)
        : oldImagePath;
      const fullOldPath = path.join(__dirname, "../../", cleanOldPath);
      if (fs.existsSync(fullOldPath)) {
        try {
          fs.unlinkSync(fullOldPath);
          // // console.log(`Deleted old image: ${fullOldPath}`);
        } catch (deleteErr) {
          logger.error(`Failed to delete old image: ${deleteErr.message}`);
          // Continue anyway - don't fail the upload if deletion fails
        }
      }
    }

    // Update the profile with the new image path
    if (user.role === "admin") {
      await Admin.updateOne(
        { user: req.userId },
        { profileImage: newImagePath },
      );
    } else if (user.role === "employee") {
      await Employee.updateOne(
        { user: req.userId },
        { profilePic: newImagePath },
      );
    } else if (user.role === "hr") {
      await HR.updateOne({ user: req.userId }, { profilePic: newImagePath });
    }

    res.status(200).send({
      message: "Profile image uploaded successfully.",
      imagePath: newImagePath,
    });
  } catch (err) {
    logger.error("Upload profile image error", { error: err.message });

    // If upload failed, delete the newly uploaded file to avoid orphaned files
    if (req.file) {
      const newFilePath = path.join(
        __dirname,
        "../../uploads/profiles",
        req.file.filename,
      );
      if (fs.existsSync(newFilePath)) {
        try {
          fs.unlinkSync(newFilePath);
          // // console.log(`Cleaned up failed upload: ${newFilePath}`);
        } catch (deleteErr) {
          logger.error(
            `Failed to delete uploaded file after error: ${deleteErr.message}`,
          );
        }
      }
    }

    res.status(500).send({ message: err.message });
  }
};

// Export the upload middleware for use in routes
exports.uploadMiddleware = upload.single("profileImage");
