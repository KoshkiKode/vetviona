#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');

const passwordPolicy = require('./lib/password_policy');
const rateLimit = require('./lib/rate_limit');
const sessionToken = require('./lib/session_token');
const totp = require('./lib/totp');
const auditLog = require('./lib/audit_log');
const appVersion = require('./lib/app_version');
const treeStorage = require('./lib/tree_storage');

const PORT = Number(process.env.PORT || 8080);
const DB_PATH = process.env.LICENSE_DB_PATH || path.join(__dirname, 'license-db.json');
// Operators must opt in to seeing the dev admin secret printed at startup.
const PRINT_DEV_SECRET =
  process.argv.includes('--print-dev-secret') ||
  process.env.PRINT_DEV_SECRET === 'true';

// ── AWS S3 Database Backend ───────────────────────────────────────────────────
// When AWS_S3_BUCKET is set the license database is stored in S3 instead of
// a local file.  The S3 object is always encrypted at rest (SSE-KMS when
// AWS_KMS_KEY_ID is set; otherwise SSE-S3/AES256).
const S3_BUCKET = process.env.AWS_S3_BUCKET || '';
const S3_KEY    = process.env.AWS_S3_KEY    || 'vetviona/license-db.json';
const S3_KMS_KEY_ID = process.env.AWS_KMS_KEY_ID || '';
const AWS_REGION    = process.env.AWS_REGION    || 'us-east-1';
const PBKDF2_ITERATIONS = 120000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_DIGEST = 'sha256';
// scrypt parameters (memory-hard; N=16384 uses 16 MB which fits the Node.js
// default maxmem of 32 MB; increase N in production if memory allows)
const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_KEYLEN = 64;

// ── Email configuration ─────────────────────────────────────────────────────
// Set SMTP_HOST (and optionally SMTP_PORT/SMTP_USER/SMTP_PASS/SMTP_SECURE)
// to send real emails.  When SMTP_HOST is absent the server runs in dev mode:
// tokens are printed to the console AND returned in API responses.
const EMAIL_FROM = process.env.EMAIL_FROM || 'Vetviona <noreply@vetviona.local>';
const EMAIL_DEV_MODE = !process.env.SMTP_HOST;

let _mailTransport = null;
function getMailTransport() {
  if (!process.env.SMTP_HOST) return null;
  if (_mailTransport) return _mailTransport;
  try {
    // nodemailer is an optional peer dep – install with: npm install nodemailer
    // eslint-disable-next-line import/no-extraneous-dependencies
    const nodemailer = require('nodemailer');
    _mailTransport = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS || '' }
        : undefined,
    });
    return _mailTransport;
  } catch (e) {
    console.warn(`[email] nodemailer unavailable (${e.message}). Run: npm install nodemailer`);
    return null;
  }
}

function sendEmail(to, subject, text) {
  const transport = getMailTransport();
  if (transport) {
    transport.sendMail({ from: EMAIL_FROM, to, subject, text }).catch((err) => {
      console.error(`[email] failed to send to ${to}: ${err.message}`);
      console.log(`[email FALLBACK]\nTo: ${to}\nSubject: ${subject}\n---\n${text}\n---`);
    });
  } else {
    // Dev mode: print to stdout so operators/developers can read tokens.
    console.log(`\n[email DEV]\nTo: ${to}\nSubject: ${subject}\n---\n${text}\n---\n`);
  }
}

// ── Constants ────────────────────────────────────────────────────────────────
const APPLE_OSES = new Set(['ios']);
const ANDROID_OSES = new Set(['android']);
const DESKTOP_OSES = new Set(['windows', 'macos', 'linux']);
const LICENSE_TYPES = new Set(['apple', 'android', 'desktop']);
const TOKEN_EXPIRY_HOURS = 48;
const GIFT_EXPIRY_HOURS = 72;
const PASSWORD_RESET_EXPIRY_HOURS = 1;
// We generate 32 random bytes (64 hex chars), but accept any configured secret
// that is at least this many characters.
const MIN_LICENSE_SECRET_LENGTH = 32;
const LICENSE_CODE_HEX_LENGTH = 24;
const LICENSE_CODE_PREFIX_LENGTH = 3;
const ABSOLUTE_MAX_DEVICES_PER_LICENSE = 10_000;
const MAX_DEVICES_PER_LICENSE = Math.min(
  Math.max(Number(process.env.MAX_DEVICES_PER_LICENSE) || 15, 1),
  ABSOLUTE_MAX_DEVICES_PER_LICENSE,
);

// ADMIN_SECRET protects the voucher-creation endpoint.
// In dev mode (no ADMIN_SECRET set) the server prints a one-time secret at
// startup so operators can still call the endpoint during development.
const _devAdminSecret = crypto.randomBytes(8).toString('hex');

