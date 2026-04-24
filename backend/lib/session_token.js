'use strict';

// HMAC-signed session tokens (Phase 2).
//
// Format: base64url(JSON payload) + '.' + base64url(HMAC-SHA256(payload, secret))
//
// Payload fields:
//   v     – schema version (currently 1)
//   sub   – account id
//   email – account email (lowercased)
//   iat   – issued-at (unix seconds)
//   exp   – expires-at (unix seconds; ~24h after iat)
//   jti   – random token id (16 hex chars).  Stored on the account so the
//           server can revoke individual sessions ("sign out everywhere"
//           bumps the account's token-version, invalidating all old tokens).
//   tv    – token-version snapshot at issue time.  Mismatch = revoked.
//   mfa   – true when the account has MFA enabled AND this token was minted
//           after a successful MFA challenge.  Endpoints that require
//           "stepped-up" auth (gift initiate, change-password) check this.

const crypto = require('crypto');

const SESSION_TTL_SECONDS = Number(process.env.SESSION_TTL_SECONDS || 24 * 60 * 60);

function _b64urlEncode(buf) {
  return Buffer.from(buf).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function _b64urlDecode(str) {
  const pad = 4 - (str.length % 4 || 4);
  const padded = str + '='.repeat(pad === 4 ? 0 : pad);
  return Buffer.from(padded.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

/**
 * Mint a session token for [account].  [secret] must be a stable >=32-char
 * hex string (LICENSE_KEY_SECRET / db.meta.licenseKeySecret are reused).
 */
function issueSessionToken(account, secret, { mfa = false } = {}) {
  const now = Math.floor(Date.now() / 1000);
  const jti = crypto.randomBytes(8).toString('hex');
  const payload = {
    v: 1,
    sub: account.id,
    email: account.email,
    iat: now,
    exp: now + SESSION_TTL_SECONDS,
    jti,
    tv: account.tokenVersion || 0,
    mfa: mfa === true,
  };
  const payloadB64 = _b64urlEncode(JSON.stringify(payload));
  const sig = crypto.createHmac('sha256', secret).update(payloadB64).digest();
  return {
    token: `${payloadB64}.${_b64urlEncode(sig)}`,
    jti,
    issuedAt: payload.iat,
    expiresAt: payload.exp,
    mfa: payload.mfa,
  };
}

/**
 * Parse and verify a session token against [secret] and the matching
 * [account] (looked up by `sub`).  Returns `{ ok: true, payload }` on
 * success or `{ ok: false, message }` on any failure.
 */
function verifySessionToken(token, secret, account) {
  if (!token || typeof token !== 'string' || !token.includes('.')) {
    return { ok: false, message: 'Malformed session token.' };
  }
  const [payloadB64, sigB64] = token.split('.', 2);
  let expected;
  try {
    expected = crypto.createHmac('sha256', secret).update(payloadB64).digest();
  } catch {
    return { ok: false, message: 'Invalid session token signature.' };
  }
  let provided;
  try {
    provided = _b64urlDecode(sigB64);
  } catch {
    return { ok: false, message: 'Invalid session token signature.' };
  }
  if (expected.length !== provided.length ||
      !crypto.timingSafeEqual(expected, provided)) {
    return { ok: false, message: 'Invalid session token signature.' };
  }
  let payload;
  try {
    payload = JSON.parse(_b64urlDecode(payloadB64).toString('utf8'));
  } catch {
    return { ok: false, message: 'Malformed session token payload.' };
  }
  if (payload.v !== 1) {
    return { ok: false, message: 'Unsupported token version.' };
  }
  const nowSec = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp <= nowSec) {
    return { ok: false, message: 'Session token expired.' };
  }
  if (!account) {
    return { ok: false, message: 'Account not found for token.' };
  }
  if (account.id !== payload.sub) {
    return { ok: false, message: 'Token does not match account.' };
  }
  if ((account.tokenVersion || 0) !== (payload.tv || 0)) {
    return { ok: false, message: 'Session has been revoked.' };
  }
  return { ok: true, payload };
}

/**
 * Extract a `Bearer <token>` value from the Authorization header.  Returns
 * the token string, or null when missing/malformed.
 */
function extractBearer(req) {
  const h = req.headers && (req.headers.authorization || req.headers.Authorization);
  if (!h || typeof h !== 'string') return null;
  const m = /^Bearer\s+(\S+)$/.exec(h);
  return m ? m[1] : null;
}

module.exports = {
  SESSION_TTL_SECONDS,
  issueSessionToken,
  verifySessionToken,
  extractBearer,
};
