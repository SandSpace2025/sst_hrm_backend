const mongoose = require("mongoose");
const crypto = require("crypto");

const userKeySchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    required: true, 
    unique: true,
    index: true 
  },
  userType: { 
    type: String, 
    enum: ['Admin', 'HR', 'Employee'], 
    required: true 
  },
  
  // User's master key (encrypted with password)
  masterKey: {
    encrypted: { type: String, required: true },
    salt: { type: String, required: true },
    iterations: { type: Number, default: 100000 },
    algorithm: { type: String, default: 'pbkdf2' }
  },
  
  // Public key for key exchange
  publicKey: { type: String, required: true },
  
  // Key derivation info
  keyDerivation: {
    algorithm: { type: String, default: 'pbkdf2' },
    salt: { type: String, required: true },
    iterations: { type: Number, default: 100000 },
    keyLength: { type: Number, default: 32 }
  },
  
  // Key rotation
  keyVersion: { type: Number, default: 1 },
  lastRotated: { type: Date, default: Date.now },
  
  // Key status
  isActive: { type: Boolean, default: true },
  isCompromised: { type: Boolean, default: false },
  compromisedAt: { type: Date },
  
  // Key metadata
  keyStrength: { 
    type: String, 
    enum: ['weak', 'medium', 'strong', 'very-strong'],
    default: 'strong'
  },
  
  // Backup keys (encrypted)
  backupKeys: [{
    encrypted: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
    isActive: { type: Boolean, default: true }
  }],
  
  // Key usage statistics
  usageStats: {
    totalEncryptions: { type: Number, default: 0 },
    totalDecryptions: { type: Number, default: 0 },
    lastUsed: { type: Date, default: Date.now }
  },
  
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}, {
  timestamps: true
});

// Indexes
userKeySchema.index({ userId: 1, userType: 1 });
userKeySchema.index({ isActive: 1, isCompromised: 1 });
userKeySchema.index({ keyVersion: 1 });

// Method to check if key is valid
userKeySchema.methods.isValid = function() {
  return this.isActive && !this.isCompromised;
};

// Method to mark as compromised
userKeySchema.methods.markCompromised = function() {
  this.isCompromised = true;
  this.compromisedAt = new Date();
  this.isActive = false;
  return this.save();
};

// Method to rotate key
userKeySchema.methods.rotateKey = function(newPublicKey, newMasterKey) {
  // Store current key as backup
  this.backupKeys.push({
    encrypted: this.masterKey.encrypted,
    createdAt: new Date(),
    isActive: false
  });
  
  // Update to new key
  this.publicKey = newPublicKey;
  this.masterKey = newMasterKey;
  this.keyVersion += 1;
  this.lastRotated = new Date();
  
  return this.save();
};

// Method to get backup key
userKeySchema.methods.getBackupKey = function(version = null) {
  if (version) {
    return this.backupKeys.find(bk => bk.keyVersion === version);
  }
  return this.backupKeys.find(bk => bk.isActive);
};

// Static method to find active key for user
userKeySchema.statics.findActiveKey = function(userId, userType) {
  return this.findOne({
    userId,
    userType,
    isActive: true,
    isCompromised: false
  });
};

// Pre-save middleware
userKeySchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model("UserKey", userKeySchema);