// ── Utilities ────────────────────────────────────────────────────────────────
function nowIso() { return new Date().toISOString(); }
function addHours(hours) { return new Date(Date.now() + hours * 3_600_000).toISOString(); }
function generateToken() { return crypto.randomBytes(4).toString('hex').toUpperCase(); }
function normalizeLicenseCode(value) {
  return String(value || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
}

function timingSafeEqualStrings(a, b) {
  const left = Buffer.from(String(a));
  const right = Buffer.from(String(b));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function getLicenseSigningSecret(db) {
  if (process.env.LICENSE_KEY_SECRET) return String(process.env.LICENSE_KEY_SECRET);
  if (
    db.meta &&
    typeof db.meta.licenseKeySecret === 'string' &&
    db.meta.licenseKeySecret.length >= MIN_LICENSE_SECRET_LENGTH
  ) {
    return db.meta.licenseKeySecret;
  }
  return '';
}

function ensureLicenseSigningSecret(db) {
  if (process.env.LICENSE_KEY_SECRET) return false;
  db.meta = db.meta || {};
  if (
    typeof db.meta.licenseKeySecret === 'string' &&
    db.meta.licenseKeySecret.length >= MIN_LICENSE_SECRET_LENGTH
  ) {
    return false;
  }
  db.meta.licenseKeySecret = crypto.randomBytes(32).toString('hex');
  return true;
}

function computeReentryLicenseCode(db, account, licenseType) {
  const secret = getLicenseSigningSecret(db);
  if (!secret) return null;
  const digest = crypto
    .createHmac('sha256', secret)
    .update(`${account.id}:${account.email}:${licenseType}`)
    .digest('hex')
    .toUpperCase()
    .slice(0, LICENSE_CODE_HEX_LENGTH);
  const parts = [];
  for (let i = 0; i < digest.length; i += 4) {
    parts.push(digest.slice(i, i + 4));
  }
  const grouped = parts.join('-');
  const prefix = licenseType
    .toUpperCase()
    .padEnd(LICENSE_CODE_PREFIX_LENGTH, 'X')
    .slice(0, LICENSE_CODE_PREFIX_LENGTH);
  return `${prefix}-${grouped}`;
}

function isValidReentryLicenseCode(db, account, licenseType, providedCode) {
  const expected = computeReentryLicenseCode(db, account, licenseType);
  if (!expected) return false;
  const normalizedExpected = normalizeLicenseCode(expected);
  const normalizedProvided = normalizeLicenseCode(providedCode);
  return timingSafeEqualStrings(normalizedExpected, normalizedProvided);
}

// ── S3 Client ─────────────────────────────────────────────────────────────────
let _s3 = null;
function getS3() {
  if (!S3_BUCKET) return null;
  if (_s3) return _s3;
  try {
    // @aws-sdk/client-s3 is an optional peer dep; install with:
    //   npm install @aws-sdk/client-s3
    // Credentials are resolved automatically from:
    //   1. Env vars: AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY (+ AWS_SESSION_TOKEN)
    //   2. ~/.aws/credentials / config file
    //   3. EC2/ECS/Lambda instance IAM role (recommended in production)
    const { S3Client } = require('@aws-sdk/client-s3');
    _s3 = new S3Client({ region: AWS_REGION });
    return _s3;
  } catch (e) {
    console.warn(`[s3] @aws-sdk/client-s3 unavailable: ${e.message}`);
    console.warn('[s3] Run: npm install @aws-sdk/client-s3');
    return null;
  }
}

// ── Database ─────────────────────────────────────────────────────────────────
async function readDb() {
  const s3 = getS3();
  if (s3) {
    try {
      const { GetObjectCommand } = require('@aws-sdk/client-s3');
      const response = await s3.send(new GetObjectCommand({ Bucket: S3_BUCKET, Key: S3_KEY }));
      const chunks = [];
      for await (const chunk of response.Body) chunks.push(chunk);
      const parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if (!parsed || !Array.isArray(parsed.accounts)) {
        return { accounts: [], pendingGifts: [], meta: {} };
      }
      if (!Array.isArray(parsed.pendingGifts)) parsed.pendingGifts = [];
      if (!parsed.meta || typeof parsed.meta !== 'object') parsed.meta = {};
      return parsed;
    } catch (err) {
      if (err.name === 'NoSuchKey') return { accounts: [], pendingGifts: [], meta: {} };
      throw err;
    }
  }
  // ── Local file fallback (dev mode) ──────────────────────────────────────────
  if (!fs.existsSync(DB_PATH)) return { accounts: [], pendingGifts: [], meta: {} };
  try {
    const raw = fs.readFileSync(DB_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.accounts)) {
      return { accounts: [], pendingGifts: [], meta: {} };
    }
    if (!Array.isArray(parsed.pendingGifts)) parsed.pendingGifts = [];
    if (!parsed.meta || typeof parsed.meta !== 'object') parsed.meta = {};
    return parsed;
  } catch {
    return { accounts: [], pendingGifts: [], meta: {} };
  }
}

async function writeDb(db) {
  const s3 = getS3();
  const encoded = JSON.stringify(db, null, 2);
  if (s3) {
    const { PutObjectCommand } = require('@aws-sdk/client-s3');
    const params = {
      Bucket: S3_BUCKET,
      Key: S3_KEY,
      Body: encoded,
      ContentType: 'application/json',
      // Always encrypt at rest — SSE-KMS when a key ID is provided, else SSE-S3 (AES-256)
      ServerSideEncryption: S3_KMS_KEY_ID ? 'aws:kms' : 'AES256',
    };
    if (S3_KMS_KEY_ID) params.SSEKMSKeyId = S3_KMS_KEY_ID;
    await s3.send(new PutObjectCommand(params));
    return;
  }
  // ── Local file fallback (dev mode) ──────────────────────────────────────────
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  const fd = fs.openSync(DB_PATH, 'w', 0o600);
  try {
    fs.writeFileSync(fd, encoded, 'utf8');
  } finally {
    fs.closeSync(fd);
  }
}

// Remove expired gifts and stale verification tokens; returns true if DB changed.
function cleanupExpired(db) {
  const now = new Date();
  let changed = false;

  db.pendingGifts = db.pendingGifts.filter((g) => {
    if (new Date(g.expiresAt) > now) return true;
    // Release the escrow held on the sender's account.
    const sender = db.accounts.find((a) => a.email === g.fromEmail);
    if (sender && sender.giftedOut && sender.giftedOut[g.licenseType] === g.id) {
      sender.giftedOut[g.licenseType] = null;
      sender.updatedAt = nowIso();
    }
    changed = true;
    return false;
  });

  for (const account of db.accounts) {
    if (
      account.emailVerificationToken &&
      account.emailVerificationExpiry &&
      new Date(account.emailVerificationExpiry) <= now
    ) {
      account.emailVerificationToken = null;
      account.emailVerificationExpiry = null;
      changed = true;
    }
  }
  return changed;
}

// ── Crypto ───────────────────────────────────────────────────────────────────

/// Hash a password using scrypt (memory-hard, preferred over PBKDF2).
/// Returns a hex string with the format: "scrypt$<hex>".
/// Also accepts legacy PBKDF2 hashes (plain hex, no prefix) so that existing
/// accounts stored before the scrypt migration continue to work.
function hashPassword(password, salt) {
  return 'scrypt$' + crypto
    .scryptSync(password, salt, SCRYPT_KEYLEN, { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P })
    .toString('hex');
}

/// Verify a password against a stored hash, supporting both scrypt (new) and
/// PBKDF2-SHA256 (legacy) formats so that pre-migration accounts still work.
function verifyPassword(password, salt, storedHash) {
  if (storedHash.startsWith('scrypt$')) {
    const expected = Buffer.from(storedHash.slice('scrypt$'.length), 'hex');
    const actual = crypto.scryptSync(
      password, salt, SCRYPT_KEYLEN,
      { N: SCRYPT_N, r: SCRYPT_R, p: SCRYPT_P },
    );
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  }
  // Legacy PBKDF2-SHA256 path — no prefix, plain hex.
  const actual = crypto.pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, PBKDF2_KEYLEN, PBKDF2_DIGEST);
  const expected = Buffer.from(storedHash, 'hex');
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

function sanitizeEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase();
}

function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1024 * 1024) {
        reject(new Error('Request body too large.'));
        req.destroy();
      }
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error('Invalid JSON body.'));
      }
    });
    req.on('error', reject);
  });
}

function parseRawBody(req, maxBytes) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    const limit = Number(maxBytes) || 4 * 1024 * 1024;
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > limit) {
        reject(new Error(`Request body too large (max ${limit} bytes).`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function sendJson(res, status, body) {
  const encoded = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(encoded),
    'Cache-Control': 'no-store',
    // Phase 2 security headers — applied to every response so a misconfigured
    // CDN can't strip them.  HSTS only matters when served over TLS but is
    // safe to include in plain-HTTP dev too (browsers ignore it then).
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'X-Frame-Options': 'DENY',
  });
  res.end(encoded);
}

function sendBinary(res, status, buffer, contentType) {
  res.writeHead(status, {
    'Content-Type': contentType || 'application/octet-stream',
    'Content-Length': buffer.length,
    'Cache-Control': 'no-store',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'X-Frame-Options': 'DENY',
  });
  res.end(buffer);
}

// ── Account helpers ───────────────────────────────────────────────────────────
function getGiftedOut(account) {
  return account.giftedOut || { apple: null, android: null, desktop: null };
}

function getLicenseDetail(account, type) {
  if (!account.licenses[type]) return 'none';
  const go = getGiftedOut(account);
  return go[type] ? 'gifted_out' : 'active';
}

// Returns the safe public view of an account.
// Pass db to include outgoing gift details; pass null to omit them.
function publicAccount(account, db) {
  const giftedOut = getGiftedOut(account);
  const licenses = account.licenses || {};
  const entitlements = {
    apple: licenses.apple === true && !giftedOut.apple,
    android: licenses.android === true && !giftedOut.android,
    desktop: licenses.desktop === true && !giftedOut.desktop,
  };

  const outgoingGifts = db
    ? (db.pendingGifts || [])
        .filter((g) => g.fromEmail === account.email)
        .map((g) => ({
          id: g.id,
          licenseType: g.licenseType,
          toEmail: g.toEmail,
          expiresAt: g.expiresAt,
          createdAt: g.createdAt,
        }))
    : [];

  return {
    id: account.id,
    email: account.email,
    emailVerified: account.emailVerified === true,
    mfaEnabled: account.mfa && account.mfa.enabled === true,
    recoveryCodesRemaining:
      account.mfa && Array.isArray(account.mfa.recoveryHashes)
        ? account.mfa.recoveryHashes.length
        : 0,
    entitlements,
    licensesDetail: {
      apple: getLicenseDetail(account, 'apple'),
      android: getLicenseDetail(account, 'android'),
      desktop: getLicenseDetail(account, 'desktop'),
    },
    reentryLicenseCodes: {
      apple: entitlements.apple ? computeReentryLicenseCode(db, account, 'apple') : null,
      android: entitlements.android ? computeReentryLicenseCode(db, account, 'android') : null,
      desktop: entitlements.desktop ? computeReentryLicenseCode(db, account, 'desktop') : null,
    },
    outgoingGifts,
    devices: account.devices.map((d) => ({
      id: d.id,
      appType: d.appType,
      os: d.os,
      firstVerifiedAt: d.firstVerifiedAt,
      lastVerifiedAt: d.lastVerifiedAt,
      lastAppVersion: d.lastAppVersion || '',
    })),
  };
}

function requireAccountAndPassword(db, email, password) {
  const normalizedEmail = sanitizeEmail(email);
  if (!normalizedEmail || !password) {
    // 401 — caller provided no credentials at all (or only a partial set).
    return { error: 'Email and password are required.', status: 401 };
  }

  const lock = rateLimit.checkLockout(normalizedEmail);
  if (lock.locked) {
    return {
      error:
        `Account temporarily locked due to repeated failed sign-ins. ` +
        `Try again in ${lock.retryAfterSeconds} seconds.`,
      status: 429,
      retryAfterSeconds: lock.retryAfterSeconds,
    };
  }

  const account = db.accounts.find((a) => a.email === normalizedEmail);
  if (!account) {
    rateLimit.recordFailure(normalizedEmail);
    return { error: 'Invalid email or password.', status: 401 };
  }

  if (!verifyPassword(String(password), account.passwordSalt, account.passwordHash)) {
    const f = rateLimit.recordFailure(normalizedEmail);
    auditLog.append(db, {
      email: normalizedEmail,
      event: 'login',
      ok: false,
      detail: { reason: 'bad_password', failureCount: f.count },
    });
    return { error: 'Invalid email or password.', status: 401 };
  }
  rateLimit.recordSuccess(normalizedEmail);
  return { account };
}

/**
 * Look up the account associated with a `Bearer <token>` header.  Returns
 * `{ account, payload }` on success, `{ error, status }` on failure.
 *
 * When [requireMfa] is true and the account has MFA enabled, the token must
 * have been minted after a successful MFA challenge (`payload.mfa === true`).
 */
function requireBearer(db, req, { requireMfa = false } = {}) {
  const tokenStr = sessionToken.extractBearer(req);
  if (!tokenStr) return { error: 'Missing Bearer token.', status: 401 };
  // Decode payload first to find the account (signature is checked next).
  let probe;
  try {
    const [b64] = tokenStr.split('.', 1);
    const json = Buffer.from(
      b64.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - b64.length % 4) % 4),
      'base64',
    ).toString('utf8');
    probe = JSON.parse(json);
  } catch {
    return { error: 'Malformed session token.', status: 401 };
  }
  const account = db.accounts.find((a) => a.id === probe.sub);
  const secret = getLicenseSigningSecret(db);
  if (!secret) return { error: 'Server signing secret unavailable.', status: 500 };
  const result = sessionToken.verifySessionToken(tokenStr, secret, account);
  if (!result.ok) return { error: result.message, status: 401 };
  if (requireMfa && account.mfa && account.mfa.enabled === true && !result.payload.mfa) {
    return { error: 'Step-up MFA required.', status: 403, code: 'mfa_required' };
  }
  return { account, payload: result.payload };
}

