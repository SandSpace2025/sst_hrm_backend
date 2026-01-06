const mongoose = require("mongoose");
const crypto = require("crypto");

const conversationSchema = new mongoose.Schema(
  {
    // Unique conversation ID
    conversationId: {
      type: String,
      required: true,
      unique: true,
      default: () => crypto.randomUUID(),
    },

    // Participants in the conversation
    participants: [
      {
        userId: {
          type: mongoose.Schema.Types.ObjectId,
          required: true,
          refPath: "participants.userType",
        },
        userType: {
          type: String,
          enum: ["Admin", "HR", "Employee"],
          required: true,
        },
        userRole: { type: String }, // For additional role context
        joinedAt: { type: Date, default: Date.now },
        isActive: { type: Boolean, default: true },
        lastSeenAt: { type: Date, default: Date.now },
      },
    ],

    // Conversation metadata
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 500,
    },
    conversationType: {
      type: String,
      enum: ["direct", "group", "support", "announcement"],
      default: "direct",
    },

    // Conversation settings
    settings: {
      allowNewParticipants: { type: Boolean, default: false },
      requireApproval: { type: Boolean, default: false },
      isArchived: { type: Boolean, default: false },
      isPinned: { type: Boolean, default: false },
      muteNotifications: { type: Boolean, default: false },
    },

    // Last activity
    lastMessageAt: { type: Date, default: Date.now },
    lastMessageId: { type: mongoose.Schema.Types.ObjectId, ref: "Message" },

    // Message count for performance
    messageCount: { type: Number, default: 0 },
    unreadCount: { type: Number, default: 0 },

    // Conversation status
    status: {
      type: String,
      enum: ["active", "archived", "deleted"],
      default: "active",
    },

    // Timestamps
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
  }
);

// Indexes for better query performance
conversationSchema.index({
  "participants.userId": 1,
  "participants.userType": 1,
});
// conversationSchema.index({ conversationId: 1 }); // Removed to prevent duplicate index warning (unique: true handles this)
conversationSchema.index({ lastMessageAt: -1 });
conversationSchema.index({ "settings.isArchived": 1 });
conversationSchema.index({ "settings.isPinned": 1 });
conversationSchema.index({ status: 1 });
conversationSchema.index({ conversationType: 1 });

// Virtual for active participants
conversationSchema.virtual("activeParticipants").get(function () {
  return this.participants.filter((p) => p.isActive);
});

// Method to check if user is participant
conversationSchema.methods.isParticipant = function (userId, userType) {
  return this.participants.some(
    (p) =>
      p.userId.toString() === userId.toString() &&
      p.userType.toLowerCase() === userType.toLowerCase()
  );
};

// Method to add participant
conversationSchema.methods.addParticipant = function (
  userId,
  userType,
  userRole = null
) {
  const existingParticipant = this.participants.find(
    (p) => p.userId.toString() === userId.toString() && p.userType === userType
  );

  if (existingParticipant) {
    existingParticipant.isActive = true;
    existingParticipant.joinedAt = new Date();
  } else {
    this.participants.push({
      userId,
      userType,
      userRole,
      joinedAt: new Date(),
      isActive: true,
    });
  }

  return this.save();
};

// Method to remove participant
conversationSchema.methods.removeParticipant = function (userId, userType) {
  const participant = this.participants.find(
    (p) =>
      p.userId.toString() === userId.toString() &&
      p.userType.toLowerCase() === userType.toLowerCase()
  );

  if (participant) {
    participant.isActive = false;
    return this.save();
  }

  return Promise.resolve(this);
};

// Method to update last seen
conversationSchema.methods.updateLastSeen = function (userId, userType) {
  const participant = this.participants.find(
    (p) =>
      p.userId.toString() === userId.toString() &&
      p.userType.toLowerCase() === userType.toLowerCase()
  );

  if (participant) {
    participant.lastSeenAt = new Date();
    return this.save();
  }

  return Promise.resolve(this);
};

// Static method to find conversation between two users
conversationSchema.statics.findDirectConversation = function (
  user1Id,
  user1Type,
  user2Id,
  user2Type
) {
  return this.findOne({
    conversationType: "direct",
    $and: [
      {
        participants: {
          $elemMatch: {
            userId: user1Id,
            userType: new RegExp(`^${user1Type}$`, "i"),
          },
        },
      },
      {
        participants: {
          $elemMatch: {
            userId: user2Id,
            userType: new RegExp(`^${user2Type}$`, "i"),
          },
        },
      },
    ],
    status: "active",
  });
};

// Pre-save middleware
conversationSchema.pre("save", function (next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model("Conversation", conversationSchema);
