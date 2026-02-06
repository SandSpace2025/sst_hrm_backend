const jwt = require("jsonwebtoken");
const User = require("../models/user.model");
const logger = require("../core/logger");

// Rate limiting for WebSocket events
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = 100; // Max requests per window

/**
 * Authenticate WebSocket connection
 */
const authenticateSocket = async (socket, next) => {
  try {
    const token =
      socket.handshake.auth.token ||
      socket.handshake.headers.authorization?.replace("Bearer ", "");

    if (!token) {
      return next(new Error("Authentication token required"));
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select("-password");

    if (!user) {
      return next(new Error("User not found"));
    }

    socket.user = user;
    next();
  } catch (error) {
    logger.error("WebSocket authentication error", { error: error.message });
    next(new Error("Authentication failed"));
  }
};

/**
 * Authorize WebSocket actions based on user role
 */
const authorizeSocket = (requiredRoles = []) => {
  return (socket, next) => {
    if (!socket.user) {
      return next(new Error("User not authenticated"));
    }

    if (requiredRoles.length > 0 && !requiredRoles.includes(socket.user.role)) {
      return next(new Error("Insufficient permissions"));
    }

    next();
  };
};

/**
 * Rate limiting for WebSocket events
 */
const rateLimitSocket = (
  maxRequests = RATE_LIMIT_MAX_REQUESTS,
  windowMs = RATE_LIMIT_WINDOW,
) => {
  return (socket, next) => {
    const userId = socket.user?._id?.toString();
    if (!userId) {
      return next(new Error("User not identified for rate limiting"));
    }

    const now = Date.now();
    const userRequests = rateLimitMap.get(userId) || {
      count: 0,
      resetTime: now + windowMs,
    };

    // Reset counter if window has passed
    if (now > userRequests.resetTime) {
      userRequests.count = 0;
      userRequests.resetTime = now + windowMs;
    }

    // Check if user has exceeded rate limit
    if (userRequests.count >= maxRequests) {
      return next(new Error("Rate limit exceeded"));
    }

    // Increment request count
    userRequests.count++;
    rateLimitMap.set(userId, userRequests);

    next();
  };
};

/**
 * Validate WebSocket event data
 */
const validateEventData = (schema) => {
  return (socket, next) => {
    try {
      // Basic validation - you can integrate with Joi or similar
      if (schema && socket.data) {
        // Add validation logic here
      }
      next();
    } catch (error) {
      next(new Error("Invalid event data"));
    }
  };
};

/**
 * Handle WebSocket errors
 */
const handleSocketErrors = (socket) => {
  socket.on("error", (error) => {
    // Log error details
    logger.error("WebSocket Error for user", {
      userId: socket.user?._id,
      socketId: socket.id,
      error: error.message,
      timestamp: new Date(),
      userAgent: socket.handshake.headers["user-agent"],
      ip: socket.handshake.address,
    });

    // You can send error to external logging service here
  });
};

/**
 * Clean up rate limiting data periodically
 */
const cleanupRateLimit = () => {
  setInterval(() => {
    const now = Date.now();
    for (const [userId, data] of rateLimitMap.entries()) {
      if (now > data.resetTime) {
        rateLimitMap.delete(userId);
      }
    }
  }, RATE_LIMIT_WINDOW);
};

// Start cleanup process
cleanupRateLimit();

module.exports = {
  authenticateSocket,
  authorizeSocket,
  rateLimitSocket,
  handleSocketErrors,
};