/**
 * Authenticate a request using either:
 *   • Authorization: Bearer <session-token> (preferred), or
 *   • email + password in the body (legacy fallback for migration).
 *
 * On success returns `{ account, viaToken: bool }`.  On failure returns
 * `{ error, status }`.
 */
function requireAuth(db, req, payload, opts = {}) {
  if (sessionToken.extractBearer(req)) {
    const r = requireBearer(db, req, opts);
    if (r.error) return r;
    return { account: r.account, viaToken: true, tokenPayload: r.payload };
  }
  const r = requireAccountAndPassword(db, payload.email, payload.password);
  if (r.error) return { error: r.error, status: r.status || 401, retryAfterSeconds: r.retryAfterSeconds };
  // Password fallback also enforces MFA when enabled.
  if (opts.requireMfa && r.account.mfa && r.account.mfa.enabled === true) {
    const code = String(payload.mfaCode || '');
    if (!code) {
      return { error: 'MFA code required.', status: 403, code: 'mfa_required' };
    }
    if (!totp.verifyCode(r.account.mfa.secret, code)) {
      auditLog.append(db, {
        email: r.account.email,
        event: 'mfa.verify',
        ok: false,
      });
      return { error: 'Invalid MFA code.', status: 401 };
    }
  }
  return { account: r.account, viaToken: false };
}

// Apply any pending incoming gifts to this account (called after registration
// or when a recipient's account is located during a gift claim).
function applyPendingGifts(db, account) {
  const incoming = db.pendingGifts.filter((g) => g.toEmail === account.email);
  for (const gift of incoming) {
    const sender = db.accounts.find((a) => a.email === gift.fromEmail);
    if (sender && sender.giftedOut && sender.giftedOut[gift.licenseType] === gift.id) {
      sender.giftedOut[gift.licenseType] = null;
      sender.licenses[gift.licenseType] = false;
      sender.updatedAt = nowIso();
    }
    account.licenses[gift.licenseType] = true;
    account.updatedAt = nowIso();
  }
  db.pendingGifts = db.pendingGifts.filter((g) => g.toEmail !== account.email);
}

