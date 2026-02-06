const jwt = require("jsonwebtoken");
const TokenBlocklist = require("../models/tokenBlocklist.model");
const logger = require("../core/logger");

exports.verifyToken = async (req, res, next) => {
  const authHeader = req.headers["authorization"];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res
      .status(403)
      .send({ message: "No token provided or invalid format!" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const isTokenBlocklisted = await TokenBlocklist.findOne({ token: token });

    if (isTokenBlocklisted) {
      return res.status(401).send({
        message: "Unauthorized! Token has been invalidated by logout.",
      });
    }

    const decoded = jwt.verify(
      token,
      process.env.JWT_SECRET ||
        "your-super-secret-jwt-key-here-please-change-in-production",
    );

    req.userId = decoded.id;
    req.userRole = decoded.role ? decoded.role.toLowerCase() : decoded.role;

    req.userRole = decoded.role ? decoded.role.toLowerCase() : decoded.role;

    next();
  } catch (err) {
    if (err.name === "TokenExpiredError") {
      return res
        .status(401)
        .send({ message: "Unauthorized! Token has expired." });
    }
    logger.error("Authentication error", { error: err.message });
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
  if (req.userRole === "hr" || req.userRole === "admin") {
    next();
    return;
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
