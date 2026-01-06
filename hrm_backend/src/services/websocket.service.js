const jwt = require("jsonwebtoken");
const User = require("../models/user.model");
const HR = require("../models/hr.model");
const Employee = require("../models/employee.model");
const Admin = require("../models/admin.model");

class WebSocketService {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map(); // userId -> socketId mapping
    this.userRooms = new Map(); // userId -> [room1, room2, ...] mapping
    this.roomMembers = new Map(); // roomName -> Set of userIds
  }

  initialize(server) {
    const { Server } = require("socket.io");
    this.io = new Server(server, {
      cors: {
        origin: "*", // Allow all origins for development
        methods: ["GET", "POST"],
        credentials: true,
      },
      transports: ["websocket", "polling"],
    });

    this.setupEventHandlers();
    // console.log("🔌 WebSocket server initialized");
  }

  setupEventHandlers() {
    this.io.on("connection", async (socket) => {
      // Handle authentication
      socket.on("authenticate", async (data) => {
        try {
          const user = await this.authenticateUser(data.token);
          if (user) {
            // console.log(`✅ User authenticated: ${user._id} (${user.role})`);
            await this.handleAuthenticatedConnection(socket, user);
          } else {
            socket.emit("authentication_failed", { message: "Invalid token" });
            socket.disconnect();
          }
        } catch (error) {
          
          socket.emit("authentication_failed", {
            message: "Authentication failed",
          });
          socket.disconnect();
        }
      });

      // Handle disconnection
      socket.on("disconnect", () => {
        this.handleDisconnection(socket);
      });

      // Handle room joining
      socket.on("join_room", (roomName) => {
        this.joinRoom(socket, roomName);
      });

      // Handle room leaving
      socket.on("leave_room", (roomName) => {
        this.leaveRoom(socket, roomName);
      });

      // Handle custom events
      socket.on("custom_event", (data) => {
        this.handleCustomEvent(socket, data);
      });

      // Typing indicator events
      socket.on("typing_indicator", (data = {}) => {
        try {
          const payload = this._serializeData({
            event: "typing_indicator",
            from: data.from || socket.profileId || socket.userId,
            to: data.to || null,
          });
          this.io.emit("typing_indicator", payload);
        } catch (e) {}
      });

      socket.on("typing_stopped", (data = {}) => {
        try {
          const payload = this._serializeData({
            event: "typing_stopped",
            from: data.from || socket.profileId || socket.userId,
            to: data.to || null,
          });
          this.io.emit("typing_stopped", payload);
        } catch (e) {}
      });
    });
  }

  async authenticateUser(token) {
    try {
      if (!token) {
        throw new Error("No token provided");
      }

      const decoded = jwt.verify(
        token,
        process.env.JWT_SECRET ||
          "your-super-secret-jwt-key-here-please-change-in-production"
      );

      // Support both 'userId' and 'id' from JWT payloads
      const userId = decoded.userId || decoded.id;
      if (!userId) {
        throw new Error("No user ID in token");
      }

      const user = await User.findById(userId).select("-password");

      if (!user) {
        // Try to find user in other models based on role
        let foundUser = null;
        if (decoded.role === "admin") {
          foundUser = await Admin.findOne({ user: userId });
        } else if (decoded.role === "hr") {
          foundUser = await HR.findOne({ user: userId });
        } else if (decoded.role === "employee") {
          foundUser = await Employee.findOne({ user: userId });
        }

        if (foundUser) {
          // Return the base user with role information
          const baseUser = await User.findById(userId).select("-password");
          if (baseUser) {
            baseUser.role = decoded.role;
            return baseUser;
          }
        }

        throw new Error("User not found in any model");
      }

      return user;
    } catch (error) {
      
      return null;
    }
  }

  async handleAuthenticatedConnection(socket, user) {
    // Store user connection - use the base user ID from the User model
    const userIdString = user._id.toString();
    this.connectedUsers.set(userIdString, socket.id);
    socket.userId = userIdString;
    socket.userRole = user.role;

    // Join user to appropriate rooms based on role
    await this.assignUserToRooms(socket, user);

    // Resolve profile id for presence
    const profileId = await this._resolveProfileId(user);
    socket.profileId = profileId;

    // Join profile-specific personal room as well to support profile-targeted messaging
    if (profileId) {
      const profileRoom = `user_${profileId}`;
      this.joinRoom(socket, profileRoom);
    }

    // Emit connection success
    socket.emit("authenticated", {
      userId: user._id,
      role: user.role,
      message: "Successfully connected to WebSocket",
    });

    // Notify all users about new connection so presence works across roles
    this.broadcastToAll("user_connected", {
      userId: user._id,
      profileId: profileId,
      name: user.name,
      role: user.role,
    });
    try {
      
    } catch (_) {}
  }

  async assignUserToRooms(socket, user) {
    const userId = user._id.toString();
    const rooms = [];

    // All users join their personal room
    const personalRoom = `user_${userId}`;
    this.joinRoom(socket, personalRoom);
    rooms.push(personalRoom);

    // Role-based room assignment
    switch (user.role) {
      case "admin":
        this.joinRoom(socket, "admin_room");
        this.joinRoom(socket, "company_wide");
        rooms.push("admin_room", "company_wide");
        break;

      case "hr":
        this.joinRoom(socket, "hr_room");
        this.joinRoom(socket, "company_wide");
        rooms.push("hr_room", "company_wide");
        break;

      case "employee":
        this.joinRoom(socket, "employee_room");
        this.joinRoom(socket, "company_wide");
        rooms.push("employee_room", "company_wide");

        // Join department room if employee has department
        const employee = await Employee.findOne({ user: user._id });
        if (employee && employee.department) {
          const deptRoom = `department_${employee.department}`;
          this.joinRoom(socket, deptRoom);
          rooms.push(deptRoom);
        }
        break;
    }

    // Store user's room memberships
    this.userRooms.set(userId, rooms);

    // console.log(`🏠 User ${user.name} joined rooms: ${rooms.join(", ")}`);
  }

  joinRoom(socket, roomName) {
    if (!socket.userId) {
      
      return;
    }

    socket.join(roomName);

    // Track room membership
    if (!this.roomMembers.has(roomName)) {
      this.roomMembers.set(roomName, new Set());
    }
    this.roomMembers.get(roomName).add(socket.userId);

    // console.log(`🏠 User ${socket.userId} joined room: ${roomName}`);

    // Emit room join confirmation
    socket.emit("room_joined", { room: roomName });
  }

  leaveRoom(socket, roomName) {
    if (!socket.userId) {
      
      return;
    }

    socket.leave(roomName);

    // Update room membership tracking
    if (this.roomMembers.has(roomName)) {
      this.roomMembers.get(roomName).delete(socket.userId);
      if (this.roomMembers.get(roomName).size === 0) {
        this.roomMembers.delete(roomName);
      }
    }

    // console.log(`🚪 User ${socket.userId} left room: ${roomName}`);

    // Emit room leave confirmation
    socket.emit("room_left", { room: roomName });
  }

  handleDisconnection(socket) {
    if (socket.userId) {
      // console.log(`🔌 User ${socket.userId} disconnected`);

      // Remove from connected users
      this.connectedUsers.delete(socket.userId);

      // Remove from all rooms
      const userRooms = this.userRooms.get(socket.userId) || [];
      userRooms.forEach((roomName) => {
        if (this.roomMembers.has(roomName)) {
          this.roomMembers.get(roomName).delete(socket.userId);
          if (this.roomMembers.get(roomName).size === 0) {
            this.roomMembers.delete(roomName);
          }
        }
      });

      // Remove user room memberships
      this.userRooms.delete(socket.userId);

      // Notify all users about disconnection so presence works across roles
      this.broadcastToAll("user_disconnected", {
        userId: socket.userId,
        profileId: socket.profileId || null,
      });
      try {
        console.log(
          ``
        );
      } catch (_) {}
    }
  }

  handleCustomEvent(socket, data) {
    // console.log(`📡 Custom event from ${socket.userId}:`, data);
    // Handle custom events here
  }

  // Broadcasting methods
  broadcastToRoom(roomName, event, data) {
    if (this.io) {
      this.io.to(roomName).emit(event, {
        ...data,
        timestamp: new Date(),
        room: roomName,
      });
      // console.log(`📢 Broadcasted '${event}' to room '${roomName}'`);
    }
  }

  // Helper function to deeply serialize data
  _serializeData(data) {
    try {
      // First attempt: JSON stringify/parse to catch any non-serializable data
      const serialized = JSON.parse(JSON.stringify(data));
      return serialized;
    } catch (error) {
      
      // Fallback: manually clean the data
      return this._cleanData(data);
    }
  }

  _cleanData(obj) {
    if (obj === null || obj === undefined) return obj;
    if (typeof obj !== "object") return obj;
    if (obj instanceof Date) return obj.toISOString();
    if (Array.isArray(obj)) return obj.map((item) => this._cleanData(item));

    const cleaned = {};
    for (const [key, value] of Object.entries(obj)) {
      if (value && typeof value === "object" && value._id) {
        // Handle MongoDB objects
        cleaned[key] = {
          _id: value._id.toString(),
          ...this._cleanData(value),
        };
      } else {
        cleaned[key] = this._cleanData(value);
      }
    }
    return cleaned;
  }

  broadcastToUser(userId, event, data) {
    // Try both string and ObjectId lookups
    let socketId = this.connectedUsers.get(userId);
    if (!socketId) {
      // Try with ObjectId if userId is a string
      const mongoose = require("mongoose");
      if (
        typeof userId === "string" &&
        mongoose.Types.ObjectId.isValid(userId)
      ) {
        socketId = this.connectedUsers.get(new mongoose.Types.ObjectId(userId));
      }
    }

    if (socketId && this.io) {
      try {
        const serializedData = this._serializeData({
          ...data,
          timestamp: new Date().toISOString(),
        });

        this.io.to(socketId).emit(event, serializedData);
        // console.log(`📤 Successfully sent ${event} to user ${userId}`);
      } catch (error) {
        
      }
    } else {
      // Fallback: emit to user's personal room
      if (this.io) {
        try {
          const room = `user_${userId}`;
          const serializedData = this._serializeData({
            ...data,
            timestamp: new Date().toISOString(),
          });
          this.io.to(room).emit(event, serializedData);
          // Also try profile-based room if this looks like an ObjectId string in payload
          if (data && data.receiver && data.receiver._id) {
            const profileRoom = `user_${data.receiver._id}`;
            this.io.to(profileRoom).emit(event, serializedData);
          }
        } catch (_) {}
      }
    }
  }

  broadcastToAll(event, data) {
    if (this.io) {
      try {
        const serializedData = this._serializeData({
          ...data,
          timestamp: new Date().toISOString(),
        });

        this.io.emit(event, serializedData);
        // console.log(`📢 Broadcasted '${event}' to all connected users`);
      } catch (error) {
      
      }
    }
  }

  async _resolveProfileId(user) {
    try {
      switch (user.role) {
        case "admin": {
          const admin = await Admin.findOne({ user: user._id }).select("_id");
          return admin ? admin._id.toString() : null;
        }
        case "hr": {
          const hr = await HR.findOne({ user: user._id }).select("_id");
          return hr ? hr._id.toString() : null;
        }
        case "employee": {
          const emp = await Employee.findOne({ user: user._id }).select("_id");
          return emp ? emp._id.toString() : null;
        }
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Utility methods
  getConnectedUsersCount() {
    return this.connectedUsers.size;
  }

  getRoomMembersCount(roomName) {
    return this.roomMembers.get(roomName)?.size || 0;
  }

  isUserConnected(userId) {
    return this.connectedUsers.has(userId);
  }

  getConnectionStats() {
    return {
      totalConnections: this.connectedUsers.size,
      rooms: Array.from(this.roomMembers.keys()).map((roomName) => ({
        name: roomName,
        memberCount: this.roomMembers.get(roomName).size,
      })),
    };
  }
}

// Export singleton instance
module.exports = new WebSocketService();