// ── Handlers ─────────────────────────────────────────────────────────────────
async function handleRegister(db, payload, res) {
  const email = sanitizeEmail(payload.email);
  const password = String(payload.password || '');
  const apple = payload.appleLicense === true;
  const android = payload.androidLicense === true;
  const desktop = payload.desktopLicense === true;

  if (!email.includes('@')) {
    return sendJson(res, 400, { ok: false, message: 'A valid email is required.' });
  }
  const policy = passwordPolicy.validatePassword(password, { email });
  if (!policy.ok) {
    return sendJson(res, 400, { ok: false, message: policy.message });
  }
  if (!apple && !android && !desktop) {
    return sendJson(res, 400, {
      ok: false,
      message: 'At least one paid entitlement (appleLicense, androidLicense, or desktopLicense) is required.',
    });
  }
  if (db.accounts.some((a) => a.email === email)) {
    return sendJson(res, 409, { ok: false, message: 'Account already exists.' });
  }

  const passwordSalt = crypto.randomBytes(16).toString('hex');
  const verificationToken = generateToken();
  const account = {
    id: crypto.randomUUID(),
    email,
    passwordSalt,
    passwordHash: hashPassword(password, passwordSalt),
    emailVerified: false,
    emailVerificationToken: verificationToken,
    emailVerificationExpiry: addHours(TOKEN_EXPIRY_HOURS),
    licenses: { apple, android, desktop },
    giftedOut: { apple: null, android: null, desktop: null },
    devices: [],
    // Phase 2: token versioning lets "sign out everywhere" invalidate all
    // outstanding session tokens at once by bumping this number.
    tokenVersion: 0,
    // Phase 2: TOTP MFA state.  `enabled` flips true only after successful
    // enrollment confirmation; `secret` is base32, `recoveryHashes` are
    // SHA-256 hex digests of single-use recovery codes.
    mfa: { enabled: false, secret: null, recoveryHashes: [] },
    // Phase 2: password reset state.
    passwordResetToken: null,
    passwordResetExpiry: null,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  db.accounts.push(account);
  // Auto-apply any pending gifts that were sent to this email before registration.
  applyPendingGifts(db, account);
  auditLog.append(db, { email, event: 'register', ok: true });
  await writeDb(db);

  sendEmail(
    email,
    'Verify your Vetviona account email',
    `Welcome to Vetviona!\n\nYour email verification code is: ${verificationToken}\n\nThis code expires in ${TOKEN_EXPIRY_HOURS} hours.\n\nEnter this code in the Vetviona app under Settings → License Account → Verify Email.`,
  );

  const response = { ok: true, account: publicAccount(account, db) };
  if (EMAIL_DEV_MODE) response._devToken = verificationToken;
  return sendJson(res, 201, response);
}

async function handleVerifyEmail(db, payload, res) {
  const email = sanitizeEmail(payload.email);
  const token = String(payload.token || '').trim().toUpperCase();

  if (!email || !token) {
    return sendJson(res, 400, { ok: false, message: 'Email and token are required.' });
  }
  const account = db.accounts.find((a) => a.email === email);
  if (!account) {
    return sendJson(res, 404, { ok: false, message: 'Account not found.' });
  }
  if (account.emailVerified) {
    return sendJson(res, 200, { ok: true, message: 'Email already verified.' });
  }
  if (!account.emailVerificationToken || account.emailVerificationToken !== token) {
    return sendJson(res, 400, { ok: false, message: 'Invalid or expired verification code.' });
  }
  if (new Date(account.emailVerificationExpiry) < new Date()) {
    return sendJson(res, 400, {
      ok: false,
      message: 'Verification code has expired. Please request a new one.',
    });
  }

  account.emailVerified = true;
  account.emailVerificationToken = null;
  account.emailVerificationExpiry = null;
  account.updatedAt = nowIso();
  await writeDb(db);

  return sendJson(res, 200, { ok: true, message: 'Email verified successfully.' });
}

async function handleResendVerification(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const account = auth.account;

  if (account.emailVerified) {
    return sendJson(res, 200, { ok: true, message: 'Email is already verified.' });
  }

  const token = generateToken();
  account.emailVerificationToken = token;
  account.emailVerificationExpiry = addHours(TOKEN_EXPIRY_HOURS);
  account.updatedAt = nowIso();
  await writeDb(db);

  sendEmail(
    account.email,
    'Your Vetviona email verification code',
    `Your email verification code is: ${token}\n\nThis code expires in ${TOKEN_EXPIRY_HOURS} hours.\n\nEnter this code in the Vetviona app under Settings → License Account → Verify Email.`,
  );

  const response = { ok: true, message: 'Verification email sent.' };
  if (EMAIL_DEV_MODE) response._devToken = token;
  return sendJson(res, 200, response);
}

async function handleChangePassword(db, payload, res, ctx) {
  // Step-up auth: when MFA is enabled the request must include either a
  // Bearer token minted with mfa=true, or a fresh `mfaCode`.
  const auth = requireAuth(db, ctx.req, {
    email: payload.email,
    password: payload.currentPassword,
    mfaCode: payload.mfaCode,
  }, { requireMfa: true });
  if (auth.error) {
    return sendJson(res, auth.status || 401, {
      ok: false, message: auth.error, code: auth.code,
    });
  }
  const account = auth.account;

  // When using a Bearer token, the user still has to confirm the current
  // password — otherwise a stolen token would let the attacker change the
  // password and lock the rightful owner out.
  if (auth.viaToken) {
    if (!payload.currentPassword ||
        !verifyPassword(String(payload.currentPassword), account.passwordSalt, account.passwordHash)) {
      auditLog.append(db, { email: account.email, event: 'password.change', ok: false,
        detail: { reason: 'bad_current_password' } });
      return sendJson(res, 401, { ok: false, message: 'Current password is incorrect.' });
    }
  }

  const newPassword = String(payload.newPassword || '');
  const policy = passwordPolicy.validatePassword(newPassword, { email: account.email });
  if (!policy.ok) {
    return sendJson(res, 400, { ok: false, message: policy.message });
  }
  if (payload.currentPassword === newPassword) {
    return sendJson(res, 400, {
      ok: false,
      message: 'New password must differ from the current password.',
    });
  }

  account.passwordSalt = crypto.randomBytes(16).toString('hex');
  account.passwordHash = hashPassword(newPassword, account.passwordSalt);
  // Bump tokenVersion so all existing session tokens are invalidated — the
  // user must sign in again with the new password on every device.
  account.tokenVersion = (account.tokenVersion || 0) + 1;
  account.updatedAt = nowIso();
  auditLog.append(db, { email: account.email, event: 'password.change', ok: true });
  await writeDb(db);

  return sendJson(res, 200, { ok: true, message: 'Password changed successfully.' });
}

// ── Phase 2: Password Reset ──────────────────────────────────────────────────
async function handlePasswordResetRequest(db, payload, res) {
  const email = sanitizeEmail(payload.email);
  if (!email.includes('@')) {
    return sendJson(res, 400, { ok: false, message: 'A valid email is required.' });
  }
  // Always respond with the same generic success to avoid leaking which
  // emails exist on the system.
  const account = db.accounts.find((a) => a.email === email);
  let devToken = null;
  if (account) {
    const token = generateToken() + generateToken(); // 16 hex chars
    account.passwordResetToken = token;
    account.passwordResetExpiry = addHours(PASSWORD_RESET_EXPIRY_HOURS);
    account.updatedAt = nowIso();
    auditLog.append(db, { email, event: 'password.reset.request', ok: true });
    await writeDb(db);
    sendEmail(
      email,
      'Reset your Vetviona password',
      `Someone requested a password reset for your Vetviona account.\n\n` +
      `Reset code: ${token}\n\n` +
      `This code expires in ${PASSWORD_RESET_EXPIRY_HOURS} hour. ` +
      `If you didn't request this, ignore this email — your password will stay unchanged.`,
    );
    devToken = token;
  } else {
    auditLog.append(db, { email, event: 'password.reset.request', ok: false,
      detail: { reason: 'no_account' } });
  }
  const response = { ok: true, message:
    'If that email is registered, a reset code has been sent.' };
  if (EMAIL_DEV_MODE && devToken) response._devToken = devToken;
  return sendJson(res, 200, response);
}

async function handlePasswordReset(db, payload, res) {
  const email = sanitizeEmail(payload.email);
  const token = String(payload.token || '').trim().toUpperCase();
  const newPassword = String(payload.newPassword || '');
  if (!email || !token) {
    return sendJson(res, 400, { ok: false, message: 'Email and reset code are required.' });
  }
  const policy = passwordPolicy.validatePassword(newPassword, { email });
  if (!policy.ok) {
    return sendJson(res, 400, { ok: false, message: policy.message });
  }
  const account = db.accounts.find((a) => a.email === email);
  if (!account || !account.passwordResetToken ||
      account.passwordResetToken !== token) {
    auditLog.append(db, { email, event: 'password.reset', ok: false,
      detail: { reason: 'bad_token' } });
    return sendJson(res, 400, { ok: false, message: 'Invalid or expired reset code.' });
  }
  if (new Date(account.passwordResetExpiry) < new Date()) {
    return sendJson(res, 400, { ok: false, message: 'Reset code has expired.' });
  }
  account.passwordSalt = crypto.randomBytes(16).toString('hex');
  account.passwordHash = hashPassword(newPassword, account.passwordSalt);
  account.passwordResetToken = null;
  account.passwordResetExpiry = null;
  // Reset token version + clear lockout history so the user can sign in
  // immediately on every device.
  account.tokenVersion = (account.tokenVersion || 0) + 1;
  rateLimit.recordSuccess(email);
  account.updatedAt = nowIso();
  auditLog.append(db, { email, event: 'password.reset', ok: true });
  await writeDb(db);
  return sendJson(res, 200, { ok: true, message: 'Password reset successfully.' });
}

// ── Phase 2: TOTP MFA enroll / verify / disable ─────────────────────────────
async function handleMfaEnrollStart(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const account = auth.account;
  if (account.mfa && account.mfa.enabled === true) {
    return sendJson(res, 409, { ok: false, message: 'MFA is already enabled.' });
  }
  const secret = totp.generateSecret();
  // Store as a pending secret — only flips to enabled after the user
  // confirms by entering a valid code.
  account.mfa = account.mfa || { enabled: false, recoveryHashes: [] };
  account.mfa.pendingSecret = secret;
  account.updatedAt = nowIso();
  await writeDb(db);
  return sendJson(res, 200, {
    ok: true,
    secret,
    otpauthUri: totp.otpauthUri({ secret, label: account.email }),
    digits: totp.DIGITS,
    period: totp.STEP_SECONDS,
  });
}

async function handleMfaEnrollConfirm(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const account = auth.account;
  if (!account.mfa || !account.mfa.pendingSecret) {
    return sendJson(res, 400, { ok: false, message: 'No pending MFA enrollment.' });
  }
  if (!totp.verifyCode(account.mfa.pendingSecret, payload.code)) {
    auditLog.append(db, { email: account.email, event: 'mfa.enroll', ok: false });
    return sendJson(res, 401, { ok: false, message: 'Invalid MFA code.' });
  }
  const recovery = totp.generateRecoveryCodes(10);
  account.mfa = {
    enabled: true,
    secret: account.mfa.pendingSecret,
    recoveryHashes: recovery.map(totp.hashRecoveryCode),
  };
  // Force a fresh sign-in so the user gets a token minted with mfa=true.
  account.tokenVersion = (account.tokenVersion || 0) + 1;
  account.updatedAt = nowIso();
  auditLog.append(db, { email: account.email, event: 'mfa.enroll', ok: true });
  await writeDb(db);
  return sendJson(res, 200, {
    ok: true,
    message: 'MFA enabled. Save these recovery codes — each can be used once.',
    recoveryCodes: recovery,
  });
}

async function handleMfaDisable(db, payload, res, ctx) {
  // Disabling MFA itself requires step-up auth.
  const auth = requireAuth(db, ctx.req, payload, { requireMfa: true });
  if (auth.error) return sendJson(res, auth.status || 401, {
    ok: false, message: auth.error, code: auth.code });
  const account = auth.account;
  account.mfa = { enabled: false, secret: null, recoveryHashes: [] };
  account.tokenVersion = (account.tokenVersion || 0) + 1;
  account.updatedAt = nowIso();
  auditLog.append(db, { email: account.email, event: 'mfa.disable', ok: true });
  await writeDb(db);
  return sendJson(res, 200, { ok: true, message: 'MFA disabled.' });
}

// ── Phase 2: Sign out everywhere ─────────────────────────────────────────────
async function handleSessionRevokeAll(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const account = auth.account;
  account.tokenVersion = (account.tokenVersion || 0) + 1;
  account.updatedAt = nowIso();
  auditLog.append(db, { email: account.email, event: 'session.revoke_all', ok: true });
  await writeDb(db);
  return sendJson(res, 200, {
    ok: true,
    message: 'All session tokens revoked. Sign in again on each device.',
  });
}

async function handleVerify(db, payload, res) {
  const email = sanitizeEmail(payload.email);
  const password = String(payload.password || '');
  const licenseCode = String(payload.licenseCode || '');
  const appType = String(payload.appType || '').toLowerCase();
  const os = String(payload.os || '').toLowerCase();
  const deviceId = String(payload.deviceId || '').trim();
  const clientAppVersion = String(payload.appVersion || '');
  const mfaCode = String(payload.mfaCode || '');

  if (!email) {
    return sendJson(res, 400, { ok: false, message: 'Email is required.' });
  }
  if (!LICENSE_TYPES.has(appType)) {
    return sendJson(res, 400, { ok: false, message: 'appType must be "apple", "android", or "desktop".' });
  }
  if (!password && !licenseCode) {
    return sendJson(res, 400, { ok: false, message: 'Provide password or licenseCode.' });
  }
  if (deviceId.length < 4 || deviceId.length > 128) {
    return sendJson(res, 400, { ok: false, message: 'deviceId must be 4-128 characters.' });
  }

  if (appType === 'apple' && !APPLE_OSES.has(os)) {
    return sendJson(res, 400, { ok: false, message: 'Apple verification requires os "ios".' });
  }
  if (appType === 'android' && !ANDROID_OSES.has(os)) {
    return sendJson(res, 400, { ok: false, message: 'Android verification requires os "android".' });
  }
  if (appType === 'desktop' && !DESKTOP_OSES.has(os)) {
    return sendJson(res, 400, {
      ok: false,
      message: 'Desktop verification requires windows, macos, or linux.',
    });
  }

  let account;
  let mfaPassed = false;
  if (password) {
    const auth = requireAccountAndPassword(db, email, password);
    if (auth.error) return sendJson(res, auth.status || 401, {
      ok: false, message: auth.error, retryAfterSeconds: auth.retryAfterSeconds });
    account = auth.account;
    if (account.mfa && account.mfa.enabled === true) {
      if (!mfaCode) {
        return sendJson(res, 403, {
          ok: false, code: 'mfa_required', message: 'MFA code required.',
        });
      }
      const codeOk = totp.verifyCode(account.mfa.secret, mfaCode);
      const recoveryHash = totp.hashRecoveryCode(mfaCode);
      const recoveryIdx = (account.mfa.recoveryHashes || []).indexOf(recoveryHash);
      if (!codeOk && recoveryIdx < 0) {
        auditLog.append(db, { email: account.email, event: 'mfa.verify', ok: false });
        return sendJson(res, 401, { ok: false, message: 'Invalid MFA code.' });
      }
      if (recoveryIdx >= 0) {
        // Single-use: burn the recovery code.
        account.mfa.recoveryHashes.splice(recoveryIdx, 1);
      }
      auditLog.append(db, { email: account.email, event: 'mfa.verify', ok: true });
      mfaPassed = true;
    }
  } else {
    account = db.accounts.find((a) => a.email === email);
    if (!account) return sendJson(res, 401, { ok: false, message: 'Account not found.' });
    if (!isValidReentryLicenseCode(db, account, appType, licenseCode)) {
      return sendJson(res, 401, { ok: false, message: 'Invalid license code.' });
    }
    // Re-entry license codes don't bypass MFA when it's enabled.
    if (account.mfa && account.mfa.enabled === true) {
      if (!mfaCode || !totp.verifyCode(account.mfa.secret, mfaCode)) {
        return sendJson(res, 403, { ok: false, code: 'mfa_required',
          message: 'MFA code required.' });
      }
      mfaPassed = true;
    }
  }

  const giftedOut = getGiftedOut(account);
  let entitled = false;
  if (appType === 'apple') entitled = account.licenses.apple === true && !giftedOut.apple;
  else if (appType === 'android') entitled = account.licenses.android === true && !giftedOut.android;
  else entitled = account.licenses.desktop === true && !giftedOut.desktop;

  if (!entitled) {
    return sendJson(res, 403, {
      ok: false,
      message: `No active ${appType} paid entitlement on this account.`,
    });
  }

  const now = nowIso();
  const existing = account.devices.find((d) => d.id === deviceId);
  const currentTypeCount = account.devices.filter((d) => d.appType === appType).length;
  const alreadyVerifiedForType = existing && existing.appType === appType;
  if (!alreadyVerifiedForType && currentTypeCount >= MAX_DEVICES_PER_LICENSE) {
    return sendJson(res, 403, {
      ok: false,
      message: `This ${appType} license has reached the limit of ${MAX_DEVICES_PER_LICENSE} devices/computers.`,
      deviceLimitPerLicense: MAX_DEVICES_PER_LICENSE,
      devicesUsedForLicense: currentTypeCount,
    });
  }
  if (existing) {
    existing.appType = appType;
    existing.os = os;
    existing.lastVerifiedAt = now;
    existing.lastAppVersion = clientAppVersion;
  } else {
    account.devices.push({
      id: deviceId,
      appType,
      os,
      firstVerifiedAt: now,
      lastVerifiedAt: now,
      lastAppVersion: clientAppVersion,
    });
  }
  account.updatedAt = now;
  auditLog.append(db, { email: account.email, event: 'login', ok: true,
    detail: { appType, os, deviceId, mfa: mfaPassed } });

  // Mint a session token so the client can stop replaying the password.
  const secret = getLicenseSigningSecret(db);
  let session = null;
  if (secret) {
    session = sessionToken.issueSessionToken(account, secret, { mfa: mfaPassed });
  }
  await writeDb(db);

  const pub = publicAccount(account, db);
  const devicesUsedForLicense = account.devices.filter((d) => d.appType === appType).length;
  return sendJson(res, 200, {
    ok: true,
    message: 'License verified.',
    entitlements: pub.entitlements,
    emailVerified: pub.emailVerified,
    mfaEnabled: pub.mfaEnabled,
    licensesDetail: pub.licensesDetail,
    reentryLicenseCodes: pub.reentryLicenseCodes,
    deviceLimitPerLicense: MAX_DEVICES_PER_LICENSE,
    devicesUsedForLicense,
    devices: pub.devices,
    session: session ? {
      token: session.token,
      issuedAt: session.issuedAt,
      expiresAt: session.expiresAt,
      mfa: session.mfa,
    } : null,
  });
}

async function handleSync(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, {
    ok: false, message: auth.error, retryAfterSeconds: auth.retryAfterSeconds });
  const account = auth.account;

  const incomingGifts = (db.pendingGifts || [])
    .filter((g) => g.toEmail === account.email)
    .map((g) => ({
      id: g.id,
      licenseType: g.licenseType,
      fromEmail: g.fromEmail,
      expiresAt: g.expiresAt,
      createdAt: g.createdAt,
    }));

  return sendJson(res, 200, {
    ok: true,
    account: publicAccount(account, db),
    incomingGifts,
    deviceLimitPerLicense: MAX_DEVICES_PER_LICENSE,
  });
}

