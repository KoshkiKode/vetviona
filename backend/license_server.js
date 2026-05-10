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

// ── S3-Compatible Database Backend ───────────────────────────────────────────
// When S3_BUCKET is set the license database is stored in any S3-compatible
// object store (MinIO, Backblaze B2, Cloudflare R2, etc.) instead of a local
// file.  Set S3_ENDPOINT to point at your provider; leave it unset to use
// AWS S3 (legacy).  Objects are always encrypted at rest (AES-256 SSE-S3).
const S3_BUCKET   = process.env.S3_BUCKET   || '';
const S3_KEY      = process.env.S3_KEY      || 'vetviona/license-db.json';
const S3_REGION   = process.env.S3_REGION   || 'us-east-1';
const S3_ENDPOINT = process.env.S3_ENDPOINT || ''; // e.g. https://s3.us-west-000.backblazeb2.com
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
    // It works with any S3-compatible provider when S3_ENDPOINT is set.
    // Credentials are resolved from env vars automatically:
    //   AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
    // (these are standard env var names used by all S3-compatible SDKs)
    const { S3Client } = require('@aws-sdk/client-s3');
    const clientConfig = { region: S3_REGION };
    if (S3_ENDPOINT) {
      clientConfig.endpoint = S3_ENDPOINT;
      clientConfig.forcePathStyle = true; // required for MinIO and most self-hosted providers
    }
    _s3 = new S3Client(clientConfig);
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
      // Standard AES-256 server-side encryption — supported by all S3-compatible providers
      ServerSideEncryption: 'AES256',
    };
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

function requireBearer(db, req, { requireMfa = false } = {}) {
  const tokenStr = sessionToken.extractBearer(req);
  if (!tokenStr) return { error: 'Missing Bearer token.', status: 401 };
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

function requireAuth(db, req, payload, opts = {}) {
  if (sessionToken.extractBearer(req)) {
    const r = requireBearer(db, req, opts);
    if (r.error) return r;
    return { account: r.account, viaToken: true, tokenPayload: r.payload };
  }
  const r = requireAccountAndPassword(db, payload.email, payload.password);
  if (r.error) return { error: r.error, status: r.status || 401, retryAfterSeconds: r.retryAfterSeconds };
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

// Apply any pending incoming gifts to this account.
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
    tokenVersion: 0,
    mfa: { enabled: false, secret: null, recoveryHashes: [] },
    passwordResetToken: null,
    passwordResetExpiry: null,
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  db.accounts.push(account);
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
