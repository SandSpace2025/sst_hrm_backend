const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const hrSchema = new Schema(
  {
    user: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      lowercase: true,
    },
    name: {
      type: String,
      trim: true,
      default: "",
    },
    profilePic: {
      type: String,
      default: "",
    },
    phone: {
      type: String,
      default: "",
    },
    bloodGroup: {
      type: String,
      default: "",
    },
    subOrganisation: {
      type: String,
      default: "SandSpace Technologies Pvt Ltd.",
    },
    employeeId: {
      type: String,
      unique: true,
      sparse: true,
    },
  },
  {
    timestamps: true,
  }
);

const HR = mongoose.model("HR", hrSchema);

module.exports = HR;
