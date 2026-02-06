const express = require("express");
const router = express.Router();
const websocketService = require("../services/websocket.service");
const websocketHandlers = require("../handlers/websocket.handlers");
const {
  verifyToken,
  isAdmin,
  isHrOrAdmin,
} = require("../middleware/auth.middleware");
const logger = require("../core/logger");

/**
 * WebSocket API Routes
 * These routes provide endpoints for testing and managing WebSocket connections
 */

// Get WebSocket connection statistics (Admin only)
router.get("/stats", verifyToken, isAdmin, (req, res) => {
  try {
    const stats = websocketService.getConnectionStats();
    res.json({
      success: true,
      data: stats,
      message: "WebSocket connection statistics retrieved successfully",
    });
  } catch (error) {
    logger.error("WebSocket stats retrieval failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/stats",
    });
    res.status(500).json({
      success: false,
      message: "Failed to retrieve WebSocket statistics",
    });
  }
});

// Test WebSocket connection (Admin/HR only)
router.post("/test-connection", verifyToken, isHrOrAdmin, (req, res) => {
  try {
    const { userId, event, data } = req.body;

    if (!userId || !event) {
      return res.status(400).json({
        success: false,
        message: "userId and event are required",
      });
    }

    // Check if user is connected
    const isConnected = websocketService.isUserConnected(userId);

    if (!isConnected) {
      return res.status(404).json({
        success: false,
        message: "User is not connected to WebSocket",
      });
    }

    // Send test event to user
    websocketService.broadcastToUser(userId, event, {
      ...data,
      testMessage: "This is a test message from the WebSocket API",
      timestamp: new Date(),
    });

    res.json({
      success: true,
      message: `Test event '${event}' sent to user ${userId}`,
    });
  } catch (error) {
    logger.error("WebSocket connection test failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/test-connection",
      userId: req.body?.userId,
    });
    res.status(500).json({
      success: false,
      message: "Failed to test WebSocket connection",
    });
  }
});

// Broadcast message to room (Admin only)
router.post("/broadcast-to-room", verifyToken, isAdmin, (req, res) => {
  try {
    const { room, event, data } = req.body;

    if (!room || !event) {
      return res.status(400).json({
        success: false,
        message: "room and event are required",
      });
    }

    // Send event to room
    websocketService.broadcastToRoom(room, event, {
      ...data,
      broadcastMessage: "This is a broadcast message from the WebSocket API",
      timestamp: new Date(),
    });

    res.json({
      success: true,
      message: `Event '${event}' broadcasted to room '${room}'`,
    });
  } catch (error) {
    logger.error("WebSocket room broadcast failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/broadcast-to-room",
      room: req.body?.room,
    });
    res.status(500).json({
      success: false,
      message: "Failed to broadcast to room",
    });
  }
});

// Broadcast message to all users (Admin only)
router.post("/broadcast-to-all", verifyToken, isAdmin, (req, res) => {
  try {
    const { event, data } = req.body;

    if (!event) {
      return res.status(400).json({
        success: false,
        message: "event is required",
      });
    }

    // Send event to all users
    websocketService.broadcastToAll(event, {
      ...data,
      broadcastMessage:
        "This is a broadcast message to all users from the WebSocket API",
      timestamp: new Date(),
    });

    res.json({
      success: true,
      message: `Event '${event}' broadcasted to all connected users`,
    });
  } catch (error) {
    logger.error("WebSocket broadcast to all failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/broadcast-to-all",
    });
    res.status(500).json({
      success: false,
      message: "Failed to broadcast to all users",
    });
  }
});

// Get connected users list (Admin only)
router.get("/connected-users", verifyToken, isAdmin, (req, res) => {
  try {
    const stats = websocketService.getConnectionStats();
    const connectedUsers = Array.from(websocketService.connectedUsers.keys());

    res.json({
      success: true,
      data: {
        totalConnections: stats.totalConnections,
        connectedUsers: connectedUsers,
        rooms: stats.rooms,
      },
      message: "Connected users retrieved successfully",
    });
  } catch (error) {
    logger.error("WebSocket connected users retrieval failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/connected-users",
    });
    res.status(500).json({
      success: false,
      message: "Failed to retrieve connected users",
    });
  }
});

// Test specific event handlers (Admin only)
router.post("/test-event-handler", verifyToken, isAdmin, (req, res) => {
  try {
    const { handler, data } = req.body;

    if (!handler) {
      return res.status(400).json({
        success: false,
        message: "handler is required",
      });
    }

    // Check if handler exists
    if (typeof websocketHandlers[handler] !== "function") {
      return res.status(400).json({
        success: false,
        message: `Handler '${handler}' does not exist`,
      });
    }

    // Call the handler
    websocketHandlers[handler](data);

    res.json({
      success: true,
      message: `Event handler '${handler}' executed successfully`,
    });
  } catch (error) {
    logger.error("WebSocket event handler test failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/test-event-handler",
      handler: req.body?.handler,
    });
    res.status(500).json({
      success: false,
      message: "Failed to test event handler",
    });
  }
});

// Health check for WebSocket service
router.get("/health", (req, res) => {
  try {
    const stats = websocketService.getConnectionStats();

    res.json({
      success: true,
      data: {
        status: "healthy",
        totalConnections: stats.totalConnections,
        rooms: stats.rooms.length,
        timestamp: new Date(),
      },
      message: "WebSocket service is healthy",
    });
  } catch (error) {
    logger.error("WebSocket health check failed", {
      error: error.message,
      stack: error.stack,
      endpoint: "/health",
    });
    res.status(500).json({
      success: false,
      message: "WebSocket service is unhealthy",
    });
  }
});

module.exports = router;
