const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const blackoutDateSchema = new Schema(
  {
    startDate: {
      type: Date,
      required: true,
      index: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    reason: {
      type: String,
      required: true,
      trim: true,
    },
    createdBy: {
      type: Schema.Types.ObjectId,
      required: true,
      refPath: "createdByModel",
    },
    createdByModel: {
      type: String,
      required: true,
      enum: ["Admin", "HR"],
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

const BlackoutDate = mongoose.model("BlackoutDate", blackoutDateSchema);

module.exports = BlackoutDate;
