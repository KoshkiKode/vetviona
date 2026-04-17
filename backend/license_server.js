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

const APPLE_OSES = new Set(['ios']);
const ANDROID_OSES = new Set(['android']);
const DESKTOP_OSES = new Set(['windows', 'macos', 'linux']);

function nowIso() {
  return new Date().toISOString();
}

function readDb() {
  if (!fs.existsSync(DB_PATH)) {
    return { accounts: [] };
  }
  try {
    const raw = fs.readFileSync(DB_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.accounts)) {
      return { accounts: [] };
    }
    return parsed;
  } catch {
    return { accounts: [] };
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

function publicAccount(account) {
  return {
    id: account.id,
    email: account.email,
    entitlements: {
      apple: account.licenses.apple === true,
      android: account.licenses.android === true,
      desktop: account.licenses.desktop === true,
    },
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
  const account = {
    id: crypto.randomUUID(),
    email,
    passwordSalt,
    passwordHash: hashPassword(password, passwordSalt),
    licenses: { apple, android, desktop },
    devices: [],
    createdAt: nowIso(),
    updatedAt: nowIso(),
  };

  db.accounts.push(account);
  writeDb(db);
  return sendJson(res, 201, { ok: true, account: publicAccount(account) });
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

  if (appType !== 'apple' && appType !== 'android' && appType !== 'desktop') {
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

  let entitled = false;
  if (appType === 'apple') entitled = account.licenses.apple === true;
  else if (appType === 'android') entitled = account.licenses.android === true;
  else entitled = account.licenses.desktop === true;

  if (!entitled) {
    return sendJson(res, 403, { ok: false, message: `No ${appType} paid entitlement on this account.` });
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

  return sendJson(res, 200, {
    ok: true,
    message: 'License verified.',
    entitlements: {
      apple: account.licenses.apple === true,
      android: account.licenses.android === true,
      desktop: account.licenses.desktop === true,
    },
    devices: publicAccount(account).devices,
  });
}

function handleSync(db, payload, res) {
  const { account, error } = requireAccountAndPassword(db, payload.email, payload.password);
  if (error) {
    return sendJson(res, 401, { ok: false, message: error });
  }
  return sendJson(res, 200, {
    ok: true,
    account: publicAccount(account),
  });
}

const server = http.createServer(async (req, res) => {
  if (!req.url) {
    return sendJson(res, 404, { ok: false, message: 'Not found.' });
  }
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJson(res, 200, { ok: true, status: 'healthy' });
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
  if (url.pathname === '/v1/account/register') {
    return handleRegister(db, payload, res);
  }
  if (url.pathname === '/v1/license/verify') {
    return handleVerify(db, payload, res);
  }
  if (url.pathname === '/v1/account/sync') {
    return handleSync(db, payload, res);
  }
  return sendJson(res, 404, { ok: false, message: 'Not found.' });
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Vetviona license backend running on http://127.0.0.1:${PORT}`);
  // eslint-disable-next-line no-console
  console.log(`License database: ${DB_PATH}`);
});