async function handleGiftInitiate(db, payload, res, ctx) {
  // Step-up: gifting away a license requires fresh MFA when enabled.
  const auth = requireAuth(db, ctx.req, payload, { requireMfa: true });
  if (auth.error) return sendJson(res, auth.status || 401, {
    ok: false, message: auth.error, code: auth.code });
  const account = auth.account;

  if (!account.emailVerified) {
    return sendJson(res, 403, {
      ok: false,
      message: 'Please verify your email before transferring licenses.',
    });
  }

  const licenseType = String(payload.licenseType || '').toLowerCase();
  const toEmail = sanitizeEmail(payload.toEmail);

  if (!LICENSE_TYPES.has(licenseType)) {
    return sendJson(res, 400, {
      ok: false,
      message: 'licenseType must be "apple", "android", or "desktop".',
    });
  }
  if (!toEmail.includes('@')) {
    return sendJson(res, 400, { ok: false, message: 'A valid recipient email is required.' });
  }
  if (toEmail === account.email) {
    return sendJson(res, 400, { ok: false, message: 'Cannot transfer a license to yourself.' });
  }
  if (!account.licenses[licenseType]) {
    return sendJson(res, 400, {
      ok: false,
      message: `You do not own a ${licenseType} license.`,
    });
  }

  const giftedOut = getGiftedOut(account);
  if (giftedOut[licenseType]) {
    return sendJson(res, 409, {
      ok: false,
      message: `Your ${licenseType} license is already in an active transfer. Cancel it first.`,
    });
  }

  const token = generateToken();
  const gift = {
    id: crypto.randomUUID(),
    fromEmail: account.email,
    toEmail,
    licenseType,
    token,
    createdAt: nowIso(),
    expiresAt: addHours(GIFT_EXPIRY_HOURS),
  };

  // Put the license in escrow so the sender can't use it until the gift is
  // claimed or cancelled.
  account.giftedOut = account.giftedOut || { apple: null, android: null, desktop: null };
  account.giftedOut[licenseType] = gift.id;
  account.updatedAt = nowIso();
  db.pendingGifts.push(gift);
  await writeDb(db);

  sendEmail(
    toEmail,
    `You have received a Vetviona ${licenseType} license`,
    `${account.email} has transferred their Vetviona ${licenseType} license to you.\n\nTo claim it:\n1. Open the Vetviona app\n2. Go to Settings → License Account\n3. Tap "Claim a License Gift" and enter your claim token\n\nYour claim token: ${token}\n\nThis offer expires in ${GIFT_EXPIRY_HOURS} hours.\n\nIf you do not have a Vetviona account yet, create one with the email address this message was sent to (${toEmail}) and then claim the license.`,
  );

  const response = {
    ok: true,
    gift: { id: gift.id, licenseType, toEmail, expiresAt: gift.expiresAt },
    account: publicAccount(account, db),
  };
  if (EMAIL_DEV_MODE) response._devToken = token;
  return sendJson(res, 200, response);
}

