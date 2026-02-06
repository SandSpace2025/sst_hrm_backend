const crypto = require("crypto");
const { promisify } = require("util");
const encryptionConfig = require("../config/encryption.config");
const logger = require("../core/logger");

class EncryptionService {
  constructor() {
    this.algorithm = encryptionConfig.algorithm;
    this.keyLength = encryptionConfig.keyLength;
    this.ivLength = encryptionConfig.ivLength;
    this.tagLength = encryptionConfig.tagLength;
    this.saltLength = encryptionConfig.saltLength;
    this.iterations = encryptionConfig.iterations;
    this.config = encryptionConfig;
  }

  // Generate random key
  generateKey() {
    return crypto.randomBytes(this.keyLength);
  }

  // Generate random IV
  generateIV() {
    return crypto.randomBytes(this.ivLength);
  }

  // Generate random salt
  generateSalt() {
    return crypto.randomBytes(this.saltLength);
  }

  // Derive key from password using PBKDF2
  deriveKeyFromPassword(password, salt, iterations = this.iterations) {
    return crypto.pbkdf2Sync(
      password,
      salt,
      iterations,
      this.keyLength,
      "sha256",
    );
  }

  // Encrypt message content
  async encryptMessage(content, key, aad = "message-auth") {
    try {
      const iv = this.generateIV();
      const cipher = crypto.createCipheriv(this.algorithm, key, iv);

      let encrypted = cipher.update(content, "utf8", "hex");
      encrypted += cipher.final("hex");

      return {
        encrypted,
        iv: iv.toString("hex"),
        tag: "aes-256-cbc", // Provide a meaningful tag
        algorithm: this.algorithm,
      };
    } catch (error) {
      logger.error("Error encrypting message", { error: error.message });
      throw new Error("Encryption failed");
    }
  }

  // Decrypt message content
  async decryptMessage(encryptedData, key, aad = "message-auth") {
    try {
      const { encrypted, iv, tag, algorithm } = encryptedData;

      const decipher = crypto.createDecipheriv(
        algorithm,
        key,
        Buffer.from(iv, "hex"),
      );

      let decrypted = decipher.update(encrypted, "hex", "utf8");
      decrypted += decipher.final("utf8");

      return decrypted;
    } catch (error) {
      logger.error("Error decrypting message", { error: error.message });
      throw new Error("Decryption failed");
    }
  }

