const User = require("../models/user.model");
const HR = require("../models/hr.model"); // Import HR model
const Employee = require("../models/employee.model"); // Import Employee model
const TokenBlocklist = require("../models/tokenBlocklist.model");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const mongoose = require("mongoose");

exports.login = async (req, res) => {
  try {
    const user = await User.findOne({ email: req.body.email });

    if (!user) {
      return res.status(404).send({ message: "User Not found." });
    }

    const passwordIsValid = bcrypt.compareSync(
      req.body.password,
      user.password
    );

    if (!passwordIsValid) {
      return res.status(401).send({
        accessToken: null,
        message: "Invalid Password!",
      });
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET ||
        "your-super-secret-jwt-key-here-please-change-in-production",
      {
        expiresIn: 86400, // 24 hours
      }
    );

    res.status(200).send({
      id: user._id,
      email: user.email,
      role: user.role,
      accessToken: token,
    });
  } catch (err) {
    res.status(500).send({ message: err.message });
  }
};

exports.logout = async (req, res) => {
  try {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (!token) {
      return res.status(400).send({ message: "No token provided." });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const expiresAt = new Date(decoded.exp * 1000);

    const blocklistedToken = new TokenBlocklist({
      token: token,
      expiresAt: expiresAt,
    });

    await blocklistedToken.save();

    res.status(200).send({ message: "Logout successful." });
  } catch (err) {
    if (err instanceof jwt.JsonWebTokenError) {
      return res.status(401).send({ message: "Invalid token." });
    }
    res.status(500).send({ message: err.message });
  }
};
