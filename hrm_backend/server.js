// Core dependencies
const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
const path = require("path");
const http = require("http");
require("dotenv").config();

// Logger
const logger = require("./src/core/logger");

// Controllers
const announcementController = require("./src/controllers/announcement.controller");

// Services
const websocketService = require("./src/services/websocket.service");

// API Routes
const authRouter = require("./src/api/auth.routes");
const adminRouter = require("./src/api/admin.routes");
const payrollRouter = require("./src/api/payroll.routes");
const userRouter = require("./src/api/user.routes");
const announcementRouter = require("./src/api/announcement.routes");
const leaveRequestRouter = require("./src/api/leaveRequest.routes");
const messageRouter = require("./src/api/message.routes");
const conversationRouter = require("./src/api/conversation.routes");
const messageV2Router = require("./src/api/message-v2.routes");
const hrRouter = require("./src/api/hr.routes");
const employeeRouter = require("./src/api/employee.routes");
const eodRoutes = require("./src/api/eod.routes");
const leaveRoutes = require("./src/api/leave.routes");
const leaveManagementRoutes = require("./src/api/leaveManagement.routes");
const messagingPermissionRoutes = require("./src/api/messagingPermission.routes");
const payslipRequestRoutes = require("./src/api/payslipRequest.routes");
const websocketRoutes = require("./src/api/websocket.routes");
const payslipsRouter = require("./src/api/payslips.routes");
const notificationRouter = require("./src/routes/notification.routes");
const attendanceRouter = require("./src/api/attendance.routes");
const holidayRouter = require("./src/api/holiday.routes");

// Initialize Express app and HTTP server
const app = express();
const server = http.createServer(app);
const port = process.env.PORT || 5000;
const host = process.env.HOST || "0.0.0.0";

// Middleware
app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// Health check endpoint
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "OK",
    timestamp: new Date().toISOString(),
    message: "Server is healthy.",
    environment: process.env.NODE_ENV || "development",
  });
});

// WebSocket test endpoint (development only)
if (process.env.NODE_ENV === "development") {
  app.get("/test-websocket", (req, res) => {
    const testData = {
      messageId: "test_123",
      sender: {
        _id: "sender_123",
        name: "Test Sender",
        email: "test@test.com",
      },
      receiver: {
        _id: "receiver_123",
        name: "Test Receiver",
        email: "receiver@test.com",
      },
      subject: "Test Message",
      content: "This is a test message",
      messageType: "test_message",
      priority: "normal",
      createdAt: new Date().toISOString(),
    };

    try {
      const serialized = websocketService._serializeData(testData);
      res.json({
        status: "WebSocket serialization test passed",
        originalData: testData,
        serializedData: serialized,
      });
    } catch (error) {
      logger.error("WebSocket test failed", { error: error.message });
      res.status(500).json({
        status: "WebSocket serialization test failed",
        error: error.message,
      });
    }
  });
}

// Database connection
const uri = process.env.MONGO_URI || "mongodb://localhost:27017/hrm_db";
mongoose
  .connect(uri)
  .then(() => logger.info("MongoDB connection successful"))
  .catch((err) => {
    logger.error("MongoDB connection error", { error: err.message });
    process.exit(1);
  });

// MongoDB connection event handlers
mongoose.connection.on("disconnected", () => {
  logger.warn("MongoDB disconnected");
});

mongoose.connection.on("reconnected", () => {
  logger.info("MongoDB reconnected");
});

// API route registration
app.use("/api/auth", authRouter);
app.use("/api/admin", adminRouter);
app.use("/api/payroll", payrollRouter);
app.use("/api/user", userRouter);
app.use("/api/announcements", announcementRouter);
app.use("/api/leave-requests", leaveRequestRouter);
app.use("/api/messages", messageRouter);
app.use("/api/conversations", conversationRouter);
app.use("/api/messages-v2", messageV2Router);
app.use("/api/hr", hrRouter);
app.use("/api/employee", employeeRouter);
app.use("/api/eod", eodRoutes);
app.use("/api/leave", leaveRoutes);
app.use("/api/leave-management", leaveManagementRoutes);
app.use("/api/messaging-permissions", messagingPermissionRoutes);
app.use("/api/payslip-requests", payslipRequestRoutes);
app.use("/api/payslips", payslipsRouter);
app.use("/api/websocket", websocketRoutes);
app.use("/api/notifications", notificationRouter);
app.use("/api/attendance", attendanceRouter);
app.use("/api/holidays", holidayRouter);

// Global error handler
app.use((err, req, res, next) => {
  logger.error("Unhandled error", {
    error: err.message,
    stack: err.stack,
    method: req.method,
    url: req.originalUrl,
  });

  const statusCode = err.statusCode || 500;
  const message =
    process.env.NODE_ENV === "production"
      ? "Internal server error"
      : err.message;

  res.status(statusCode).json({
    success: false,
    message,
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
});

// 404 handler (must be after all routes)
app.use((req, res) => {
  logger.warn(`Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
});

// Scheduled tasks
announcementController.cleanupOldAnnouncements();
setInterval(
  () => {
    announcementController.cleanupOldAnnouncements();
  },
  24 * 60 * 60 * 1000,
);

// WebSocket initialization
websocketService.initialize(server);

// Start server
server.listen(port, host, () => {
  logger.info(`Server started on ${host}:${port}`);
  logger.info(`Environment: ${process.env.NODE_ENV || "development"}`);
  logger.info(`Health check: http://${host}:${port}/health`);
  logger.info("WebSocket server initialized");
});

// Graceful shutdown
const gracefulShutdown = (signal) => {
  logger.info(`${signal} received, starting graceful shutdown`);

  server.close(() => {
    logger.info("HTTP server closed");

    mongoose.connection.close(false, () => {
      logger.info("MongoDB connection closed");
      process.exit(0);
    });
  });

  // Force shutdown after 30 seconds
  setTimeout(() => {
    logger.error("Forced shutdown after timeout");
    process.exit(1);
  }, 30000);
};

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

// Unhandled rejection handler
process.on("unhandledRejection", (reason, promise) => {
  logger.error("Unhandled Promise Rejection", {
    reason: reason,
    promise: promise,
  });
});

// Uncaught exception handler
process.on("uncaughtException", (error) => {
  logger.error("Uncaught Exception", {
    error: error.message,
    stack: error.stack,
  });
  process.exit(1);
});
