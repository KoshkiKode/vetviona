#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 8080);
const DB_PATH = process.env.LICENSE_DB_PATH || path.join(__dirname, 'license-db.json');
const PBKDF2_ITERATIONS = 120000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_DIGEST = 'sha256';

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

// ADMIN_SECRET protects the voucher-creation endpoint.
// In dev mode (no ADMIN_SECRET set) the server prints a one-time secret at
// startup so operators can still call the endpoint during development.
const _devAdminSecret = crypto.randomBytes(8).toString('hex');

// ── Utilities ────────────────────────────────────────────────────────────────
function nowIso() { return new Date().toISOString(); }
function addHours(hours) { return new Date(Date.now() + hours * 3_600_000).toISOString(); }
function generateToken() { return crypto.randomBytes(4).toString('hex').toUpperCase(); }

// ── Database ─────────────────────────────────────────────────────────────────
function readDb() {
  if (!fs.existsSync(DB_PATH)) {
    return { accounts: [], pendingGifts: [] };
  }
  try {
    const raw = fs.readFileSync(DB_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.accounts)) {
      return { accounts: [], pendingGifts: [] };
    }
    if (!Array.isArray(parsed.pendingGifts)) parsed.pendingGifts = [];
    return parsed;
  } catch {
    return { accounts: [], pendingGifts: [] };
  }
}

function writeDb(db) {
  fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });
  const fd = fs.openSync(DB_PATH, 'w', 0o600);
  try {
    fs.writeFileSync(fd, JSON.stringify(db, null, 2), 'utf8');
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
function hashPassword(password, salt) {
  return crypto
    .pbkdf2Sync(password, salt, PBKDF2_ITERATIONS, PBKDF2_KEYLEN, PBKDF2_DIGEST)
    .toString('hex');
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

function sendJson(res, status, body) {
  const encoded = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(encoded),
    'Cache-Control': 'no-store',
  });
  res.end(encoded);
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
    entitlements: {
      apple: licenses.apple === true && !giftedOut.apple,
      android: licenses.android === true && !giftedOut.android,
      desktop: licenses.desktop === true && !giftedOut.desktop,
    },
    licensesDetail: {
      apple: getLicenseDetail(account, 'apple'),
      android: getLicenseDetail(account, 'android'),
      desktop: getLicenseDetail(account, 'desktop'),
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
    return { error: 'Email and password are required.' };
  }

  const account = db.accounts.find((a) => a.email === normalizedEmail);
  if (!account) {
    return { error: 'Account not found.' };
  }

  const actualHash = hashPassword(String(password), account.passwordSalt);
  const expectedHash = Buffer.from(account.passwordHash, 'hex');
  const actual = Buffer.from(actualHash, 'hex');
  if (expectedHash.length !== actual.length || !crypto.timingSafeEqual(expectedHash, actual)) {
    return { error: 'Invalid email or password.' };
  }
  return { account };
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
function handleRegister(db, payload, res) {
  const email = sanitizeEmail(payload.email);
  const password = String(payload.password || '');
  const apple = payload.appleLicense === true;
  const android = payload.androidLicense === true;
  const desktop = payload.desktopLicense === true;

  if (!email.includes('@')) {
    return sendJson(res, 400, { ok: false, message: 'A valid email is required.' });
  }
  if (password.length < 8) {
    return sendJson(res, 400, {
      ok: false,
      message: 'Password must be at least 8 characters.',
    });
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
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  db.accounts.push(account);
  // Auto-apply any pending gifts that were sent to this email before registration.
  applyPendingGifts(db, account);
  writeDb(db);

  sendEmail(
    email,
    'Verify your Vetviona account email',
    `Welcome to Vetviona!\n\nYour email verification code is: ${verificationToken}\n\nThis code expires in ${TOKEN_EXPIRY_HOURS} hours.\n\nEnter this code in the Vetviona app under Settings → License Account → Verify Email.`,
  );

  const response = { ok: true, account: publicAccount(account, db) };
  if (EMAIL_DEV_MODE) response._devToken = verificationToken;
  return sendJson(res, 201, response);
}

function handleVerifyEmail(db, payload, res) {
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
  writeDb(db);

  return sendJson(res, 200, { ok: true, message: 'Email verified successfully.' });
}

function handleResendVerification(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) return sendJson(res, 401, { ok: false, message: error });

  if (account.emailVerified) {
    return sendJson(res, 200, { ok: true, message: 'Email is already verified.' });
  }

  const token = generateToken();
  account.emailVerificationToken = token;
  account.emailVerificationExpiry = addHours(TOKEN_EXPIRY_HOURS);
  account.updatedAt = nowIso();
  writeDb(db);

  sendEmail(
    account.email,
    'Your Vetviona email verification code',
    `Your email verification code is: ${token}\n\nThis code expires in ${TOKEN_EXPIRY_HOURS} hours.\n\nEnter this code in the Vetviona app under Settings → License Account → Verify Email.`,
  );

  const response = { ok: true, message: 'Verification email sent.' };
  if (EMAIL_DEV_MODE) response._devToken = token;
  return sendJson(res, 200, response);
}

function handleChangePassword(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.currentPassword);
  if (error) return sendJson(res, 401, { ok: false, message: error });

  const newPassword = String(payload.newPassword || '');
  if (newPassword.length < 8) {
    return sendJson(res, 400, {
      ok: false,
      message: 'New password must be at least 8 characters.',
    });
  }
  if (payload.currentPassword === newPassword) {
    return sendJson(res, 400, {
      ok: false,
      message: 'New password must differ from the current password.',
    });
  }

  account.passwordSalt = crypto.randomBytes(16).toString('hex');
  account.passwordHash = hashPassword(newPassword, account.passwordSalt);
  account.updatedAt = nowIso();
  writeDb(db);

  return sendJson(res, 200, { ok: true, message: 'Password changed successfully.' });
}