  // Generate RSA key pair for user
  generateKeyPair() {
    const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", {
      modulusLength: 2048,
      publicKeyEncoding: { type: "spki", format: "pem" },
      privateKeyEncoding: { type: "pkcs8", format: "pem" },
    });

    return { publicKey, privateKey };
  }

  // Encrypt private key with user password
  encryptPrivateKey(privateKey, password, salt = null) {
    const keySalt = salt || this.generateSalt();
    const key = this.deriveKeyFromPassword(password, keySalt);
    const iv = this.generateIV();
    const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);

    let encrypted = cipher.update(privateKey, "utf8", "hex");
    encrypted += cipher.final("hex");

    return {
      encrypted,
      iv: iv.toString("hex"),
      salt: keySalt.toString("hex"),
      algorithm: "aes-256-cbc",
    };
  }

  // Decrypt private key with user password
  decryptPrivateKey(encryptedData, password) {
    const { encrypted, iv, salt, algorithm } = encryptedData;
    const key = this.deriveKeyFromPassword(password, Buffer.from(salt, "hex"));
    const decipher = crypto.createDecipheriv(
      algorithm,
      key,
      Buffer.from(iv, "hex"),
    );

    let decrypted = decipher.update(encrypted, "hex", "utf8");
    decrypted += decipher.final("utf8");

    return decrypted;
  }

  // Encrypt data with public key (for conversation keys)
  encryptWithPublicKey(data, publicKey) {
    try {
      const encrypted = crypto.publicEncrypt(
        {
          key: publicKey,
          padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
          oaepHash: "sha256",
        },
        Buffer.from(data),
      );
      return encrypted.toString("base64");
    } catch (error) {
      logger.error("Error encrypting with public key", {
        error: error.message,
      });
      throw new Error("Public key encryption failed");
    }
  }

  // Decrypt data with private key
  decryptWithPrivateKey(encryptedData, privateKey) {
    try {
      const decrypted = crypto.privateDecrypt(
        {
          key: privateKey,
          padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
          oaepHash: "sha256",
        },
        Buffer.from(encryptedData, "base64"),
      );
      return decrypted.toString();
    } catch (error) {
      logger.error("Error decrypting with private key", {
        error: error.message,
      });
      throw new Error("Private key decryption failed");
    }
  }

  // Generate conversation encryption key
  generateConversationKey() {
    return this.generateKey();
  }

  // Encrypt conversation key for each participant
  encryptConversationKey(conversationKey, participantPublicKeys) {
    const encryptedKeys = {};

    for (const [userId, publicKey] of Object.entries(participantPublicKeys)) {
      try {
        encryptedKeys[userId] = this.encryptWithPublicKey(
          conversationKey.toString("hex"),
          publicKey,
        );
      } catch (error) {
        logger.error(`Error encrypting key for user ${userId}`, {
          error: error.message,
        });
        throw new Error(`Failed to encrypt key for user ${userId}`);
      }
    }

    return encryptedKeys;
  }

  // Decrypt conversation key for participant
  decryptConversationKey(encryptedKey, privateKey) {
    try {
      const decrypted = this.decryptWithPrivateKey(encryptedKey, privateKey);
      return Buffer.from(decrypted, "hex");
    } catch (error) {
      logger.error("Error decrypting conversation key", {
        error: error.message,
      });
      throw new Error("Failed to decrypt conversation key");
    }
  }

  // Hash password for storage
  hashPassword(password, salt = null) {
    const passwordSalt = salt || this.generateSalt();
    const hash = crypto.pbkdf2Sync(
      password,
      passwordSalt,
      this.iterations,
      64,
      "sha256",
    );
    return {
      hash: hash.toString("hex"),
      salt: passwordSalt.toString("hex"),
      iterations: this.iterations,
    };
  }

  // Verify password
  verifyPassword(password, hash, salt, iterations) {
    const testHash = crypto.pbkdf2Sync(
      password,
      Buffer.from(salt, "hex"),
      iterations,
      64,
      "sha256",
    );
    return crypto.timingSafeEqual(Buffer.from(hash, "hex"), testHash);
  }

  // Generate secure random string
  generateSecureRandom(length = 32) {
    return crypto.randomBytes(length).toString("hex");
  }

  // Create HMAC for message integrity
  createHMAC(data, key) {
    const hmac = crypto.createHmac("sha256", key);
    hmac.update(data);
    return hmac.digest("hex");
  }

  // Verify HMAC
  verifyHMAC(data, key, hmac) {
    const expectedHmac = this.createHMAC(data, key);
    return crypto.timingSafeEqual(
      Buffer.from(hmac, "hex"),
      Buffer.from(expectedHmac, "hex"),
    );
  }

  // Encrypt file content
  async encryptFile(fileBuffer, key) {
    const iv = this.generateIV();
    const cipher = crypto.createCipher(this.algorithm, key);

    let encrypted = cipher.update(fileBuffer);
    encrypted = Buffer.concat([encrypted, cipher.final()]);

    const tag = cipher.getAuthTag();

    return {
      encrypted: encrypted.toString("base64"),
      iv: iv.toString("hex"),
      tag: tag.toString("hex"),
      algorithm: this.algorithm,
    };
  }

  // Decrypt file content
  async decryptFile(encryptedData, key) {
    const { encrypted, iv, tag, algorithm } = encryptedData;

    const decipher = crypto.createDecipher(algorithm, key);
    decipher.setAuthTag(Buffer.from(tag, "hex"));

    let decrypted = decipher.update(Buffer.from(encrypted, "base64"));
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted;
  }
}

module.exports = new EncryptionService();
