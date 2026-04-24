'use strict';

// RFC 6238 TOTP (Time-based One-Time Password) — opt-in MFA.
//
// Defaults match what authenticator apps (Google Authenticator, Authy, 1Password)
// expect: SHA-1, 6-digit codes, 30-second steps.

const crypto = require('crypto');

const STEP_SECONDS = 30;
const DIGITS = 6;
const ALGO = 'sha1';
// Allow ±1 step of clock skew during verification.
const ACCEPTED_WINDOW = 1;

// RFC 4648 base32 alphabet.
const _BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function _base32Encode(buf) {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const b of buf) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      out += _BASE32_ALPHABET[(value >>> bits) & 0x1f];
    }
  }
  if (bits > 0) {
    out += _BASE32_ALPHABET[(value << (5 - bits)) & 0x1f];
  }
  return out;
}

function _base32Decode(str) {
  const clean = String(str || '').toUpperCase().replace(/[^A-Z2-7]/g, '');
  let bits = 0;
  let value = 0;
  const out = [];
  for (const ch of clean) {
    const idx = _BASE32_ALPHABET.indexOf(ch);
    if (idx < 0) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.push((value >>> bits) & 0xff);
    }
  }
  return Buffer.from(out);
}

/**
 * Generate a fresh TOTP secret as a base32 string suitable for embedding
 * in an `otpauth://` URI.
 */
function generateSecret() {
  return _base32Encode(crypto.randomBytes(20));
}

function _hotp(secret, counter) {
  const key = _base32Decode(secret);
  const buf = Buffer.alloc(8);
  let c = counter;
  // Big-endian 64-bit counter.
  for (let i = 7; i >= 0; i--) {
    buf[i] = c & 0xff;
    c = Math.floor(c / 256);
  }
  const hmac = crypto.createHmac(ALGO, key).update(buf).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  const code =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  return String(code % (10 ** DIGITS)).padStart(DIGITS, '0');
}

/**
 * Verify a 6-digit TOTP code.  Accepts the current step plus ±1 step of
 * clock skew.  Returns true on success.
 */
function verifyCode(secret, code) {
  if (!secret || !code) return false;
  const normalized = String(code).replace(/\s+/g, '');
  if (!/^\d{6}$/.test(normalized)) return false;
  const counter = Math.floor(Date.now() / 1000 / STEP_SECONDS);
  for (let w = -ACCEPTED_WINDOW; w <= ACCEPTED_WINDOW; w++) {
    const expected = _hotp(secret, counter + w);
    if (crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(normalized))) {
      return true;
    }
  }
  return false;
}

/**
 * Build the otpauth:// URI an authenticator app scans from a QR code.
 */
function otpauthUri({ secret, label, issuer = 'Vetviona' }) {
  const enc = encodeURIComponent;
  return `otpauth://totp/${enc(issuer)}:${enc(label)}` +
    `?secret=${secret}&issuer=${enc(issuer)}&algorithm=SHA1&digits=${DIGITS}&period=${STEP_SECONDS}`;
}

/**
 * Generate N short hex recovery codes the user can paper-print.  Each code
 * is single-use and stored hashed (SHA-256, no per-code salt — codes are
 * already 80-bit random) on the account.
 */
function generateRecoveryCodes(count = 10) {
  const codes = [];
  for (let i = 0; i < count; i++) {
    codes.push(crypto.randomBytes(5).toString('hex').toUpperCase());
  }
  return codes;
}

function hashRecoveryCode(code) {
  return crypto.createHash('sha256')
    .update(String(code).trim().toUpperCase())
    .digest('hex');
}

module.exports = {
  STEP_SECONDS, DIGITS,
  generateSecret, verifyCode, otpauthUri,
  generateRecoveryCodes, hashRecoveryCode,
};
