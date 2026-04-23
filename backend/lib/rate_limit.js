'use strict';

// Per-IP and per-account rate limiting + exponential account lockout.
//
// In-memory token-bucket implementation — fine for a single Fargate task or
// a single Lambda warm container.  For multi-instance HA, swap the buckets
// for a Redis-backed implementation that exposes the same `consume()` /
// `recordFailure()` / `recordSuccess()` shape.  See `backend/DEPLOY-AWS.md`
// "Multi-instance HA" section.

const crypto = require('crypto');

// Default: 30 requests per minute per IP, 10 per minute per account, on
// auth-sensitive endpoints.  Override via env for stress tests.
const IP_BUCKET_CAPACITY = Number(process.env.RATE_LIMIT_IP_PER_MIN || 30);
const ACCOUNT_BUCKET_CAPACITY = Number(process.env.RATE_LIMIT_ACCOUNT_PER_MIN || 10);
const REFILL_INTERVAL_MS = 60_000;

// Lockout: starts at 1 min after 5 consecutive failures, doubles each time
// up to 60 minutes.  Successful sign-in resets the counter.
const LOCKOUT_THRESHOLD = Number(process.env.LOCKOUT_THRESHOLD || 5);
const LOCKOUT_BASE_MS = Number(process.env.LOCKOUT_BASE_SECONDS || 60) * 1_000;
const LOCKOUT_MAX_MS = Number(process.env.LOCKOUT_MAX_SECONDS || 3_600) * 1_000;

const _ipBuckets = new Map();        // ip -> { tokens, refilledAt }
const _accountBuckets = new Map();   // emailLower -> { tokens, refilledAt }
const _failures = new Map();         // emailLower -> { count, lockedUntil }

function _refill(bucket, capacity) {
  const now = Date.now();
  const elapsed = now - bucket.refilledAt;
  if (elapsed >= REFILL_INTERVAL_MS) {
    bucket.tokens = capacity;
    bucket.refilledAt = now;
  }
}

function _consume(map, key, capacity) {
  if (!key) return { ok: true, retryAfterSeconds: 0 };
  let b = map.get(key);
  if (!b) {
    b = { tokens: capacity, refilledAt: Date.now() };
    map.set(key, b);
  }
  _refill(b, capacity);
  if (b.tokens <= 0) {
    const retryAfterSeconds = Math.ceil(
      (b.refilledAt + REFILL_INTERVAL_MS - Date.now()) / 1000,
    );
    return { ok: false, retryAfterSeconds: Math.max(retryAfterSeconds, 1) };
  }
  b.tokens -= 1;
  return { ok: true, retryAfterSeconds: 0 };
}

/**
 * Charge one token against both the per-IP and per-account buckets.
 * Returns `{ ok: false, retryAfterSeconds, scope }` when rate-limited;
 * otherwise `{ ok: true }`.
 */
function consume({ ip, email }) {
  const ipKey = (ip || '').toString();
  const acctKey = (email || '').toString().toLowerCase();
  const ipR = _consume(_ipBuckets, ipKey, IP_BUCKET_CAPACITY);
  if (!ipR.ok) return { ...ipR, scope: 'ip' };
  if (acctKey) {
    const acctR = _consume(_accountBuckets, acctKey, ACCOUNT_BUCKET_CAPACITY);
    if (!acctR.ok) return { ...acctR, scope: 'account' };
  }
  return { ok: true };
}

/**
 * Check whether the account is currently locked out from auth attempts.
 * Returns `{ locked: true, retryAfterSeconds }` or `{ locked: false }`.
 */
function checkLockout(email) {
  const key = (email || '').toLowerCase();
  if (!key) return { locked: false };
  const f = _failures.get(key);
  if (!f || !f.lockedUntil) return { locked: false };
  const remaining = f.lockedUntil - Date.now();
  if (remaining <= 0) {
    f.lockedUntil = 0;
    return { locked: false };
  }
  return { locked: true, retryAfterSeconds: Math.ceil(remaining / 1000) };
}

/**
 * Record a failed authentication attempt.  Triggers exponential backoff
 * lockout once the threshold is crossed.  Safe to call multiple times.
 */
function recordFailure(email) {
  const key = (email || '').toLowerCase();
  if (!key) return { locked: false };
  const f = _failures.get(key) || { count: 0, lockedUntil: 0 };
  f.count = (f.count || 0) + 1;
  if (f.count >= LOCKOUT_THRESHOLD) {
    const overshoot = f.count - LOCKOUT_THRESHOLD;
    const ms = Math.min(LOCKOUT_BASE_MS * (2 ** overshoot), LOCKOUT_MAX_MS);
    f.lockedUntil = Date.now() + ms;
  }
  _failures.set(key, f);
  return { count: f.count, lockedUntil: f.lockedUntil };
}

/**
 * Reset the failure counter for an account after a successful authentication.
 */
function recordSuccess(email) {
  const key = (email || '').toLowerCase();
  if (!key) return;
  _failures.delete(key);
}

/**
 * Best-effort client IP extraction.  Trusts X-Forwarded-For when running
 * behind ALB / API Gateway (set TRUST_PROXY=true).
 */
function clientIp(req) {
  if (process.env.TRUST_PROXY === 'true') {
    const xff = req.headers['x-forwarded-for'];
    if (typeof xff === 'string' && xff.length > 0) {
      return xff.split(',')[0].trim();
    }
  }
  return (
    (req.socket && req.socket.remoteAddress) ||
    'unknown'
  );
}

// Test-only: clears all in-memory state.  Exported behind a property name
// that won't collide with anything else.
function _resetForTests() {
  _ipBuckets.clear();
  _accountBuckets.clear();
  _failures.clear();
}

// Lightweight self-test marker so unit tests can verify they're hitting the
// same module instance as the server.
const _instanceId = crypto.randomBytes(4).toString('hex');

module.exports = {
  consume,
  checkLockout,
  recordFailure,
  recordSuccess,
  clientIp,
  _resetForTests,
  _instanceId,
  IP_BUCKET_CAPACITY,
  ACCOUNT_BUCKET_CAPACITY,
  LOCKOUT_THRESHOLD,
};
