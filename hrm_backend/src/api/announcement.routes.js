const express = require("express");
const router = express.Router();
const announcementController = require("../controllers/announcement.controller");
const authMiddleware = require("../middleware/auth.middleware");

// All announcement routes require authentication
router.use(authMiddleware.verifyToken);

// Create announcement (Admin only)
router.post("/", announcementController.createAnnouncement);

// Get all announcements with filtering (Admin only)
router.get("/", announcementController.getAnnouncements);

// Get announcements for specific audience (Public for authenticated users)
router.get(
  "/audience/:audience",
  announcementController.getAnnouncementsForAudience
);

// Get single announcement by ID
router.get("/:id", announcementController.getAnnouncementById);

// Update announcement (Admin only - creator only)
router.put("/:id", announcementController.updateAnnouncement);

// Delete announcement (Admin only - creator only)
router.delete("/:id", announcementController.deleteAnnouncement);

module.exports = router;