async function handleGiftClaim(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const account = auth.account;

  let gift;
  if (payload.giftId) {
    // Directed gift by ID — must be addressed to this account.
    gift = db.pendingGifts.find(
      (g) => g.id === payload.giftId && (g.toEmail === account.email || g.toEmail === null),
    );
  } else if (payload.token) {
    const tok = String(payload.token).trim().toUpperCase();
    // First look for a directed gift for this email.
    gift = db.pendingGifts.find((g) => g.token === tok && g.toEmail === account.email);
    // Fall back to open vouchers (toEmail === null — redeemable by anyone).
    if (!gift) {
      gift = db.pendingGifts.find((g) => g.token === tok && g.toEmail === null);
    }
  }

  if (!gift) {
    return sendJson(res, 404, {
      ok: false,
      message: 'Gift or voucher not found, or the code does not match your account.',
    });
  }
  if (new Date(gift.expiresAt) < new Date()) {
    db.pendingGifts = db.pendingGifts.filter((g) => g.id !== gift.id);
    await writeDb(db);
    return sendJson(res, 410, { ok: false, message: 'This gift has expired.' });
  }

  const licenseType = gift.licenseType;

  // Release escrow on sender (only directed gifts lock the sender's license).
  if (gift.fromEmail) {
    const sender = db.accounts.find((a) => a.email === gift.fromEmail);
    if (sender && sender.giftedOut && sender.giftedOut[licenseType] === gift.id) {
      sender.giftedOut[licenseType] = null;
      sender.licenses[licenseType] = false;
      sender.updatedAt = nowIso();
    }
  }

  // Grant the license to the recipient.
  account.licenses[licenseType] = true;
  account.updatedAt = nowIso();
  db.pendingGifts = db.pendingGifts.filter((g) => g.id !== gift.id);
  auditLog.append(db, { email: account.email, event: 'gift.claim', ok: true,
    detail: { licenseType } });
  await writeDb(db);

  return sendJson(res, 200, {
    ok: true,
    message: `${licenseType} license claimed successfully.`,
    account: publicAccount(account, db),
  });
}

async function handleGiftCancel(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload, { requireMfa: true });
  if (auth.error) return sendJson(res, auth.status || 401, {
    ok: false, message: auth.error, code: auth.code });
  const account = auth.account;

  let gift;
  if (payload.giftId) {
    gift = db.pendingGifts.find((g) => g.id === payload.giftId && g.fromEmail === account.email);
  } else {
    const licenseType = String(payload.licenseType || '').toLowerCase();
    if (!LICENSE_TYPES.has(licenseType)) {
      return sendJson(res, 400, {
        ok: false,
        message: 'licenseType must be "apple", "android", or "desktop".',
      });
    }
    const go = getGiftedOut(account);
    if (!go[licenseType]) {
      return sendJson(res, 404, {
        ok: false,
        message: `No active transfer found for your ${licenseType} license.`,
      });
    }
    gift = db.pendingGifts.find((g) => g.id === go[licenseType] && g.fromEmail === account.email);
  }

  if (!gift) return sendJson(res, 404, { ok: false, message: 'Transfer not found.' });

  // Release escrow — license returns to sender.
  account.giftedOut = account.giftedOut || {};
  account.giftedOut[gift.licenseType] = null;
  account.updatedAt = nowIso();
  db.pendingGifts = db.pendingGifts.filter((g) => g.id !== gift.id);
  auditLog.append(db, { email: account.email, event: 'gift.cancel', ok: true,
    detail: { licenseType: gift.licenseType } });
  await writeDb(db);

  return sendJson(res, 200, {
    ok: true,
    message: `${gift.licenseType} license transfer cancelled.`,
    account: publicAccount(account, db),
  });
}

// ── Voucher (open gift) creation — admin-only ─────────────────────────────────
//
// Creates a pending gift with `toEmail: null` so that ANY authenticated
// account can redeem the claim token.  This enables the "buy a license for
// someone else" workflow: the operator/admin creates a voucher, hands the
// token to the purchaser, and the recipient redeems it with their account.
//
// Protect this endpoint by setting the ADMIN_SECRET env var.  In dev mode
// (no env var) a one-time secret is logged at startup.
async function handleVoucherCreate(db, payload, res) {
  const configuredSecret = process.env.ADMIN_SECRET || _devAdminSecret;
  if (!payload.adminSecret || payload.adminSecret !== configuredSecret) {
    return sendJson(res, 403, { ok: false, message: 'Invalid admin secret.' });
  }

  const licenseType = String(payload.licenseType || '').toLowerCase();
  if (!LICENSE_TYPES.has(licenseType)) {
    return sendJson(res, 400, {
      ok: false,
      message: 'licenseType must be "apple", "android", or "desktop".',
    });
  }

  const quantity = Math.min(Math.max(Number(payload.quantity) || 1, 1), 50);
  const fromEmail = payload.fromEmail ? sanitizeEmail(payload.fromEmail) : null;
  const notes = payload.notes ? String(payload.notes).slice(0, 200) : null;
  const expiry = addHours(GIFT_EXPIRY_HOURS);

  const vouchers = [];
  for (let i = 0; i < quantity; i++) {
    const token = generateToken();
    const voucher = {
      id: crypto.randomUUID(),
      fromEmail,
      toEmail: null,          // open — any authenticated account may claim
      licenseType,
      token,
      notes,
      createdAt: nowIso(),
      expiresAt: expiry,
    };
    db.pendingGifts.push(voucher);
    vouchers.push({ id: voucher.id, token, licenseType, expiresAt: expiry });
  }
  await writeDb(db);

  if (fromEmail) {
    sendEmail(
      fromEmail,
      `Your Vetviona ${licenseType} voucher${quantity > 1 ? 's' : ''}`,
      `Your Vetviona ${licenseType} license voucher${quantity > 1 ? 's have' : ' has'} been created.\n\n${vouchers.map((v, i) => `Voucher ${i + 1}: ${v.token}`).join('\n')}\n\nShare each token with the intended recipient. They can redeem it in the Vetviona app under Settings → License Account → Claim a License Gift.\n\nEach voucher expires in ${GIFT_EXPIRY_HOURS} hours.`,
    );
  }

  const response = { ok: true, vouchers };
  if (EMAIL_DEV_MODE) response._devTokens = vouchers.map((v) => v.token);
  return sendJson(res, 200, response);
}

