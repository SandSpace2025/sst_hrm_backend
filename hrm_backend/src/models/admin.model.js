const mongoose = require("mongoose");

const AdminSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    fullName: {
      type: String,
      trim: true,
    },
    mobileNumber: {
      type: String,
      trim: true,
    },
    designation: {
      type: String,
      enum: [
        "",
        "Associate Manager",
        "Manager",
        "Senior Manager",
        "Director",
        "CEO (Chief Executive Officer)",
        "COO (Chief Operating Officer)",
        "CFO (Chief Financial Officer)",
      ],
      default: "",
    },
    profileImage: {
      type: String,
      default: "",
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Admin", AdminSchema);
