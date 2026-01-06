const controller = require("../controllers/admin-management.controller");
const express = require("express");

const router = express.Router();

router.use((req, res, next) => {
  res.header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept");
  next();
});

router.post("/", controller.createAdmin);

module.exports = router;