// ── Tree chunk S3 helpers ────────────────────────────────────────────────────
async function s3PutChunk(accountId, treeId, chunkId, body) {
  const s3 = getS3();
  const key = treeStorage.chunkS3Key(accountId, treeId, chunkId);
  if (!s3) {
    treeStorage.memPut(accountId, treeId, chunkId, body);
    return key;
  }
  const { PutObjectCommand } = require('@aws-sdk/client-s3');
  const params = {
    Bucket: S3_BUCKET, Key: key, Body: body,
    ContentType: 'application/octet-stream',
    ServerSideEncryption: S3_KMS_KEY_ID ? 'aws:kms' : 'AES256',
  };
  if (S3_KMS_KEY_ID) params.SSEKMSKeyId = S3_KMS_KEY_ID;
  await s3.send(new PutObjectCommand(params));
  return key;
}

async function s3GetChunk(accountId, treeId, chunkId) {
  const s3 = getS3();
  if (!s3) {
    return treeStorage.memGet(accountId, treeId, chunkId);
  }
  try {
    const { GetObjectCommand } = require('@aws-sdk/client-s3');
    const key = treeStorage.chunkS3Key(accountId, treeId, chunkId);
    const response = await s3.send(new GetObjectCommand({ Bucket: S3_BUCKET, Key: key }));
    const chunks = [];
    for await (const chunk of response.Body) chunks.push(chunk);
    return Buffer.concat(chunks);
  } catch (err) {
    if (err.name === 'NoSuchKey') return null;
    throw err;
  }
}

async function s3DeleteChunk(accountId, treeId, chunkId) {
  const s3 = getS3();
  if (!s3) {
    treeStorage.memDelete(accountId, treeId, chunkId);
    return;
  }
  const { DeleteObjectCommand } = require('@aws-sdk/client-s3');
  const key = treeStorage.chunkS3Key(accountId, treeId, chunkId);
  await s3.send(new DeleteObjectCommand({ Bucket: S3_BUCKET, Key: key }));
}

async function s3DeleteTreeChunks(accountId, treeId, chunkIds) {
  for (const id of chunkIds) {
    try { await s3DeleteChunk(accountId, treeId, id); } catch (_) {}
  }
}

// ── Tree-storage HTTP handlers ───────────────────────────────────────────────
async function handleTreeList(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  return sendJson(res, 200, { ok: true, ...treeStorage.listTrees(db, auth.account.id) });
}

async function handleTreeManifestGet(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const treeId = String(payload.treeId || '');
  const r = treeStorage.getManifest(db, auth.account.id, treeId);
  if (!r.ok) return sendJson(res, r.status, { ok: false, message: r.message });
  return sendJson(res, 200, { ok: true, manifest: r.manifest });
}

async function handleTreeManifestPut(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const treeId = String(payload.treeId || '');
  const r = treeStorage.putManifest(db, auth.account.id, treeId, payload.manifest);
  if (!r.ok) return sendJson(res, r.status, {
    ok: false, message: r.message, manifest: r.manifest });
  auditLog.append(db, { email: auth.account.email, event: 'tree.upload', ok: true,
    detail: { treeId, revision: r.manifest.revision, bytes: r.manifest.bytes } });
  await writeDb(db);
  return sendJson(res, 200, { ok: true, manifest: r.manifest });
}

async function handleTreeDelete(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const treeId = String(payload.treeId || '');
  const before = treeStorage.getManifest(db, auth.account.id, treeId);
  const r = treeStorage.deleteTree(db, auth.account.id, treeId);
  if (!r.ok) return sendJson(res, r.status || 400, { ok: false, message: r.message });
  if (before.ok) {
    await s3DeleteTreeChunks(
      auth.account.id, treeId,
      (before.manifest.chunks || []).map((c) => c.id),
    );
  }
  auditLog.append(db, { email: auth.account.email, event: 'tree.delete', ok: true,
    detail: { treeId } });
  await writeDb(db);
  return sendJson(res, 200, { ok: true, deleted: r.deleted });
}

async function handleTreeDeleteAll(db, payload, res, ctx) {
  const auth = requireAuth(db, ctx.req, payload);
  if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
  const trees = treeStorage.listTrees(db, auth.account.id).trees;
  for (const t of trees) {
    const got = treeStorage.getManifest(db, auth.account.id, t.id);
    if (got.ok) {
      await s3DeleteTreeChunks(auth.account.id, t.id, (got.manifest.chunks || []).map((c) => c.id));
    }
  }
  const r = treeStorage.deleteAllForAccount(db, auth.account.id);
  auditLog.append(db, { email: auth.account.email, event: 'tree.delete', ok: true,
    detail: { all: true, deleted: r.deletedTrees } });
  await writeDb(db);
  return sendJson(res, 200, { ok: true, deletedTrees: r.deletedTrees });
}

// Endpoints used to set rate-limit policy per route.  Auth-sensitive paths
// get charged tokens against both the per-IP and per-account buckets;
// version checks and health probes are unmetered.
const RATE_LIMITED_ROUTES = new Set([
  '/v1/account/register',
  '/v1/account/resend-verification',
  '/v1/account/change-password',
  '/v1/account/password-reset/request',
  '/v1/account/password-reset',
  '/v1/account/mfa/enroll/start',
  '/v1/account/mfa/enroll/confirm',
  '/v1/account/mfa/disable',
  '/v1/account/session/revoke-all',
  '/v1/license/verify',
  '/v1/license/gift/initiate',
  '/v1/license/gift/claim',
  '/v1/license/gift/cancel',
]);

// ── HTTP Server ───────────────────────────────────────────────────────────────
const stripeCheckout = require('./lib/stripe_checkout');

