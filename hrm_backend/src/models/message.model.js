const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    // Reference to conversation
    conversationId: {
      type: String,
      required: true,
      index: true,
      ref: "Conversation",
    },

    // Sender information
    sender: {
      userId: { type: mongoose.Schema.Types.ObjectId, required: true },
      userType: {
        type: String,
        enum: ["Admin", "HR", "Employee"],
        required: true,
      },
      name: { type: String, required: true },
      email: { type: String, required: true },
    },
    // Receiver information (Critical for unread counts)
    receiver: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    receiverModel: {
      type: String,
      enum: ["Admin", "HR", "Employee"],
      required: true,
    },
    // Message content (plain text)
    content: {
      type: String,
      required: true,
      trim: true,
    },
    // Message metadata
    messageType: {
      type: String,
      enum: ["text", "file", "image", "system", "announcement"],
      default: "text",
    },

    priority: {
      type: String,
      enum: ["low", "normal", "high", "urgent"],
      default: "normal",
    },
    // Message status
    status: {
      type: String,
      enum: ["sent", "delivered", "read"],
      default: "sent",
    },

    // Simple isRead flag for quick queries (in addition to readBy array)
    isRead: {
      type: Boolean,
      default: false,
      index: true, // Index for efficient unread message queries
    },

    // Read receipts
    readBy: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, required: true },
        userType: { type: String, required: true },
        readAt: { type: Date, default: Date.now },
      },
    ],
    isArchived: {
      type: Boolean,
      default: false,
    },
    archivedAt: {
      type: Date,
      default: null,
    },
    // Reply/thread information
    replyTo: { type: mongoose.Schema.Types.ObjectId, ref: "Message" },
    isReply: { type: Boolean, default: false },
    // File attachments
    attachments: [
      {
        filename: { type: String, required: true },
        originalName: { type: String, required: true },
        filePath: { type: String, required: true },
        fileSize: { type: Number, required: true },
        mimeType: { type: String, required: true },
        uploadedAt: { type: Date, default: Date.now },
      },
    ],
    // For scheduled messages
    scheduledFor: {
      type: Date,
      default: null,
    },
    isScheduled: {
      type: Boolean,
      default: false,
    },
    // For message templates
    templateId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MessageTemplate",
      default: null,
    },
    // For tracking
    deliveryAttempts: {
      type: Number,
      default: 0,
    },
    lastDeliveryAttempt: {
      type: Date,
      default: null,
    },
    // For employee message approval
    requiresApproval: {
      type: Boolean,
      default: false,
    },
    isApproved: {
      type: Boolean,
      default: true, // Admin and HR messages are auto-approved
    },
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Admin",
      default: null,
    },
    approvedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for better query performance
messageSchema.index({ conversationId: 1, createdAt: -1 });
messageSchema.index({ "sender.userId": 1, createdAt: -1 });
messageSchema.index({ "readBy.userId": 1 });
messageSchema.index({ messageType: 1, createdAt: -1 });
messageSchema.index({ status: 1, createdAt: -1 });
messageSchema.index({ isArchived: 1, conversationId: 1 });

// Virtual for message thread (replies)
messageSchema.virtual("replies", {
  ref: "Message",
  localField: "_id",
  foreignField: "parentMessage",
});

// Method to mark as read by specific user
messageSchema.methods.markAsRead = function (userId, userType) {
  const existingRead = this.readBy.find(
    (r) => r.userId.toString() === userId.toString() && r.userType === userType
  );

  if (!existingRead) {
    this.readBy.push({
      userId,
      userType,
      readAt: new Date(),
    });
  }

  this.status = "read";
  return this.save();
};

// Method to archive message
messageSchema.methods.archive = function () {
  this.isArchived = true;
  this.archivedAt = new Date();
  return this.save();
};

// Method to check if message is read by user
messageSchema.methods.isReadBy = function (userId, userType) {
  return this.readBy.some(
    (r) => r.userId.toString() === userId.toString() && r.userType === userType
  );
};

// Method to get read count
messageSchema.methods.getReadCount = function () {
  return this.readBy.length;
};

// Static method to get messages in conversation
messageSchema.statics.getConversationMessages = function (
  conversationId,
  page = 1,
  limit = 50
) {
  const skip = (page - 1) * limit;

  return this.find({
    conversationId,
    isArchived: false,
  })
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(parseInt(limit));
};

// Pre-save middleware
messageSchema.pre("save", function (next) {
  // Set default values
  if (!this.messageType) {
    this.messageType = "text";
  }

  if (!this.priority) {
    this.priority = "normal";
  }

  if (!this.status) {
    this.status = "sent";
  }

  next();
});

// Add error handling for validation errors
messageSchema.post("save", function (error, doc, next) {
  if (error) {
    console.error("Message validation error:", error);
    if (error.name === "ValidationError") {
      console.error("Validation errors:", error.errors);
    }
  }
  next();
});

module.exports = mongoose.model("Message", messageSchema);
