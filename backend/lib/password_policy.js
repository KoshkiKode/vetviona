'use strict';

// Stronger password policy used by /v1/account/register, /v1/account/change-password,
// and /v1/account/reset-password.
//
// Rules (Phase 2 plan):
//   • length >= 10
//   • must include 3 of 4 character classes:
//       lower, upper, digit, symbol (anything not in [A-Za-z0-9])
//   • must not appear in the embedded common-passwords list
//
// We embed a SMALL list (top common passwords + obvious vetviona/koshkikode
// brand strings) on purpose — a 100k-entry list bloats the deploy artifact
// without blocking real attackers, and the rate-limit layer is what prevents
// online brute force.  Operators can extend the list via the
// EXTRA_BLOCKED_PASSWORDS env var (newline-, comma-, or space-separated).

const MIN_LENGTH = 10;

// Lowercased once, compared timing-insensitively (this list is public anyway).
const _builtIn = [
  'password', 'password1', 'password123', 'passw0rd', 'p@ssw0rd', 'p@ssword',
  '12345678', '123456789', '1234567890', 'qwerty', 'qwertyuiop', 'qwerty123',
  'iloveyou', 'admin1234', 'administrator', 'welcome1', 'welcome123',
  'letmein', 'letmein123', 'changeme', 'changeme1', 'changemenow',
  'abc12345', 'abcd1234', 'monkey123', 'football1', 'baseball1',
  'starwars1', 'dragon123', 'master123', 'sunshine1', 'princess1',
  'shadow123', 'superman1', 'batman123', 'trustno1!', 'iloveyou1',
  'vetviona', 'vetviona1', 'vetviona!', 'koshkikode', 'koshkikode1',
  'genealogy', 'genealogy1', 'familytree', 'familytree1',
];

function _envExtras() {
  const raw = process.env.EXTRA_BLOCKED_PASSWORDS || '';
  if (!raw) return [];
  return raw
    .split(/[\s,]+/)
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

function _commonSet() {
  return new Set([..._builtIn.map((s) => s.toLowerCase()), ..._envExtras()]);
}

function _classCount(pw) {
  let n = 0;
  if (/[a-z]/.test(pw)) n++;
  if (/[A-Z]/.test(pw)) n++;
  if (/[0-9]/.test(pw)) n++;
  if (/[^A-Za-z0-9]/.test(pw)) n++;
  return n;
}

/**
 * Validate a candidate password.  Returns `{ ok: true }` or
 * `{ ok: false, message }` with a user-facing message that the client can
 * surface verbatim.
 */
function validatePassword(password, { email = '' } = {}) {
  const pw = String(password || '');
  if (pw.length < MIN_LENGTH) {
    return { ok: false, message: `Password must be at least ${MIN_LENGTH} characters.` };
  }
  if (pw.length > 256) {
    return { ok: false, message: 'Password is too long (max 256 characters).' };
  }
  if (_classCount(pw) < 3) {
    return {
      ok: false,
      message:
        'Password must include at least 3 of: lowercase, uppercase, digit, symbol.',
    };
  }
  const lower = pw.toLowerCase();
  if (_commonSet().has(lower)) {
    return { ok: false, message: 'That password is too common. Pick something unique.' };
  }
  // Reject password == email local-part / full email.
  if (email) {
    const e = String(email).toLowerCase().trim();
    if (e && (lower === e || lower === e.split('@')[0])) {
      return { ok: false, message: 'Password must not match your email address.' };
    }
  }
  return { ok: true };
}

/**
 * 0-4 score useful for a strength meter on the client.
 */
function scorePassword(password) {
  const pw = String(password || '');
  if (!pw) return 0;
  let s = 0;
  if (pw.length >= MIN_LENGTH) s++;
  if (pw.length >= 14) s++;
  if (_classCount(pw) >= 3) s++;
  if (_classCount(pw) === 4) s++;
  if (_commonSet().has(pw.toLowerCase())) s = Math.min(s, 1);
  return Math.min(s, 4);
}

module.exports = { MIN_LENGTH, validatePassword, scorePassword };
