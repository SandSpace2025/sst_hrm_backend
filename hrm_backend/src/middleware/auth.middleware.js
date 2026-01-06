const jwt = require("jsonwebtoken");
const TokenBlocklist = require("../models/tokenBlocklist.model");

exports.verifyToken = async (req, res, next) => {
  const authHeader = req.headers["authorization"];

  // Only log for HR leave data requests to avoid spam
  if (req.path && req.path.includes("/leave-data")) {
    // // console.log("🔐 Auth Middleware - Processing request for:", req.path);
  }

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    if (req.path && req.path.includes("/leave-data")) {
      // // console.log("❌ Auth Middleware - No valid authorization header");
    }
    return res
      .status(403)
      .send({ message: "No token provided or invalid format!" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const isTokenBlocklisted = await TokenBlocklist.findOne({ token: token });

    if (isTokenBlocklisted) {
      if (req.path && req.path.includes("/leave-data")) {
        // // console.log("❌ Auth Middleware - Token is blocklisted");
      }
      return res.status(401).send({
        message: "Unauthorized! Token has been invalidated by logout.",
      });
    }

    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET ||
      "your-super-secret-jwt-key-here-please-change-in-production"
    );

    req.userId = decoded.id;
    req.userRole = decoded.role ? decoded.role.toLowerCase() : decoded.role;

    if (req.path && req.path.includes("/leave-data")) {
      // // console.log("✅ Auth Middleware - Token verified successfully");
      // // console.log("🔐 Auth Middleware - User ID:", req.userId);
      // // console.log("🔐 Auth Middleware - User Role:", req.userRole);
    }

    next();
  } catch (err) {
    if (req.path && req.path.includes("/leave-data")) {
    }
    if (err.name === "TokenExpiredError") {
      return res
        .status(401)
        .send({ message: "Unauthorized! Token has expired." });
    }
    return res.status(401).send({ message: "Unauthorized! Invalid token." });
  }
};

exports.isAdmin = (req, res, next) => {
  if (req.userRole === "admin") {
    next();
    return;
  }
  res.status(403).send({ message: "Require Admin Role!" });
};

exports.isHrOrAdmin = (req, res, next) => {
  // Only log for HR leave data requests to avoid spam
  if (req.path && req.path.includes("/leave-data")) {
    // // console.log("🔐 HR Role Middleware - Checking role for:", req.path);
    // // console.log("🔐 HR Role Middleware - User role:", req.userRole);
  }

  if (req.userRole === "hr" || req.userRole === "admin") {
    if (req.path && req.path.includes("/leave-data")) {
      // // console.log("✅ HR Role Middleware - Role check passed");
    }
    next();
    return;
  }

  if (req.path && req.path.includes("/leave-data")) {
    // // console.log("❌ HR Role Middleware - Role check failed");
  }
  res.status(403).send({ message: "Require HR or Admin Role!" });
};

exports.isEmployee = (req, res, next) => {
  if (req.userRole === "employee") {
    next();
    return;
  }
  res.status(403).send({ message: "Require Employee Role!" });
};
