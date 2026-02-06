const Announcement = require("../models/announcement.model");
const Admin = require("../models/admin.model");
const websocketService = require("../services/websocket.service");
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");
const logger = require("../core/logger");

// Create a new announcement
const createAnnouncement = async (req, res) => {
  try {
    const { title, message, audience, priority, scheduledFor, expiresAt } =
      req.body;
    const adminId = req.userId; // User ID from auth middleware

    // Find the admin to get the admin document ID
    const admin = await Admin.findOne({ user: adminId });
    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const announcement = new Announcement({
      title,
      message,
      audience,
      priority,
      createdBy: admin._id,
      createdByModel: "Admin",
      scheduledFor: scheduledFor ? new Date(scheduledFor) : null,
      expiresAt: expiresAt ? new Date(expiresAt) : null,
    });

    await announcement.save();

    // Populate the createdBy field for response based on model type
    if (announcement.createdByModel === "Admin") {
      await announcement.populate({
        path: "createdBy",
        model: "Admin",
        select: "fullName designation",
      });
    } else if (announcement.createdByModel === "HR") {
      await announcement.populate({
        path: "createdBy",
        model: "HR",
        select: "fullName email",
      });
    }

    // Emit WebSocket event for real-time notification
    const announcementData = {
      id: announcement._id.toString(),
      title: announcement.title,
      message: announcement.message,
      priority: announcement.priority,
      audience: announcement.audience,
      createdBy: {
        _id: announcement.createdBy._id.toString(),
        userId: admin.user.toString(), // Include User ID for frontend filtering
        fullName: announcement.createdBy.fullName,
        designation: announcement.createdBy.designation,
      },
      createdAt: announcement.createdAt.toISOString(),
    };

    // Determine target audience and send notifications
    if (announcement.audience === "all") {
      // Notify all users via company_wide room
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        },
      );

      // Also emit notification_sent event for better notification handling
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.NOTIFICATION_SENT,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        },
      );
    } else {
      // Notify specific audience (employees, hr, admin)
      const targetRoom =
        announcement.audience === "employees"
          ? WEBSOCKET_ROOMS.EMPLOYEE_ROOM
          : announcement.audience === "hr"
            ? WEBSOCKET_ROOMS.HR_ROOM
            : WEBSOCKET_ROOMS.ADMIN_ROOM;

      websocketService.broadcastToRoom(
        targetRoom,
        WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        },
      );

      // Also emit notification_sent event for better notification handling
      websocketService.broadcastToRoom(
        targetRoom,
        WEBSOCKET_EVENTS.NOTIFICATION_SENT,
        {
          type: "announcement",
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        },
      );
    }

    // Send notifications to target users
    try {
      const User = require("../models/user.model");
      const Notification = require("../models/notification.model");

      let targetQuery = {};
      if (announcement.audience === "employees") {
        targetQuery.role = "employee";
      } else if (announcement.audience === "hr") {
        targetQuery.role = "hr";
      } else if (announcement.audience === "admin") {
        targetQuery.role = "admin";
      }

      targetQuery._id = { $ne: req.userId };
      const targetUsers = await User.find(targetQuery).select("_id fcmToken");

      if (targetUsers.length > 0) {
        const notificationsToCreate = targetUsers.map((user) => ({
          recipient: user._id,
          type: "announcement",
          title: `📢 New Announcement: ${announcement.title}`,
          body: announcement.message.substring(0, 50) + "...",
          data: {
            type: "announcement",
            id: announcement._id.toString(),
            announcementId: announcement._id.toString(),
            title: announcement.title,
            priority: announcement.priority,
            audience: announcement.audience,
          },
          isRead: false,
          createdAt: new Date(),
        }));

        try {
          await Notification.insertMany(notificationsToCreate);
        } catch (dbErr) {
          logger.error("Failed to bulk insert announcement notifications", {
            error: dbErr.message,
            stack: dbErr.stack,
            count: notificationsToCreate.length,
          });
        }
      }

      const usersWithTokens = targetUsers.filter((u) => u.fcmToken);
      const tokens = usersWithTokens.map((u) => u.fcmToken);

      if (tokens.length > 0) {
        const message = {
          notification: {
            title: `📢 New Announcement: ${announcement.title}`,
            body: announcement.message.substring(0, 100),
          },
          android: {
            notification: {
              channelId: "hrm_notifications_v2",
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              priority: "high",
              sound: "default",
            },
          },
          data: {
            type: "announcement",
            id: announcement._id.toString(),
            announcementId: announcement._id.toString(),
            title: announcement.title,
            priority: announcement.priority,
            message: announcement.message,
            audience: announcement.audience,
            createdByModel: announcement.createdByModel,
            createdBy: JSON.stringify({
              fullName: announcementData.createdBy.fullName,
              designation: announcementData.createdBy.designation,
              userId: announcementData.createdBy.userId,
              _id: announcementData.createdBy._id,
            }),
            createdAt: announcementData.createdAt,
          },
          tokens: tokens,
        };

        const { admin } = require("../config/firebase");
        if (admin) {
          await admin.messaging().sendEachForMulticast(message);
        }
      }
    } catch (notifError) {
      logger.error("Failed to process announcement notifications", {
        error: notifError.message,
        stack: notifError.stack,
        announcementId: announcement._id,
      });
    }
    res.status(201).json({
      message: "Announcement created successfully",
      announcement,
    });
  } catch (error) {
    logger.error("Announcement creation failed", {
      error: error.message,
      stack: error.stack,
      adminId: req.userId,
    });
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get all announcements with filtering and pagination
const getAnnouncements = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      audience,
      priority,
      isActive = true,
      sortBy = "createdAt",
      sortOrder = "desc",
    } = req.query;

    const query = { isActive };

    if (audience) {
      query.audience = audience;
    }

    if (priority) {
      query.priority = priority;
    }

    if (req.query.onlyMine === "true") {
      const adminId = req.userId;
      const admin = await Admin.findOne({ user: adminId });
      if (admin) {
        query.createdBy = admin._id;
      }
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === "desc" ? -1 : 1;

    const announcements = await Announcement.find(query)
      .sort(sortOptions)
      .skip(skip)
      .limit(parseInt(limit));

    for (const announcement of announcements) {
      try {
        if (announcement.createdByModel === "Admin") {
          await announcement.populate({
            path: "createdBy",
            model: "Admin",
            select: "fullName designation",
          });
        } else if (announcement.createdByModel === "HR") {
          await announcement.populate({
            path: "createdBy",
            model: "HR",
            select: "name email",
          });
        } else {
          // Fallback for legacy announcements
          try {
            await announcement.populate({
              path: "createdBy",
              model: "Admin",
              select: "fullName designation",
            });
          } catch (adminError) {
            try {
              await announcement.populate({
                path: "createdBy",
                model: "HR",
                select: "name email",
              });
            } catch (hrError) {}
          }
        }
      } catch (populateError) {
        logger.error("Error populating announcement", {
          error: populateError.message,
          announcementId: announcement._id,
        });
      }
    }

    const total = await Announcement.countDocuments(query);

    res.json({
      announcements,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    logger.error("Fetching announcements failed", {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get a single announcement by ID
const getAnnouncementById = async (req, res) => {
  try {
    const { id } = req.params;

    const announcement = await Announcement.findById(id).populate(
      "createdBy",
      "fullName designation",
    );

    if (!announcement) {
      return res.status(404).json({ message: "Announcement not found" });
    }

    res.json({ announcement });
  } catch (error) {
    logger.error("Fetching announcement by ID failed", {
      error: error.message,
      stack: error.stack,
      announcementId: req.params.id,
    });
    res.status(500).json({ message: "Internal server error" });
  }
};

// Update an announcement
const updateAnnouncement = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      title,
      message,
      audience,
      priority,
      isActive,
      scheduledFor,
      expiresAt,
    } = req.body;

    const announcement = await Announcement.findById(id);
    if (!announcement) {
      return res.status(404).json({ message: "Announcement not found" });
    }

    // Check if the user is the creator of the announcement
    const adminId = req.userId;
    const admin = await Admin.findOne({ user: adminId });
    if (!admin || announcement.createdBy.toString() !== admin._id.toString()) {
      return res
        .status(403)
        .json({ message: "Not authorized to update this announcement" });
    }

    const updateData = {};
    if (title !== undefined) updateData.title = title;
    if (message !== undefined) updateData.message = message;
    if (audience !== undefined) updateData.audience = audience;
    if (priority !== undefined) updateData.priority = priority;
    if (isActive !== undefined) updateData.isActive = isActive;
    if (scheduledFor !== undefined)
      updateData.scheduledFor = scheduledFor ? new Date(scheduledFor) : null;
    if (expiresAt !== undefined)
      updateData.expiresAt = expiresAt ? new Date(expiresAt) : null;

    const updatedAnnouncement = await Announcement.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true },
    ).populate("createdBy", "fullName designation");

    res.json({
      message: "Announcement updated successfully",
      announcement: updatedAnnouncement,
    });
  } catch (error) {
    logger.error("Updating announcement failed", {
      error: error.message,
      stack: error.stack,
      announcementId: req.params.id,
    });
    res.status(500).json({ message: "Internal server error" });
  }
};

