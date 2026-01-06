const Announcement = require("../models/announcement.model");
const Admin = require("../models/admin.model");
const websocketService = require("../services/websocket.service");
const { WEBSOCKET_EVENTS, WEBSOCKET_ROOMS } = require("../constants/websocket.events");

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
        fullName: announcement.createdBy.fullName,
        designation: announcement.createdBy.designation,
      },
      createdAt: announcement.createdAt.toISOString(),
    };

    // Determine target audience and send notifications
    if (announcement.audience === 'all') {
      // Notify all users via company_wide room
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
        {
          type: 'announcement',
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );

      // Also emit notification_sent event for better notification handling
      websocketService.broadcastToRoom(
        WEBSOCKET_ROOMS.COMPANY_WIDE,
        WEBSOCKET_EVENTS.NOTIFICATION_SENT,
        {
          type: 'announcement',
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );
    } else {
      // Notify specific audience (employees, hr, admin)
      const targetRoom = announcement.audience === 'employees'
        ? WEBSOCKET_ROOMS.EMPLOYEE_ROOM
        : announcement.audience === 'hr'
          ? WEBSOCKET_ROOMS.HR_ROOM
          : WEBSOCKET_ROOMS.ADMIN_ROOM;

      websocketService.broadcastToRoom(
        targetRoom,
        WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
        {
          type: 'announcement',
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );

      // Also emit notification_sent event for better notification handling
      websocketService.broadcastToRoom(
        targetRoom,
        WEBSOCKET_EVENTS.NOTIFICATION_SENT,
        {
          type: 'announcement',
          title: announcement.title,
          message: announcement.message,
          priority: announcement.priority,
          audience: announcement.audience,
          createdBy: announcementData.createdBy,
          createdAt: announcementData.createdAt,
          announcementId: announcementData.id,
        }
      );
    }

    // Emit WebSocket event existing code...
    // ... existing websocket sending code ...
    // Note: I will insert the notification code AFTER the websocket code, before res.json

    // --- Start Notification Logic ---
    try {
      let targetQuery = { fcmToken: { $ne: null, $exists: true } };

      if (announcement.audience === "employees") {
        targetQuery.role = "employee";
      } else if (announcement.audience === "hr") {
        targetQuery.role = "hr";
      } else if (announcement.audience === "admin") {
        targetQuery.role = "admin";
      }
      // if audience is 'all', we don't add role filter, just token check

      const usersWithTokens = await require("../models/user.model").find(targetQuery).select("fcmToken");
      const tokens = usersWithTokens.map(u => u.fcmToken).filter(t => t);

      if (tokens.length > 0) {
        const notificationService = require("../services/notification.service");
        // We pass the announcement ID in data to allow navigation on click
        // Route: /announcements/:id
        await notificationService.sendMulticastNotification(
          tokens,
          `📢 New Announcement: ${announcement.title}`,
          announcement.message.substring(0, 100) + (announcement.message.length > 100 ? "..." : ""),
          {
            type: "announcement",
            id: announcement._id.toString(),
            announcementId: announcement._id.toString(),
            title: announcement.title,
            message: announcement.message,
            priority: announcement.priority,
            audience: announcement.audience,
            createdBy: JSON.stringify(announcementData.createdBy),
            createdAt: announcementData.createdAt,
          }
        );
      }
    } catch (notifError) {
      console.error("Failed to send push notification:", notifError);
      // Don't block the response
    }
    // --- End Notification Logic ---

    // Original sending code omitted here because replace_file_content needs target.
    // I will append this to the end of the websocket block.

    // Actually, simpler to just start replacing from line 135
    res.status(201).json({
      message: "Announcement created successfully",
      announcement,
    });
  } catch (error) {
    console.error("Error creating announcement:", error);
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

    // Populate based on model type
    for (const announcement of announcements) {
      try {
        if (announcement.createdByModel === "Admin") {
          // // console.log("🔍 [DEBUG] Populating as Admin");
          await announcement.populate({
            path: "createdBy",
            model: "Admin",
            select: "fullName designation",
          });
        } else if (announcement.createdByModel === "HR") {
          // // console.log("🔍 [DEBUG] Populating as HR");
          await announcement.populate({
            path: "createdBy",
            model: "HR",
            select: "name email",
          });
        } else {
          // // console.log("🔍 [DEBUG] Legacy announcement - trying both models");
          // Fallback for legacy announcements - try Admin first, then HR
          try {
            await announcement.populate({
              path: "createdBy",
              model: "Admin",
              select: "fullName designation",
            });
            // // console.log("🔍 [DEBUG] Successfully populated as Admin (legacy)");
          } catch (adminError) {
            // // console.log("🔍 [DEBUG] Admin populate failed, trying HR");
            try {
              await announcement.populate({
                path: "createdBy",
                model: "HR",
                select: "name email",
              });
              // // console.log("🔍 [DEBUG] Successfully populated as HR (legacy)");
            } catch (hrError) { }
          }
        }
      } catch (populateError) {
        console.error(
          "❌ [ERROR] Error populating announcement:",
          populateError.message
        );
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
    console.error("Error fetching announcements:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

// Get a single announcement by ID
const getAnnouncementById = async (req, res) => {
  try {
    const { id } = req.params;

    const announcement = await Announcement.findById(id).populate(
      "createdBy",
      "fullName designation"
    );

    if (!announcement) {
      return res.status(404).json({ message: "Announcement not found" });
    }

    res.json({ announcement });
  } catch (error) {
    console.error("Error fetching announcement:", error);
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
      { new: true, runValidators: true }
    ).populate("createdBy", "fullName designation");

    res.json({
      message: "Announcement updated successfully",
      announcement: updatedAnnouncement,
    });
  } catch (error) {
    console.error("Error updating announcement:", error);
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
    console.error("Error deleting announcement:", error);
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
    console.error("Error fetching announcements for audience:", error);
    res.status(500).json({ message: "Internal server error" });
  }
};

module.exports = {
  createAnnouncement,
  getAnnouncements,
  getAnnouncementById,
  updateAnnouncement,
  deleteAnnouncement,
  getAnnouncementsForAudience,
};