function handleVerify(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) {
    return sendJson(res, 401, { ok: false, message: error });
  }

  const appType = String(payload.appType || '').toLowerCase();
  const os = String(payload.os || '').toLowerCase();
  const deviceId = String(payload.deviceId || '').trim();
  const appVersion = String(payload.appVersion || '');

  if (!LICENSE_TYPES.has(appType)) {
    return sendJson(res, 400, { ok: false, message: 'appType must be "apple", "android", or "desktop".' });
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
  if (existing) {
    existing.appType = appType;
    existing.os = os;
    existing.lastVerifiedAt = now;
    existing.lastAppVersion = appVersion;
  } else {
    account.devices.push({
      id: deviceId,
      appType,
      os,
      firstVerifiedAt: now,
      lastVerifiedAt: now,
      lastAppVersion: appVersion,
    });
  }
  account.updatedAt = now;
  writeDb(db);

  const pub = publicAccount(account, db);
  return sendJson(res, 200, {
    ok: true,
    message: 'License verified.',
    entitlements: pub.entitlements,
    emailVerified: pub.emailVerified,
    licensesDetail: pub.licensesDetail,
    devices: pub.devices,
  });
}

function handleSync(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) {
    return sendJson(res, 401, { ok: false, message: error });
  }

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
  });
}

function handleGiftInitiate(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) return sendJson(res, 401, { ok: false, message: error });

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
  writeDb(db);

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

function handleGiftClaim(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) return sendJson(res, 401, { ok: false, message: error });

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
    writeDb(db);
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
  writeDb(db);

  return sendJson(res, 200, {
    ok: true,
    message: `${licenseType} license claimed successfully.`,
    account: publicAccount(account, db),
  });
}

function handleGiftCancel(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) return sendJson(res, 401, { ok: false, message: error });

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
  writeDb(db);

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
function handleVoucherCreate(db, payload, res) {
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
  writeDb(db);

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

// ── HTTP Server ───────────────────────────────────────────────────────────────
const server = http.createServer(async (req, res) => {
  if (!req.url) {
    return sendJson(res, 404, { ok: false, message: 'Not found.' });
  }
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJson(res, 200, {
      ok: true,
      status: 'healthy',
      emailMode: EMAIL_DEV_MODE ? 'dev-console' : 'smtp',
    });
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

  const db = readDb();
  if (cleanupExpired(db)) writeDb(db);

  const routes = {
    '/v1/account/register': handleRegister,
    '/v1/account/verify-email': handleVerifyEmail,
    '/v1/account/resend-verification': handleResendVerification,
    '/v1/account/change-password': handleChangePassword,
    '/v1/account/sync': handleSync,
    '/v1/license/verify': handleVerify,
    '/v1/license/gift/initiate': handleGiftInitiate,
    '/v1/license/gift/claim': handleGiftClaim,
    '/v1/license/gift/cancel': handleGiftCancel,
    '/v1/license/voucher/create': handleVoucherCreate,
  };

  const handler = routes[url.pathname];
  if (handler) return handler(db, payload, res);
  return sendJson(res, 404, { ok: false, message: 'Not found.' });
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Vetviona license backend running on http://127.0.0.1:${PORT}`);
  // eslint-disable-next-line no-console
  console.log(`License database: ${DB_PATH}`);
  // eslint-disable-next-line no-console
  console.log(
    EMAIL_DEV_MODE
      ? 'Email: DEV MODE — tokens logged to console. Set SMTP_HOST to use real email.'
      : `Email: SMTP via ${process.env.SMTP_HOST}:${process.env.SMTP_PORT || 587}`,
  );
  if (!process.env.ADMIN_SECRET) {
    // eslint-disable-next-line no-console
    console.log(`\n[DEV] Admin secret (voucher creation): ${_devAdminSecret}`);
    // eslint-disable-next-line no-console
    console.log('[DEV] Set ADMIN_SECRET env var to use a permanent admin secret.\n');
  }
});