const server = http.createServer(async (req, res) => {
  if (!req.url) {
    return sendJson(res, 404, { ok: false, message: 'Not found.' });
  }
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const ip = rateLimit.clientIp(req);

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJson(res, 200, {
      ok: true,
      status: 'healthy',
      emailMode: EMAIL_DEV_MODE ? 'dev-console' : 'smtp',
    });
  }

  // ── Stripe webhook — must read raw body before JSON parsing ───────────────
  if (req.method === 'POST' && url.pathname === '/stripe-webhook') {
    let rawBody;
    try {
      rawBody = await parseRawBody(req, 64 * 1024);
    } catch (e) {
      return sendJson(res, 400, { ok: false, message: e.message });
    }
    const db = await readDb();
    const result = await stripeCheckout.handleWebhook(req, rawBody, db, writeDb);
    return sendJson(res, result.status, result.body);
  }

  // ── Download endpoint — GET with query params ─────────────────────────────
  if (req.method === 'GET' && url.pathname.startsWith('/download/')) {
    const platform = url.pathname.replace('/download/', '');
    const email = url.searchParams.get('email') || '';
    const db = await readDb();
    const result = await stripeCheckout.handleDownload(platform, db, email);
    if (result.status === 200 && result.body.url) {
      // Redirect to the pre-signed S3 URL.
      res.writeHead(302, { Location: result.body.url });
      return res.end();
    }
    return sendJson(res, result.status, result.body);
  }

  // ── /v1/app/version — public, unauthenticated, idempotent ────────────────
  if (req.method === 'GET' && url.pathname === '/v1/app/version') {
    return sendJson(res, 200, appVersion.build());
  }

  // ── Tree chunk PUT/GET/DELETE — Bearer-only, raw bodies ──────────────────
  // Format: /v1/tree/<treeId>/chunk/<chunkId>
  const chunkMatch = /^\/v1\/tree\/([A-Za-z0-9_-]{1,64})\/chunk\/([A-Za-z0-9_-]{1,64})$/.exec(url.pathname);
  if (chunkMatch && (req.method === 'PUT' || req.method === 'GET' || req.method === 'DELETE')) {
    const db = await readDb();
    const dbChanged = ensureLicenseSigningSecret(db);
    if (dbChanged) await writeDb(db);

    const auth = requireBearer(db, req);
    if (auth.error) return sendJson(res, auth.status || 401, { ok: false, message: auth.error });
    const accountId = auth.account.id;
    const [, treeId, chunkId] = chunkMatch;

    // Per-IP rate limit on chunk traffic.
    const rl = rateLimit.consume({ ip, email: auth.account.email });
    if (!rl.ok) return sendJson(res, 429, {
      ok: false, message: 'Rate limit exceeded.', retryAfterSeconds: rl.retryAfterSeconds });

    if (req.method === 'PUT') {
      const got = treeStorage.getManifest(db, accountId, treeId);
      if (!got.ok) return sendJson(res, 404, {
        ok: false, message: 'Upload manifest before chunks.' });
      const declared = (got.manifest.chunks || []).find((c) => c.id === chunkId);
      if (!declared) return sendJson(res, 400, {
        ok: false, message: 'Chunk id is not declared in the current manifest.' });
      let body;
      try {
        body = await parseRawBody(req, treeStorage.MAX_CHUNK_BYTES + 1024);
      } catch (e) {
        return sendJson(res, 413, { ok: false, message: e.message });
      }
      if (body.length > treeStorage.MAX_CHUNK_BYTES) {
        return sendJson(res, 413, {
          ok: false, message: `Chunk too large (max ${treeStorage.MAX_CHUNK_BYTES} bytes).` });
      }
      if (declared.sha256) {
        const actual = treeStorage.sha256Hex(body);
        if (actual !== declared.sha256) {
          return sendJson(res, 400, { ok: false, message: 'Chunk hash mismatch.' });
        }
      }
      try {
        await s3PutChunk(accountId, treeId, chunkId, body);
      } catch (err) {
        return sendJson(res, 500, { ok: false, message: `Storage error: ${err.message}` });
      }
      return sendJson(res, 200, { ok: true, bytes: body.length });
    }

    if (req.method === 'GET') {
      let buf;
      try { buf = await s3GetChunk(accountId, treeId, chunkId); }
      catch (err) { return sendJson(res, 500, { ok: false, message: `Storage error: ${err.message}` }); }
      if (!buf) return sendJson(res, 404, { ok: false, message: 'Chunk not found.' });
      return sendBinary(res, 200, buf, 'application/octet-stream');
    }

    if (req.method === 'DELETE') {
      try { await s3DeleteChunk(accountId, treeId, chunkId); }
      catch (err) { return sendJson(res, 500, { ok: false, message: `Storage error: ${err.message}` }); }
      return sendJson(res, 200, { ok: true });
    }
  }

  if (req.method !== 'POST') {
    return sendJson(res, 405, { ok: false, message: 'Method not allowed.' });
  }

  let payload;
  try {
    payload = await parseJsonBody(req);
  } catch (err) {
    return sendJson(res, 400, { ok: false, message: err.message || 'Bad request.' });
  }

  // Per-IP and per-account rate limit on auth-sensitive POST routes.
  if (RATE_LIMITED_ROUTES.has(url.pathname)) {
    const rl = rateLimit.consume({ ip, email: payload && payload.email });
    if (!rl.ok) {
      // Best-effort audit log without touching the DB on the rate-limit path.
      return sendJson(res, 429, {
        ok: false,
        message: 'Too many requests. Please slow down and try again shortly.',
        retryAfterSeconds: rl.retryAfterSeconds,
        scope: rl.scope,
      });
    }
  }

  const db = await readDb();
  const dbChanged = cleanupExpired(db) || ensureLicenseSigningSecret(db);
  if (dbChanged) await writeDb(db);

  const ctx = { req, ip };

  const routes = {
    '/v1/account/register': handleRegister,
    '/v1/account/verify-email': handleVerifyEmail,
    '/v1/account/resend-verification': handleResendVerification,
    '/v1/account/change-password': handleChangePassword,
    '/v1/account/password-reset/request': handlePasswordResetRequest,
    '/v1/account/password-reset': handlePasswordReset,
    '/v1/account/mfa/enroll/start': handleMfaEnrollStart,
    '/v1/account/mfa/enroll/confirm': handleMfaEnrollConfirm,
    '/v1/account/mfa/disable': handleMfaDisable,
    '/v1/account/session/revoke-all': handleSessionRevokeAll,
    '/v1/account/sync': handleSync,
    '/v1/license/verify': handleVerify,
    '/v1/license/gift/initiate': handleGiftInitiate,
    '/v1/license/gift/claim': handleGiftClaim,
    '/v1/license/gift/cancel': handleGiftCancel,
    '/v1/license/voucher/create': handleVoucherCreate,
    '/v1/tree/list': handleTreeList,
    '/v1/tree/manifest/get': handleTreeManifestGet,
    '/v1/tree/manifest/put': handleTreeManifestPut,
    '/v1/tree/delete': handleTreeDelete,
    '/v1/tree/delete-all': handleTreeDeleteAll,
  };

  const handler = routes[url.pathname];
  if (handler) return await handler(db, payload, res, ctx);
  return sendJson(res, 404, { ok: false, message: 'Not found.' });
});

// Only start listening when invoked directly (e.g. `node license_server.js`).
// When unit tests `require()` this file they get the lib re-exports without
// starting a real server.
if (require.main === module) {
  server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Vetviona license backend running on http://127.0.0.1:${PORT}`);
  // eslint-disable-next-line no-console
  if (S3_BUCKET) {
    // eslint-disable-next-line no-console
    console.log(`License database: s3://${S3_BUCKET}/${S3_KEY} (${AWS_REGION}) encryption=${S3_KMS_KEY_ID ? 'SSE-KMS' : 'SSE-S3/AES256'}`);
  } else {
    // eslint-disable-next-line no-console
    console.log(`License database: ${DB_PATH} (local file — set AWS_S3_BUCKET for production)`);
  }
  // eslint-disable-next-line no-console
  console.log(
    EMAIL_DEV_MODE
      ? 'Email: DEV MODE — tokens logged to console. Set SMTP_HOST to use real email.'
      : `Email: SMTP via ${process.env.SMTP_HOST}:${process.env.SMTP_PORT || 587}`,
  );
  if (!process.env.ADMIN_SECRET) {
    if (PRINT_DEV_SECRET) {
      // eslint-disable-next-line no-console
      console.log(`\n[DEV] Admin secret (voucher creation): ${_devAdminSecret}`);
      // eslint-disable-next-line no-console
      console.log('[DEV] Set ADMIN_SECRET env var to use a permanent admin secret.\n');
    } else {
      // eslint-disable-next-line no-console
      console.log(
        '\n[DEV] ADMIN_SECRET unset. Re-run with --print-dev-secret ' +
        'to print a one-time admin secret, or set ADMIN_SECRET in production.\n',
      );
    }
  }
  if (S3_BUCKET && !process.env.LICENSE_KEY_SECRET) {
    // eslint-disable-next-line no-console
    console.warn('\n[WARN] LICENSE_KEY_SECRET is not set. Re-entry license codes will change on restart when using S3 storage. Set LICENSE_KEY_SECRET to a stable ≥ 32-char secret.\n');
  }
});
}

// Exported for unit tests — only when not actually starting the server.
module.exports = {
  server,
  // Re-exports of lib modules so tests can reset state easily.
  _internal: {
    rateLimit, sessionToken, totp, passwordPolicy, treeStorage, auditLog,
    appVersion,
  },
};