// Delete an announcement (soft delete by setting isActive to false)
const deleteAnnouncement = async (req, res) => {
  try {
    const { id } = req.params;

    const announcement = await Announcement.findById(id);
    if (!announcement) {
      return res.status(404).json({ message: "Announcement not found" });
    }

    // Check if the user is the creator of the announcement
    const adminId = req.userId;
    const admin = await Admin.findOne({ user: adminId });
    if (!admin || announcement.createdBy.toString() !== admin._id.toString()) {
      return res
        .status(403)
        .json({ message: "Not authorized to delete this announcement" });
    }

    await Announcement.findByIdAndUpdate(id, { isActive: false });

    res.json({ message: "Announcement deleted successfully" });
  } catch (error) {
    logger.error("Deleting announcement failed", {
      error: error.message,
      stack: error.stack,
      announcementId: req.params.id,
    });
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get announcements for a specific audience (for employees/HR to view)
const getAnnouncementsForAudience = async (req, res) => {
  try {
    const { audience } = req.params;
    const { page = 1, limit = 10 } = req.query;

    const query = {
      isActive: true,
      $or: [{ audience: audience }, { audience: "all" }],
    };

    // Filter out expired announcements
    query.$and = [
      {
        $or: [
          { expiresAt: { $exists: false } },
          { expiresAt: null },
          { expiresAt: { $gt: new Date() } },
        ],
      },
    ];

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const announcements = await Announcement.find(query)
      .populate("createdBy", "fullName designation")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Announcement.countDocuments(query);

    res.json({
      announcements,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(total / parseInt(limit)),
        totalItems: total,
        itemsPerPage: parseInt(limit),
      },
    });
  } catch (error) {
    logger.error("Fetching announcements for audience failed", {
      error: error.message,
      stack: error.stack,
      audience: req.params.audience,
    });
    res.status(500).json({ message: "Internal server error" });
  }
};

// Cleanup announcements older than 5 days
const cleanupOldAnnouncements = async () => {
  try {
    const fiveDaysAgo = new Date();
    fiveDaysAgo.setDate(fiveDaysAgo.getDate() - 5);

    const result = await Announcement.deleteMany({
      createdAt: { $lt: fiveDaysAgo },
    });

    if (result.deletedCount > 0) {
      logger.info(`Deleted ${result.deletedCount} old announcements`);
    }
  } catch (error) {
    logger.error("Cleanup old announcements failed", {
      error: error.message,
      stack: error.stack,
    });
  }
};

module.exports = {
  createAnnouncement,
  getAnnouncements,
  getAnnouncementById,
  updateAnnouncement,
  deleteAnnouncement,
  getAnnouncementsForAudience,
  cleanupOldAnnouncements,
};
