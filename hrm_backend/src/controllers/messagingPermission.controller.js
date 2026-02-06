const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");
const logger = require("../core/logger");

/**
 * @description Check if employee can message (permission valid and not expired)
 */
exports.checkMessagingPermission = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const employeeProfile = await Employee.findOne({ user: employeeUserId });

    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    const now = new Date();
    const permissions = employeeProfile.messagingPermissions;

    // Check if permission exists and is not expired
    const canMessage =
      permissions.canMessage &&
      permissions.expiresAt &&
      permissions.expiresAt > now;

    // If permission is expired, automatically revoke it
    if (
      permissions.canMessage &&
      permissions.expiresAt &&
      permissions.expiresAt <= now
    ) {
      employeeProfile.messagingPermissions.canMessage = false;
      employeeProfile.messagingPermissions.grantedBy = null;
      employeeProfile.messagingPermissions.grantedAt = null;
      employeeProfile.messagingPermissions.expiresAt = null;
      await employeeProfile.save();
    }

    res.status(200).json({
      canMessage,
      permissions: {
        canMessage: employeeProfile.messagingPermissions.canMessage,
        grantedBy: employeeProfile.messagingPermissions.grantedBy,
        grantedAt: employeeProfile.messagingPermissions.grantedAt,
        expiresAt: employeeProfile.messagingPermissions.expiresAt,
        lastRequestedAt: employeeProfile.messagingPermissions.lastRequestedAt,
      },
    });
  } catch (err) {
    logger.error("Error checking messaging permission", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Request messaging permission (employee)
 */
exports.requestMessagingPermission = async (req, res) => {
  try {
    const employeeUserId = req.userId;
    const { adminId } = req.body; // Admin ID to request permission from

    const employeeProfile = await Employee.findOne({ user: employeeUserId });

    if (!employeeProfile) {
      return res.status(404).json({ message: "Employee profile not found" });
    }

    // Verify admin exists if adminId is provided
    if (adminId) {
      const admin = await Admin.findById(adminId);
      if (!admin) {
        return res.status(404).json({ message: "Admin not found" });
      }
    }

    // Update last requested timestamp and requested from admin
    employeeProfile.messagingPermissions.lastRequestedAt = new Date();
    employeeProfile.messagingPermissions.requestedFrom = adminId || null;
    await employeeProfile.save();

    res.status(200).json({
      message: "Messaging permission requested successfully",
      lastRequestedAt: employeeProfile.messagingPermissions.lastRequestedAt,
      requestedFrom: employeeProfile.messagingPermissions.requestedFrom,
    });
  } catch (err) {
    logger.error("Error requesting messaging permission", {
      error: err.message,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Grant messaging permission (admin only)
 */
exports.grantMessagingPermission = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const adminUserId = req.userId;
    const { durationHours = 48 } = req.body; // Default 48 hours

    // Verify admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Find employee
    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Calculate expiration time
    const now = new Date();
    const expiresAt = new Date(now.getTime() + durationHours * 60 * 60 * 1000);

    // Grant permission
    employee.messagingPermissions.canMessage = true;
    employee.messagingPermissions.grantedBy = admin._id;
    employee.messagingPermissions.grantedAt = now;
    employee.messagingPermissions.expiresAt = expiresAt;

    await employee.save();

    res.status(200).json({
      message: "Messaging permission granted successfully",
      permissions: {
        canMessage: employee.messagingPermissions.canMessage,
        grantedBy: employee.messagingPermissions.grantedBy,
        grantedAt: employee.messagingPermissions.grantedAt,
        expiresAt: employee.messagingPermissions.expiresAt,
      },
    });
  } catch (err) {
    logger.error("Error granting messaging permission", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Revoke messaging permission (admin only)
 */
exports.revokeMessagingPermission = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const adminUserId = req.userId;

    // Verify admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Find employee
    const employee = await Employee.findById(employeeId);
    if (!employee) {
      return res.status(404).json({ message: "Employee not found" });
    }

    // Revoke permission
    employee.messagingPermissions.canMessage = false;
    employee.messagingPermissions.grantedBy = null;
    employee.messagingPermissions.grantedAt = null;
    employee.messagingPermissions.expiresAt = null;

    await employee.save();

    res.status(200).json({
      message: "Messaging permission revoked successfully",
      permissions: {
        canMessage: employee.messagingPermissions.canMessage,
        grantedBy: employee.messagingPermissions.grantedBy,
        grantedAt: employee.messagingPermissions.grantedAt,
        expiresAt: employee.messagingPermissions.expiresAt,
      },
    });
  } catch (err) {
    logger.error("Error revoking messaging permission", { error: err.message });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get all employees with messaging permission requests (admin only)
 */
exports.getMessagingPermissionRequests = async (req, res) => {
  try {
    const adminUserId = req.userId;

    // Verify admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    // Find employees who have requested messaging permission
    const employees = await Employee.find({
      "messagingPermissions.lastRequestedAt": { $exists: true, $ne: null },
      "messagingPermissions.canMessage": false,
    })
      .populate("user", "email")
      .select("name email employeeId messagingPermissions")
      .sort({ "messagingPermissions.lastRequestedAt": -1 });

    res.status(200).json({
      employees,
      total: employees.length,
    });
  } catch (err) {
    logger.error("Error getting messaging permission requests", {
      error: err.message,
    });
    res.status(500).json({ message: err.message });
  }
};

/**
 * @description Get all employees with active messaging permissions (admin only)
 */
exports.getActiveMessagingPermissions = async (req, res) => {
  try {
    const adminUserId = req.userId;

    // Verify admin
    const admin = await Admin.findOne({ user: adminUserId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const now = new Date();

    // Find employees with active messaging permissions
    const employees = await Employee.find({
      "messagingPermissions.canMessage": true,
      "messagingPermissions.expiresAt": { $gt: now },
    })
      .populate("user", "email")
      .populate("messagingPermissions.grantedBy", "fullName")
      .select("name email employeeId messagingPermissions")
      .sort({ "messagingPermissions.expiresAt": 1 });

    res.status(200).json({
      employees,
      total: employees.length,
    });
  } catch (err) {
    logger.error("Error getting active messaging permissions", {
      error: err.message,
    });
    res.status(500).json({ message: err.message });
  }
};
