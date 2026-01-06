const mongoose = require("mongoose");

const TokenBlocklistSchema = new mongoose.Schema({
  token: {
    type: String,
    required: true,
    ref: "Token",
  },
  expiresAt: {
    type: Date,
    required: true,
  },
});

// This TTL index will automatically delete the documents from the collection
// once their expiration date has passed. This keeps the collection clean.
TokenBlocklistSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const TokenBlocklist = mongoose.model("TokenBlocklist", TokenBlocklistSchema);
module.exports = TokenBlocklist;
