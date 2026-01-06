const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
const path = require("path");
const http = require("http");

require("dotenv").config();

const app = express();
const server = http.createServer(app);
const port = process.env.PORT || 5000;
const host = "0.0.0.0";

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// --- Health Check Endpoint ---
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "OK",
    timestamp: new Date().toISOString(),
    message: "Server is healthy.",
  });
});

// Test WebSocket endpoint
app.get("/test-websocket", (req, res) => {
  const websocketService = require("./src/services/websocket.service");
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
    res.status(500).json({
      status: "WebSocket serialization test failed",
      error: error.message,
    });
  }
});

const uri = process.env.MONGO_URI || "mongodb://localhost:27017/hrm_db";
mongoose
  .connect(uri)
  .then(() => console.log("✓ MongoDB connection successful"))
  .catch((err) => console.error("✗ MongoDB connection error:", err.message));

// --- API Routes ---
const authRouter = require("./src/api/auth.routes");
const adminRouter = require("./src/api/admin.routes");
const payrollRouter = require("./src/api/payroll.routes");
const userRouter = require("./src/api/user.routes");
const announcementRouter = require("./src/api/announcement.routes");
const leaveRequestRouter = require("./src/api/leaveRequest.routes");
const messageRouter = require("./src/api/message.routes");

app.use("/api/auth", authRouter);
app.use("/api/admin", adminRouter);
app.use("/api/payroll", payrollRouter);
app.use("/api/user", userRouter);
app.use("/api/announcements", announcementRouter);
app.use("/api/leave-requests", leaveRequestRouter);
app.use("/api/messages", messageRouter);

// Messaging system routes (encryption removed)
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

// Debug: Log all incoming requests to payslip-requests (BEFORE route registration)
app.use("/api/payslip-requests", (req, res, next) => {
  console.log(
    `🔍 [SERVER] ${req.method} ${req.originalUrl} - Path: ${req.path}`
  );
  next();
});

// Add these with your other route declarations

const attendanceRouter = require("./src/api/attendance.routes");
app.use("/api/attendance", attendanceRouter);

const holidayRouter = require("./src/api/holiday.routes");
app.use("/api/holidays", holidayRouter);

// 404 handler for debugging (must be after all routes)
app.use((req, res, next) => {
  if (req.path.includes("payslip") || req.originalUrl.includes("payslip")) {
    console.error(`❌ [404] Route not found: ${req.method} ${req.originalUrl}`);
    console.error(`❌ [404] Path: ${req.path}`);
    console.error(
      `❌ [404] Expected: POST /api/payslip-requests/:requestId/process`
    );
  }
  res.status(404).json({
    message: `Cannot ${req.method} ${req.originalUrl}`,
    path: req.path,
    originalUrl: req.originalUrl,
  });
});

// --- WebSocket Initialization ---
const websocketService = require("./src/services/websocket.service");
websocketService.initialize(server);

server.listen(port, host, () => {
  console.log(`\n🚀 Server is running on port: ${process.env.PORT || 3000}`);
  console.log(
    `🩺 Health check: http://${process.env.HOST}:${process.env.PORT || 3000
    }/health`
  );
  console.log(`🔌 WebSocket server initialized\n`);
});
