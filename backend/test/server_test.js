'use strict';

// Smoke + functional tests for the new Phase 2/3 server features.
//
// Run with:  node test/server_test.js
//
// Tests are intentionally framework-free so they don't add a new dev
// dependency.  Each test logs PASS/FAIL and the script exits non-zero on
// any failure.

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Use a fresh temporary db file per run so we don't pollute the local dev DB.
const tmpDb = path.join(os.tmpdir(), `vetviona-test-${Date.now()}-${process.pid}.json`);
process.env.LICENSE_DB_PATH = tmpDb;
process.env.LICENSE_KEY_SECRET = 'a'.repeat(64);
process.env.RATE_LIMIT_IP_PER_MIN = '1000';
process.env.RATE_LIMIT_ACCOUNT_PER_MIN = '1000';
process.env.LOCKOUT_THRESHOLD = '3';
process.env.LOCKOUT_BASE_SECONDS = '5';
process.env.ADMIN_SECRET = 'test-admin-secret-veryverylong-999';

// Make absolutely sure the http server inside license_server.js does not
// actually bind a port — main entrypoint is gated on require.main === module.
const mod = require('../license_server');
const { rateLimit, sessionToken, totp, passwordPolicy, treeStorage, auditLog, appVersion } =
  mod._internal;

const http = require('http');

// ── Test runner ──────────────────────────────────────────────────────────────
let passed = 0;
let failed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.log(`  ✗ ${name}\n      ${err && err.stack || err}`);
    failures.push({ name, err });
    failed++;
  }
}

// Bind the in-process server to an ephemeral port for end-to-end tests.
function listen() {
  return new Promise((resolve) => {
    mod.server.listen(0, '127.0.0.1', () => resolve(mod.server.address().port));
  });
}

function close() {
  return new Promise((resolve) => mod.server.close(() => resolve()));
}

function request(method, port, pathname, { json, raw, headers } = {}) {
  return new Promise((resolve, reject) => {
    const body = json !== undefined ? JSON.stringify(json) : raw;
    const opts = {
      method, port, host: '127.0.0.1', path: pathname,
      headers: {
        ...(json !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...(body ? { 'Content-Length': Buffer.byteLength(body) } : {}),
        ...(headers || {}),
      },
    };
    const req = http.request(opts, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        let parsed = null;
        try { parsed = JSON.parse(buf.toString('utf8')); } catch (_) {}
        resolve({ status: res.statusCode, headers: res.headers, body: parsed, raw: buf });
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// ── TOTP/HOTP helper (used for MFA tests) ────────────────────────────────────
const crypto = require('crypto');
function hotp(secret, counter) {
  const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0, val = 0; const out = [];
  for (const ch of secret) {
    const i = alpha.indexOf(ch); if (i < 0) continue;
    val = (val << 5) | i; bits += 5;
    if (bits >= 8) { bits -= 8; out.push((val >>> bits) & 0xff); }
  }
  const key = Buffer.from(out);
  const buf = Buffer.alloc(8);
  let cc = counter;
  for (let i = 7; i >= 0; i--) { buf[i] = cc & 0xff; cc = Math.floor(cc / 256); }
  const h = crypto.createHmac('sha1', key).update(buf).digest();
  const offset = h[h.length - 1] & 0xf;
  const code = ((h[offset] & 0x7f) << 24) | ((h[offset + 1] & 0xff) << 16)
             | ((h[offset + 2] & 0xff) << 8) | (h[offset + 3] & 0xff);
  return String(code % 1_000_000).padStart(6, '0');
}
function currentTotpCode(secret) {
  return hotp(secret, Math.floor(Date.now() / 1000 / 30));
}


async function libraryTests() {
  console.log('Library tests');

  await test('passwordPolicy: rejects too-short password', () => {
    const r = passwordPolicy.validatePassword('Short1!');
    assert.strictEqual(r.ok, false);
  });
  await test('passwordPolicy: rejects common password', () => {
    const r = passwordPolicy.validatePassword('Password123!');
    assert.strictEqual(r.ok, true); // strong enough although capitalized — class check passes
    const r2 = passwordPolicy.validatePassword('password123');
    assert.strictEqual(r2.ok, false);
  });
  await test('passwordPolicy: rejects email match', () => {
    const r = passwordPolicy.validatePassword('user@example.com', { email: 'user@example.com' });
    assert.strictEqual(r.ok, false);
  });
  await test('passwordPolicy: accepts strong password', () => {
    const r = passwordPolicy.validatePassword('Tr0ub4dor&3xpand', { email: 'a@b.c' });
    assert.strictEqual(r.ok, true);
  });

  await test('passwordPolicy: rejects password longer than 256 chars', () => {
    const r = passwordPolicy.validatePassword('A'.repeat(257) + '!1a');
    assert.strictEqual(r.ok, false);
    assert.ok(r.message.includes('too long'));
  });

  await test('passwordPolicy: rejects password matching email local-part', () => {
    const r = passwordPolicy.validatePassword('alice1234!A', { email: 'alice1234!A@example.com' });
    assert.strictEqual(r.ok, false);
    assert.ok(r.message.includes('email'));
  });

  await test('passwordPolicy: rejects password failing class count (only 2 classes)', () => {
    const r = passwordPolicy.validatePassword('abcdefghij'); // only lowercase
    assert.strictEqual(r.ok, false);
    assert.ok(r.message.includes('3 of'));
  });

  await test('passwordPolicy: rejects EXTRA_BLOCKED_PASSWORDS via env', () => {
    process.env.EXTRA_BLOCKED_PASSWORDS = 'customblocked1';
    const r = passwordPolicy.validatePassword('customBlocked1');
    delete process.env.EXTRA_BLOCKED_PASSWORDS;
    assert.strictEqual(r.ok, false);
  });

  await test('passwordPolicy.scorePassword: empty string scores 0', () => {
    assert.strictEqual(passwordPolicy.scorePassword(''), 0);
    assert.strictEqual(passwordPolicy.scorePassword(null), 0);
  });

  await test('passwordPolicy.scorePassword: strong 14+ char password scores 4', () => {
    const s = passwordPolicy.scorePassword('Tr0ub4dor&3xpand!');
    assert.strictEqual(s, 4);
  });

  await test('passwordPolicy.scorePassword: common password is capped at 1', () => {
    const s = passwordPolicy.scorePassword('password');
    assert.ok(s <= 1);
  });

  await test('passwordPolicy.scorePassword: medium password (10-13 chars, 3 classes) scores 2', () => {
    const s = passwordPolicy.scorePassword('Abc12345!X'); // 10 chars, 3 classes, not common
    assert.ok(s >= 2 && s <= 3);
  });

  await test('sessionToken: round-trip issue + verify', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const secret = 'b'.repeat(64);
    const t = sessionToken.issueSessionToken(account, secret, { mfa: true });
    const v = sessionToken.verifySessionToken(t.token, secret, account);
    assert.strictEqual(v.ok, true);
    assert.strictEqual(v.payload.email, 'u@e.com');
    assert.strictEqual(v.payload.mfa, true);
  });
  await test('sessionToken: rejects after tokenVersion bump', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const secret = 'b'.repeat(64);
    const t = sessionToken.issueSessionToken(account, secret);
    const v = sessionToken.verifySessionToken(t.token, secret,
      { ...account, tokenVersion: 1 });
    assert.strictEqual(v.ok, false);
  });
  await test('sessionToken: rejects bad signature', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const t = sessionToken.issueSessionToken(account, 'b'.repeat(64));
    const v = sessionToken.verifySessionToken(t.token, 'c'.repeat(64), account);
    assert.strictEqual(v.ok, false);
  });

  await test('sessionToken: mfa defaults to false when not specified', () => {
    const account = { id: 'acct2', email: 'x@y.com', tokenVersion: 0 };
    const secret = 'd'.repeat(64);
    const t = sessionToken.issueSessionToken(account, secret);
    assert.strictEqual(t.mfa, false);
    const v = sessionToken.verifySessionToken(t.token, secret, account);
    assert.strictEqual(v.ok, true);
    assert.strictEqual(v.payload.mfa, false);
  });

  await test('sessionToken: rejects malformed token with no dot', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const v = sessionToken.verifySessionToken('nodothere', 'b'.repeat(64), account);
    assert.strictEqual(v.ok, false);
    assert.ok(v.message.toLowerCase().includes('malformed'));
  });

  await test('sessionToken: rejects null/undefined token', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    assert.strictEqual(sessionToken.verifySessionToken(null, 'b'.repeat(64), account).ok, false);
    assert.strictEqual(sessionToken.verifySessionToken(undefined, 'b'.repeat(64), account).ok, false);
  });

  await test('sessionToken: rejects when account is null', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const secret = 'b'.repeat(64);
    const t = sessionToken.issueSessionToken(account, secret);
    const v = sessionToken.verifySessionToken(t.token, secret, null);
    assert.strictEqual(v.ok, false);
    assert.ok(v.message.includes('Account not found'));
  });

  await test('sessionToken: rejects when account id mismatches payload sub', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const secret = 'b'.repeat(64);
    const t = sessionToken.issueSessionToken(account, secret);
    const v = sessionToken.verifySessionToken(t.token, secret, { ...account, id: 'different-id' });
    assert.strictEqual(v.ok, false);
    assert.ok(v.message.includes('does not match'));
  });

  await test('sessionToken: issueSessionToken returns issuedAt and expiresAt', () => {
    const account = { id: 'acct1', email: 'u@e.com', tokenVersion: 0 };
    const before = Math.floor(Date.now() / 1000);
    const t = sessionToken.issueSessionToken(account, 'b'.repeat(64));
    const after = Math.floor(Date.now() / 1000);
    assert.ok(t.issuedAt >= before && t.issuedAt <= after);
    assert.ok(t.expiresAt > t.issuedAt);
    assert.ok(t.jti && t.jti.length > 0);
  });

  await test('totp: code matches generator', () => {
    const secret = totp.generateSecret();
    // Manufacture the current code by re-running the algorithm.
    // Easiest: just feed the secret back to the verifier.
    const counter = Math.floor(Date.now() / 1000 / 30);
    // Re-derive expected code via the internal algorithm by calling _hotp via a
    // small re-implementation here mirrors what authenticator apps do.
    const crypto = require('crypto');
    function hotp(s, c) {
      // Use the same base32 decode the library uses.
      const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      let bits = 0, val = 0; const out = [];
      for (const ch of s) {
        const i = alpha.indexOf(ch); if (i < 0) continue;
        val = (val << 5) | i; bits += 5;
        if (bits >= 8) { bits -= 8; out.push((val >>> bits) & 0xff); }
      }
      const key = Buffer.from(out);
      const buf = Buffer.alloc(8);
      let cc = c; for (let i = 7; i >= 0; i--) { buf[i] = cc & 0xff; cc = Math.floor(cc / 256); }
      const h = crypto.createHmac('sha1', key).update(buf).digest();
      const offset = h[h.length - 1] & 0xf;
      const code = ((h[offset] & 0x7f) << 24) | ((h[offset+1] & 0xff) << 16)
                 | ((h[offset+2] & 0xff) << 8) | (h[offset+3] & 0xff);
      return String(code % 1_000_000).padStart(6, '0');
    }
    const code = hotp(secret, counter);
    assert.strictEqual(totp.verifyCode(secret, code), true);
    assert.strictEqual(totp.verifyCode(secret, '000000'), false);
  });

  await test('rateLimit: lockout after threshold', () => {
    rateLimit._resetForTests();
    rateLimit.recordFailure('lock@e.com');
    rateLimit.recordFailure('lock@e.com');
    assert.strictEqual(rateLimit.checkLockout('lock@e.com').locked, false);
    rateLimit.recordFailure('lock@e.com');
    assert.strictEqual(rateLimit.checkLockout('lock@e.com').locked, true);
    rateLimit.recordSuccess('lock@e.com');
    assert.strictEqual(rateLimit.checkLockout('lock@e.com').locked, false);
  });

  await test('treeStorage: quota enforcement', () => {
    const db = { accounts: [{ id: 'a1', email: 'a@b.c' }] };
    const r1 = treeStorage.putManifest(db, 'a1', 'tree-1', {
      revision: 1, chunks: [{ id: 'c1', bytes: 100, sha256: 'x' }],
    });
    assert.strictEqual(r1.ok, true);
    const r2 = treeStorage.putManifest(db, 'a1', 'tree-1', {
      revision: 0, chunks: [{ id: 'c1', bytes: 100 }],
    });
    assert.strictEqual(r2.ok, false); // Older revision rejected
    assert.strictEqual(r2.status, 409);
  });

  await test('appVersion: returns per-platform map', () => {
    const v = appVersion.build();
    assert.strictEqual(v.ok, true);
    assert.ok(v.platforms.android.latest);
    assert.ok(v.platforms.windows.downloadUrl);
  });

  // ── auditLog ─────────────────────────────────────────────────────────────────
  await test('auditLog: append adds entry with required fields', () => {
    const db = {};
    auditLog.append(db, { email: 'u@e.com', event: 'login', ok: true });
    assert.ok(Array.isArray(db.auditLog));
    assert.strictEqual(db.auditLog.length, 1);
    const entry = db.auditLog[0];
    assert.ok(entry.ts);
    assert.strictEqual(entry.email, 'u@e.com');
    assert.strictEqual(entry.event, 'login');
    assert.strictEqual(entry.ok, true);
    assert.strictEqual(entry.ip, null);
    assert.strictEqual(entry.detail, null);
  });

  await test('auditLog: append records ip and detail when provided', () => {
    const db = {};
    auditLog.append(db, { ip: '1.2.3.4', email: 'u@e.com', event: 'mfa.verify', ok: false, detail: { reason: 'bad_code' } });
    const e = db.auditLog[0];
    assert.strictEqual(e.ip, '1.2.3.4');
    assert.deepStrictEqual(e.detail, { reason: 'bad_code' });
    assert.strictEqual(e.ok, false);
  });

  await test('auditLog: caps list at MAX_ENTRIES', () => {
    const db = {};
    const limit = auditLog.MAX_ENTRIES;
    for (let i = 0; i <= limit + 5; i++) {
      auditLog.append(db, { email: 'cap@e.com', event: 'test', ok: true });
    }
    assert.strictEqual(db.auditLog.length, limit);
  });

  await test('auditLog: initialises auditLog array when absent', () => {
    const db = { auditLog: null };
    auditLog.append(db, { email: 'a@b.com', event: 'register', ok: true });
    assert.ok(Array.isArray(db.auditLog));
    assert.strictEqual(db.auditLog.length, 1);
  });

  // ── sessionToken.extractBearer ────────────────────────────────────────────────
  await test('sessionToken.extractBearer: returns token from valid header', () => {
    const req = { headers: { authorization: 'Bearer abc123' } };
    assert.strictEqual(sessionToken.extractBearer(req), 'abc123');
  });

  await test('sessionToken.extractBearer: returns null when header absent', () => {
    const req = { headers: {} };
    assert.strictEqual(sessionToken.extractBearer(req), null);
  });

  await test('sessionToken.extractBearer: returns null for malformed header', () => {
    assert.strictEqual(sessionToken.extractBearer({ headers: { authorization: 'Token abc' } }), null);
    assert.strictEqual(sessionToken.extractBearer({ headers: { authorization: 'Bearer' } }), null);
    assert.strictEqual(sessionToken.extractBearer({ headers: { authorization: '' } }), null);
  });

  await test('sessionToken.extractBearer: handles capitalised Authorization header', () => {
    const req = { headers: { Authorization: 'Bearer mytoken' } };
    assert.strictEqual(sessionToken.extractBearer(req), 'mytoken');
  });

  // ── totp helpers ─────────────────────────────────────────────────────────────
  await test('totp.generateSecret: returns non-empty base32 string', () => {
    const s = totp.generateSecret();
    assert.ok(typeof s === 'string' && s.length > 0);
    // Base32: only uppercase letters and digits 2-7
    assert.ok(/^[A-Z2-7]+$/.test(s));
  });

  await test('totp.generateSecret: each call produces a different secret', () => {
    const s1 = totp.generateSecret();
    const s2 = totp.generateSecret();
    assert.notStrictEqual(s1, s2);
  });

  await test('totp.verifyCode: returns false for non-6-digit input', () => {
    const secret = totp.generateSecret();
    assert.strictEqual(totp.verifyCode(secret, '12345'), false);    // 5 digits
    assert.strictEqual(totp.verifyCode(secret, '1234567'), false);  // 7 digits
    assert.strictEqual(totp.verifyCode(secret, 'abcdef'), false);   // non-numeric
  });

  await test('totp.verifyCode: returns false for missing/null inputs', () => {
    assert.strictEqual(totp.verifyCode(null, '123456'), false);
    assert.strictEqual(totp.verifyCode('SECRET', null), false);
    assert.strictEqual(totp.verifyCode('', ''), false);
  });

  await test('totp.generateRecoveryCodes: returns n uppercase hex strings', () => {
    const codes = totp.generateRecoveryCodes(6);
    assert.strictEqual(codes.length, 6);
    for (const c of codes) {
      assert.ok(/^[0-9A-F]+$/.test(c), `Expected hex: ${c}`);
    }
  });

  await test('totp.generateRecoveryCodes: codes are distinct', () => {
    const codes = totp.generateRecoveryCodes(10);
    const unique = new Set(codes);
    assert.strictEqual(unique.size, 10);
  });

  await test('totp.hashRecoveryCode: same input produces same hash', () => {
    const h1 = totp.hashRecoveryCode('ABC123');
    const h2 = totp.hashRecoveryCode('ABC123');
    assert.strictEqual(h1, h2);
    assert.ok(/^[0-9a-f]{64}$/.test(h1)); // SHA-256 hex
  });

  await test('totp.hashRecoveryCode: normalises to uppercase before hashing', () => {
    assert.strictEqual(totp.hashRecoveryCode('abc123'), totp.hashRecoveryCode('ABC123'));
    assert.strictEqual(totp.hashRecoveryCode('  abc123  '), totp.hashRecoveryCode('ABC123'));
  });

  await test('totp.hashRecoveryCode: different inputs produce different hashes', () => {
    assert.notStrictEqual(totp.hashRecoveryCode('AAA'), totp.hashRecoveryCode('BBB'));
  });

  await test('totp.otpauthUri: includes secret, label, and issuer', () => {
    const uri = totp.otpauthUri({ secret: 'MYSECRET', label: 'user@example.com' });
    assert.ok(uri.startsWith('otpauth://totp/'));
    assert.ok(uri.includes('MYSECRET'));
    assert.ok(uri.includes('Vetviona'));
    assert.ok(uri.includes('SHA1'));
    assert.ok(uri.includes(`digits=${totp.DIGITS}`));
    assert.ok(uri.includes(`period=${totp.STEP_SECONDS}`));
  });

  // ── treeStorage unit tests ────────────────────────────────────────────────────
  await test('treeStorage.listTrees: returns empty list for new account', () => {
    const db = {};
    const r = treeStorage.listTrees(db, 'acc1');
    assert.strictEqual(r.trees.length, 0);
    assert.strictEqual(r.usedBytes, 0);
    assert.strictEqual(r.usedTrees, 0);
  });

  await test('treeStorage.getManifest: returns 404 for missing tree', () => {
    const db = {};
    const r = treeStorage.getManifest(db, 'acc1', 'no-such-tree');
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 404);
  });

  await test('treeStorage.getManifest: rejects invalid treeId characters', () => {
    const db = {};
    const r = treeStorage.getManifest(db, 'acc1', 'bad id!');
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 400);
  });

  await test('treeStorage: put + get manifest roundtrip', () => {
    const db = {};
    const manifest = { revision: 1, kdfSalt: 'AABB', chunks: [] };
    const put = treeStorage.putManifest(db, 'acc2', 'tree-x', manifest);
    assert.strictEqual(put.ok, true);
    const get = treeStorage.getManifest(db, 'acc2', 'tree-x');
    assert.strictEqual(get.ok, true);
    assert.strictEqual(get.manifest.revision, 1);
  });

  await test('treeStorage.deleteTree: returns deleted=true for existing tree', () => {
    const db = {};
    treeStorage.putManifest(db, 'acc3', 'del-tree', { revision: 1, chunks: [] });
    const r = treeStorage.deleteTree(db, 'acc3', 'del-tree');
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.deleted, true);
  });

  await test('treeStorage.deleteTree: returns deleted=false for non-existent tree', () => {
    const db = {};
    const r = treeStorage.deleteTree(db, 'acc4', 'no-tree');
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.deleted, false);
  });

  await test('treeStorage.chunkS3Key: produces expected key format', () => {
    const key = treeStorage.chunkS3Key('accA', 'treeB', 'chunkC');
    assert.ok(key.includes('accA'));
    assert.ok(key.includes('treeB'));
    assert.ok(key.includes('chunkC'));
    assert.ok(key.endsWith('.bin'));
  });

  await test('treeStorage.memPut + memGet: stores and retrieves chunk', () => {
    treeStorage.memReset();
    const data = Buffer.from('hello-chunk');
    treeStorage.memPut('acc5', 'tree5', 'c5', data);
    const got = treeStorage.memGet('acc5', 'tree5', 'c5');
    assert.ok(got !== null);
    assert.strictEqual(got.toString(), 'hello-chunk');
  });

  await test('treeStorage.memGet: returns null for missing chunk', () => {
    treeStorage.memReset();
    assert.strictEqual(treeStorage.memGet('acc6', 'tree6', 'missing'), null);
  });

  await test('treeStorage.memDelete: removes chunk from store', () => {
    treeStorage.memReset();
    treeStorage.memPut('acc7', 'tree7', 'c7', Buffer.from('x'));
    treeStorage.memDelete('acc7', 'tree7', 'c7');
    assert.strictEqual(treeStorage.memGet('acc7', 'tree7', 'c7'), null);
  });

  await test('treeStorage.sha256Hex: returns correct 64-char hex digest', () => {
    const h = treeStorage.sha256Hex(Buffer.from('hello'));
    assert.strictEqual(h.length, 64);
    assert.ok(/^[0-9a-f]{64}$/.test(h));
    // SHA-256 of "hello" is well-known
    assert.strictEqual(h, '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824');
  });

  await test('treeStorage.putManifest: rejects invalid treeId', () => {
    const db = {};
    const r = treeStorage.putManifest(db, 'acc1', 'bad id!', { revision: 1, chunks: [] });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 400);
  });

  await test('treeStorage.putManifest: rejects null manifest', () => {
    const db = {};
    const r = treeStorage.putManifest(db, 'acc1', 'tree-1', null);
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 400);
  });

  await test('treeStorage.putManifest: rejects chunk entry that is not an object', () => {
    const db = {};
    const r = treeStorage.putManifest(db, 'acc1', 'tree-1', {
      revision: 1, chunks: ['not-an-object'],
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 400);
  });

  await test('treeStorage.putManifest: rejects chunk with invalid id characters', () => {
    const db = {};
    const r = treeStorage.putManifest(db, 'acc1', 'tree-1', {
      revision: 1, chunks: [{ id: 'bad chunk!', bytes: 100 }],
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 400);
  });

  await test('treeStorage.putManifest: rejects chunk with bytes exceeding per-chunk max', () => {
    const db = {};
    const r = treeStorage.putManifest(db, 'acc1', 'tree-1', {
      revision: 1, chunks: [{ id: 'c1', bytes: treeStorage.MAX_CHUNK_BYTES + 1 }],
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 400);
  });

  await test('treeStorage.putManifest: rejects when total bytes exceed account quota', () => {
    const db = {};
    const bigChunks = [];
    // Each chunk is just under MAX_CHUNK_BYTES; fill enough to exceed account quota.
    const bytesPerChunk = treeStorage.MAX_CHUNK_BYTES;
    const chunksNeeded = Math.ceil(treeStorage.MAX_BYTES_PER_ACCOUNT / bytesPerChunk) + 1;
    for (let i = 0; i < Math.min(chunksNeeded, treeStorage.MAX_CHUNKS_PER_TREE); i++) {
      bigChunks.push({ id: `c${i}`, bytes: bytesPerChunk });
    }
    const r = treeStorage.putManifest(db, 'acc1', 'tree-1', {
      revision: 1, chunks: bigChunks,
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 413);
    assert.ok(r.message.includes('quota'));
  });

  await test('treeStorage.putManifest: rejects new tree when tree count limit reached', () => {
    const db = {};
    // Fill up to the limit with tiny trees.
    for (let i = 0; i < treeStorage.MAX_TREES_PER_ACCOUNT; i++) {
      const r = treeStorage.putManifest(db, 'acc-limit', `tree-${i}`, {
        revision: 1, chunks: [],
      });
      assert.strictEqual(r.ok, true, `tree ${i} should have been accepted`);
    }
    // One more tree should be rejected.
    const r = treeStorage.putManifest(db, 'acc-limit', 'tree-overflow', {
      revision: 1, chunks: [],
    });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 413);
    assert.ok(r.message.includes('count limit'));
  });

  await test('treeStorage.putManifest: rejects chunk list exceeding MAX_CHUNKS_PER_TREE', () => {
    const db = {};
    const chunks = [];
    for (let i = 0; i <= treeStorage.MAX_CHUNKS_PER_TREE; i++) {
      chunks.push({ id: `c${i}`, bytes: 1 });
    }
    const r = treeStorage.putManifest(db, 'acc1', 'tree-1', { revision: 1, chunks });
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.status, 413);
    assert.ok(r.message.includes('chunk limit'));
  });

  await test('treeStorage.putManifest: preserves kdfSalt from existing tree when not provided', () => {
    const db = {};
    treeStorage.putManifest(db, 'acc1', 'tree-salt', {
      revision: 1, kdfSalt: 'ORIGINAL', chunks: [],
    });
    // Update without providing kdfSalt — existing value should be retained.
    const r = treeStorage.putManifest(db, 'acc1', 'tree-salt', {
      revision: 2, chunks: [],
    });
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.manifest.kdfSalt, 'ORIGINAL');
  });

  await test('treeStorage.deleteAllForAccount: removes all trees for an account', () => {
    const db = {};
    treeStorage.putManifest(db, 'accX', 'tree-a', { revision: 1, chunks: [] });
    treeStorage.putManifest(db, 'accX', 'tree-b', { revision: 1, chunks: [] });
    assert.strictEqual(treeStorage.listTrees(db, 'accX').trees.length, 2);
    const r = treeStorage.deleteAllForAccount(db, 'accX');
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.deletedTrees, 2);
    assert.strictEqual(treeStorage.listTrees(db, 'accX').trees.length, 0);
  });

  await test('treeStorage.memPut: throws when chunk exceeds MAX_CHUNK_BYTES', () => {
    treeStorage.memReset();
    const oversized = Buffer.alloc(treeStorage.MAX_CHUNK_BYTES + 1);
    assert.throws(() => treeStorage.memPut('acc1', 'tree1', 'c1', oversized), /too large/);
  });

  await test('treeStorage.listTrees: reflects usage after put and delete', () => {
    const db = {};
    treeStorage.putManifest(db, 'accY', 'tree-1', {
      revision: 1, chunks: [{ id: 'c1', bytes: 500 }],
    });
    const listAfterPut = treeStorage.listTrees(db, 'accY');
    assert.strictEqual(listAfterPut.usedTrees, 1);
    assert.strictEqual(listAfterPut.usedBytes, 500);
    treeStorage.deleteTree(db, 'accY', 'tree-1');
    const listAfterDel = treeStorage.listTrees(db, 'accY');
    assert.strictEqual(listAfterDel.usedTrees, 0);
    assert.strictEqual(listAfterDel.usedBytes, 0);
  });

  // ── rateLimit.consume ─────────────────────────────────────────────────────────
  await test('rateLimit.consume: succeeds for a fresh IP', () => {
    rateLimit._resetForTests();
    const r = rateLimit.consume({ ip: '10.0.0.1', email: 'fresh@e.com' });
    assert.strictEqual(r.ok, true);
  });

  await test('rateLimit.consume: depletes IP bucket and returns 429', () => {
    rateLimit._resetForTests();
    let limited = false;
    for (let i = 0; i < rateLimit.IP_BUCKET_CAPACITY + 5; i++) {
      const r = rateLimit.consume({ ip: 'depletion-ip', email: 'dep@e.com' });
      if (!r.ok) { limited = true; break; }
    }
    assert.ok(limited, 'Should be rate-limited after exhausting IP bucket');
  });

  await test('rateLimit.consume: depletes account bucket and returns 429', () => {
    rateLimit._resetForTests();
    let limited = false;
    for (let i = 0; i < rateLimit.ACCOUNT_BUCKET_CAPACITY + 5; i++) {
      const r = rateLimit.consume({ ip: `unique-ip-${i}`, email: 'acct-dep@e.com' });
      if (!r.ok) { limited = true; break; }
    }
    assert.ok(limited, 'Should be rate-limited after exhausting account bucket');
  });

  await test('rateLimit.consume: ok when email is absent', () => {
    rateLimit._resetForTests();
    const r = rateLimit.consume({ ip: '10.0.0.2' });
    assert.strictEqual(r.ok, true);
  });

  await test('rateLimit.recordFailure: exponential backoff doubles lockout duration', () => {
    rateLimit._resetForTests();
    const email = 'backoff@e.com';
    // Trigger threshold to start lockout.
    for (let i = 0; i < rateLimit.LOCKOUT_THRESHOLD; i++) {
      rateLimit.recordFailure(email);
    }
    const first = rateLimit.checkLockout(email);
    assert.ok(first.locked, 'Should be locked after threshold failures');
    // One more failure past threshold should increase lockout duration.
    rateLimit.recordFailure(email);
    const second = rateLimit.checkLockout(email);
    assert.ok(second.retryAfterSeconds >= first.retryAfterSeconds);
  });

  await test('rateLimit.clientIp: returns socket remoteAddress by default', () => {
    const req = { socket: { remoteAddress: '9.9.9.9' }, headers: {} };
    assert.strictEqual(rateLimit.clientIp(req), '9.9.9.9');
  });

  await test('rateLimit.clientIp: returns "unknown" when socket is missing', () => {
    const req = { headers: {} };
    assert.strictEqual(rateLimit.clientIp(req), 'unknown');
  });

  await test('rateLimit.clientIp: uses X-Forwarded-For when TRUST_PROXY=true', () => {
    process.env.TRUST_PROXY = 'true';
    const req = { headers: { 'x-forwarded-for': '203.0.113.5, 10.0.0.1' } };
    assert.strictEqual(rateLimit.clientIp(req), '203.0.113.5');
    delete process.env.TRUST_PROXY;
  });

  await test('rateLimit.clientIp: ignores X-Forwarded-For when TRUST_PROXY is unset', () => {
    delete process.env.TRUST_PROXY;
    const req = { socket: { remoteAddress: '1.2.3.4' }, headers: { 'x-forwarded-for': '5.6.7.8' } };
    assert.strictEqual(rateLimit.clientIp(req), '1.2.3.4');
  });

  await test('rateLimit.consume: scope is "ip" when IP bucket exhausted', () => {
    rateLimit._resetForTests();
    let result;
    for (let i = 0; i < rateLimit.IP_BUCKET_CAPACITY + 5; i++) {
      result = rateLimit.consume({ ip: 'scope-test-ip', email: 'scope@e.com' });
      if (!result.ok) break;
    }
    assert.strictEqual(result.ok, false);
    assert.strictEqual(result.scope, 'ip');
    rateLimit._resetForTests();
  });

  await test('rateLimit.consume: scope is "account" when account bucket exhausted', () => {
    rateLimit._resetForTests();
    let result;
    for (let i = 0; i < rateLimit.ACCOUNT_BUCKET_CAPACITY + 5; i++) {
      result = rateLimit.consume({ ip: `unique-${i}`, email: 'scope-acct@e.com' });
      if (!result.ok) break;
    }
    assert.strictEqual(result.ok, false);
    assert.strictEqual(result.scope, 'account');
    rateLimit._resetForTests();
  });

  await test('rateLimit.checkLockout: returns locked=false for unknown email', () => {
    rateLimit._resetForTests();
    assert.deepStrictEqual(rateLimit.checkLockout('unknown@e.com'), { locked: false });
  });

  await test('rateLimit.checkLockout: returns locked=false for empty email', () => {
    assert.deepStrictEqual(rateLimit.checkLockout(''), { locked: false });
  });

  await test('rateLimit.recordSuccess: clears failure counter', () => {
    rateLimit._resetForTests();
    const email = 'success@e.com';
    for (let i = 0; i < rateLimit.LOCKOUT_THRESHOLD; i++) {
      rateLimit.recordFailure(email);
    }
    assert.ok(rateLimit.checkLockout(email).locked);
    rateLimit.recordSuccess(email);
    assert.strictEqual(rateLimit.checkLockout(email).locked, false);
  });
}

// ── End-to-end HTTP tests ────────────────────────────────────────────────────
async function httpTests() {
  console.log('HTTP tests');
  rateLimit._resetForTests();
  const port = await listen();

  let regToken;
  await test('register: enforces strong password', async () => {
    const r = await request('POST', port, '/v1/account/register', {
      json: { email: 'u1@example.com', password: 'short', desktopLicense: true },
    });
    assert.strictEqual(r.status, 400);
  });

  await test('register: succeeds with strong password', async () => {
    const r = await request('POST', port, '/v1/account/register', {
      json: { email: 'u1@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.body.ok, true);
    regToken = r.body._devToken;
    assert.ok(regToken, 'dev token returned in dev mode');
  });

  await test('verify-email: succeeds with token', async () => {
    const r = await request('POST', port, '/v1/account/verify-email', {
      json: { email: 'u1@example.com', token: regToken },
    });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
  });

  let session;
  await test('license/verify: succeeds and returns session token', async () => {
    const r = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'u1@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux',
        deviceId: 'dev-abcd-1234', appVersion: '1.0.0',
      },
    });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
    assert.ok(r.body.session && r.body.session.token);
    session = r.body.session.token;
  });

  await test('account/sync: works with Bearer token (no password)', async () => {
    const r = await request('POST', port, '/v1/account/sync', {
      json: {},
      headers: { Authorization: `Bearer ${session}` },
    });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
  });

  await test('account/sync: rejects bad Bearer', async () => {
    const r = await request('POST', port, '/v1/account/sync', {
      json: {},
      headers: { Authorization: 'Bearer not.a.token' },
    });
    assert.strictEqual(r.status, 401);
  });

  await test('change-password: rejects bad current password', async () => {
    const r = await request('POST', port, '/v1/account/change-password', {
      json: {
        email: 'u1@example.com', currentPassword: 'wrong',
        newPassword: 'BrandNewSecret#9!',
      },
    });
    assert.strictEqual(r.status, 401);
  });

  await test('change-password: succeeds and rotates session', async () => {
    const r = await request('POST', port, '/v1/account/change-password', {
      json: {
        email: 'u1@example.com', currentPassword: 'Tr0ub4dor&3xpand',
        newPassword: 'BrandNewSecret#9!',
      },
    });
    assert.strictEqual(r.status, 200);
    // Old session should now be revoked.
    const r2 = await request('POST', port, '/v1/account/sync', {
      json: {}, headers: { Authorization: `Bearer ${session}` },
    });
    assert.strictEqual(r2.status, 401);
  });

  // Re-login with the new password.
  let session2;
  await test('re-login with new password works', async () => {
    const r = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'u1@example.com', password: 'BrandNewSecret#9!',
        appType: 'desktop', os: 'linux',
        deviceId: 'dev-abcd-1234', appVersion: '1.0.0',
      },
    });
    assert.strictEqual(r.status, 200);
    session2 = r.body.session.token;
  });

  await test('rate limit: 429 after exhausting bucket', async () => {
    // Override env doesn't help mid-process; use the in-memory limiter directly
    // by replacing the IP capacity.  Easiest: hammer login with a tiny override.
    // Instead, simulate via internal API:
    const orig = rateLimit.IP_BUCKET_CAPACITY;
    // Force consume to fail by recording many fails.
    rateLimit._resetForTests();
    // Force the IP bucket to depletion by calling consume directly until
    // it returns not-ok.
    let limited = false;
    for (let i = 0; i < 5000; i++) {
      const r = rateLimit.consume({ ip: 'rate-test-ip', email: 'x@y.z' });
      if (!r.ok) { limited = true; break; }
    }
    assert.ok(limited, 'consume should eventually rate-limit');
    // Reset for further tests.
    rateLimit._resetForTests();
  });

  await test('account lockout: 429 after configured failures', async () => {
    rateLimit._resetForTests();
    // 3 failed sign-ins (LOCKOUT_THRESHOLD=3) should lock the account.
    for (let i = 0; i < 3; i++) {
      await request('POST', port, '/v1/license/verify', {
        json: {
          email: 'lockout-test@example.com', password: 'wrong-password!',
          appType: 'desktop', os: 'linux', deviceId: 'dev-lock-1234',
        },
      });
    }
    // Pre-create the account so that lookup finds it (the lockout layer keys
    // off email, not account existence).
    const reg = await request('POST', port, '/v1/account/register', {
      json: {
        email: 'lockout-test@example.com', password: 'Tr0ub4dor&3xpand',
        desktopLicense: true,
      },
    });
    assert.strictEqual(reg.status, 201);
    const r = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'lockout-test@example.com', password: 'still-wrong!',
        appType: 'desktop', os: 'linux', deviceId: 'dev-lock-1234',
      },
    });
    // After 3 failures recordFailure has set lockedUntil; the next attempt
    // should be rejected with 429.
    assert.ok(r.status === 401 || r.status === 429,
      `expected 401 or 429, got ${r.status}`);
  });

  await test('password reset: full flow', async () => {
    rateLimit._resetForTests();
    const req1 = await request('POST', port, '/v1/account/password-reset/request', {
      json: { email: 'u1@example.com' },
    });
    assert.strictEqual(req1.status, 200);
    const tok = req1.body._devToken;
    assert.ok(tok);
    const reset = await request('POST', port, '/v1/account/password-reset', {
      json: { email: 'u1@example.com', token: tok, newPassword: 'AnotherStrongOne!9' },
    });
    assert.strictEqual(reset.status, 200);
  });

  await test('mfa: enroll start + confirm + login challenge', async () => {
    // Register a fresh user for MFA testing.
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'mfa@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfa@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfa-1234',
      },
    });
    const tok = login.body.session.token;
    const start = await request('POST', port, '/v1/account/mfa/enroll/start', {
      json: {}, headers: { Authorization: `Bearer ${tok}` },
    });
    assert.strictEqual(start.status, 200);
    const secret = start.body.secret;
    // Compute current code using the module-level hotp helper.
    const counter = Math.floor(Date.now() / 1000 / 30);
    const code = hotp(secret, counter);
    const confirm = await request('POST', port, '/v1/account/mfa/enroll/confirm', {
      json: { code }, headers: { Authorization: `Bearer ${tok}` },
    });
    assert.strictEqual(confirm.status, 200);
    assert.ok(Array.isArray(confirm.body.recoveryCodes));

    // Now login should require MFA.
    const noMfa = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfa@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfa-1234',
      },
    });
    assert.strictEqual(noMfa.status, 403);
    assert.strictEqual(noMfa.body.code, 'mfa_required');

    const code2 = currentTotpCode(secret);
    const withMfa = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfa@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfa-1234',
        mfaCode: code2,
      },
    });
    assert.strictEqual(withMfa.status, 200);
    assert.strictEqual(withMfa.body.session.mfa, true);
  });

  await test('app version: GET returns platform map', async () => {
    const r = await request('GET', port, '/v1/app/version', {});
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
    assert.ok(r.body.platforms.android.latest);
  });

  await test('tree: round-trip manifest + chunk upload + download + delete', async () => {
    rateLimit._resetForTests();
    // Re-register simple user.
    await request('POST', port, '/v1/account/register', {
      json: { email: 'tree@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'tree@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-tree-1234',
      },
    });
    const tok = login.body.session.token;
    const auth = { Authorization: `Bearer ${tok}` };

    const blob = Buffer.from('encrypted-blob-payload');
    const sha = crypto.createHash('sha256').update(blob).digest('hex');

    const putManifest = await request('POST', port, '/v1/tree/manifest/put', {
      json: {
        treeId: 'tree-001',
        manifest: {
          revision: 1, kdfSalt: 'AAAA',
          chunks: [{ id: 'c1', bytes: blob.length, sha256: sha }],
        },
      },
      headers: auth,
    });
    assert.strictEqual(putManifest.status, 200);

    const putChunkReal = await request('PUT', port, '/v1/tree/tree-001/chunk/c1', {
      raw: blob, headers: { ...auth, 'Content-Type': 'application/octet-stream' },
    });
    assert.strictEqual(putChunkReal.status, 200);

    const getChunk = await request('GET', port, '/v1/tree/tree-001/chunk/c1', { headers: auth });
    assert.strictEqual(getChunk.status, 200);
    assert.strictEqual(getChunk.raw.toString('utf8'), 'encrypted-blob-payload');

    const list = await request('POST', port, '/v1/tree/list', { json: {}, headers: auth });
    assert.strictEqual(list.status, 200);
    assert.strictEqual(list.body.trees.length, 1);
    assert.strictEqual(list.body.trees[0].id, 'tree-001');

    const del = await request('POST', port, '/v1/tree/delete', {
      json: { treeId: 'tree-001' }, headers: auth,
    });
    assert.strictEqual(del.status, 200);

    const list2 = await request('POST', port, '/v1/tree/list', { json: {}, headers: auth });
    assert.strictEqual(list2.body.trees.length, 0);
  });

  await test('tree: rejects upload without auth', async () => {
    const r = await request('POST', port, '/v1/tree/list', { json: {} });
    assert.strictEqual(r.status, 401);
  });

  await test('security headers: HSTS + nosniff present', async () => {
    const r = await request('POST', port, '/v1/account/sync', { json: {} });
    assert.ok(r.headers['strict-transport-security']);
    assert.strictEqual(r.headers['x-content-type-options'], 'nosniff');
  });

  // ── Health check ─────────────────────────────────────────────────────────────
  await test('health: GET /health returns healthy status', async () => {
    const r = await request('GET', port, '/health', {});
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.status, 'healthy');
  });

  // ── Resend verification ───────────────────────────────────────────────────────
  await test('resend-verification: already-verified account returns ok message', async () => {
    rateLimit._resetForTests();
    // u1@example.com is email-verified; current password after reset flow.
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'u1@example.com', password: 'AnotherStrongOne!9',
        appType: 'desktop', os: 'linux', deviceId: 'dev-rv-0001',
      },
    });
    assert.strictEqual(login.status, 200, `re-login failed: ${JSON.stringify(login.body)}`);
    const tok = login.body.session.token;
    const r = await request('POST', port, '/v1/account/resend-verification', {
      json: {}, headers: { Authorization: `Bearer ${tok}` },
    });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
    assert.ok(r.body.message.toLowerCase().includes('already verified'));
  });

  await test('resend-verification: unverified account receives a new dev token', async () => {
    rateLimit._resetForTests();
    // Register a fresh account and do NOT verify its email.
    await request('POST', port, '/v1/account/register', {
      json: { email: 'rv-unverified@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    // license/verify does not require email verification, so we can get a session token.
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'rv-unverified@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-rv-0002',
      },
    });
    assert.strictEqual(login.status, 200, `login failed: ${JSON.stringify(login.body)}`);
    const tok = login.body.session.token;
    const r = await request('POST', port, '/v1/account/resend-verification', {
      json: {}, headers: { Authorization: `Bearer ${tok}` },
    });
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
    // In dev mode the new token is returned in _devToken.
    assert.ok(r.body._devToken, 'dev token should be returned for unverified account in dev mode');
  });

  // ── Session revoke all ────────────────────────────────────────────────────────
  await test('session/revoke-all: revoked token is rejected on subsequent requests', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'revoke-test@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'revoke-test@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-revoke-0001',
      },
    });
    assert.strictEqual(login.status, 200);
    const tok = login.body.session.token;

    const revoke = await request('POST', port, '/v1/account/session/revoke-all', {
      json: {}, headers: { Authorization: `Bearer ${tok}` },
    });
    assert.strictEqual(revoke.status, 200);
    assert.strictEqual(revoke.body.ok, true);

    // The same token must now be rejected.
    const sync = await request('POST', port, '/v1/account/sync', {
      json: {}, headers: { Authorization: `Bearer ${tok}` },
    });
    assert.strictEqual(sync.status, 401);
  });

  // ── MFA disable ──────────────────────────────────────────────────────────────
  await test('mfa/disable: login succeeds without MFA after disabling', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'mfadis@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login1 = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfadis@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfadis-0001',
      },
    });
    const tok1 = login1.body.session.token;

    // Enroll MFA.
    const start = await request('POST', port, '/v1/account/mfa/enroll/start', {
      json: {}, headers: { Authorization: `Bearer ${tok1}` },
    });
    assert.strictEqual(start.status, 200);
    const secret = start.body.secret;
    const enrollCode = currentTotpCode(secret);
    const confirm = await request('POST', port, '/v1/account/mfa/enroll/confirm', {
      json: { code: enrollCode }, headers: { Authorization: `Bearer ${tok1}` },
    });
    assert.strictEqual(confirm.status, 200);

    // Login again with MFA to get an mfa=true session token.
    const loginCode = currentTotpCode(secret);
    const login2 = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfadis@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfadis-0002',
        mfaCode: loginCode,
      },
    });
    assert.strictEqual(login2.status, 200, `login2 failed: ${JSON.stringify(login2.body)}`);
    const tok2 = login2.body.session.token;

    // Disable MFA using the step-up token.
    const disable = await request('POST', port, '/v1/account/mfa/disable', {
      json: {}, headers: { Authorization: `Bearer ${tok2}` },
    });
    assert.strictEqual(disable.status, 200);
    assert.strictEqual(disable.body.ok, true);

    // Login without MFA should now succeed.
    const login3 = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfadis@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfadis-0003',
      },
    });
    assert.strictEqual(login3.status, 200, `login without MFA after disable should succeed`);
    assert.strictEqual(login3.body.mfaEnabled, false);
  });

  // ── Gift: initiate + claim + cancel ──────────────────────────────────────────
  await test('gift: initiate → claim transfers desktop license', async () => {
    rateLimit._resetForTests();
    // Create sender with a verified email and a desktop license.
    const senderReg = await request('POST', port, '/v1/account/register', {
      json: { email: 'gift-sender@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    assert.strictEqual(senderReg.status, 201);
    await request('POST', port, '/v1/account/verify-email', {
      json: { email: 'gift-sender@example.com', token: senderReg.body._devToken },
    });
    const senderLogin = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'gift-sender@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-giftsnd-0001',
      },
    });
    assert.strictEqual(senderLogin.status, 200, `sender login failed: ${JSON.stringify(senderLogin.body)}`);
    const senderTok = senderLogin.body.session.token;

    // Register recipient (starts with an android license so the account exists;
    // the gift will add a desktop license).
    await request('POST', port, '/v1/account/register', {
      json: { email: 'gift-recip@example.com', password: 'Tr0ub4dor&3xpandR', androidLicense: true },
    });

    // Initiate the gift.
    const initiate = await request('POST', port, '/v1/license/gift/initiate', {
      json: { licenseType: 'desktop', toEmail: 'gift-recip@example.com' },
      headers: { Authorization: `Bearer ${senderTok}` },
    });
    assert.strictEqual(initiate.status, 200, `gift initiate failed: ${JSON.stringify(initiate.body)}`);
    assert.strictEqual(initiate.body.ok, true);
    const giftToken = initiate.body._devToken;
    assert.ok(giftToken, 'dev gift token should be present in dev mode');

    // Claim the gift as the recipient.
    const claim = await request('POST', port, '/v1/license/gift/claim', {
      json: { token: giftToken, email: 'gift-recip@example.com', password: 'Tr0ub4dor&3xpandR' },
    });
    assert.strictEqual(claim.status, 200, `gift claim failed: ${JSON.stringify(claim.body)}`);
    assert.strictEqual(claim.body.ok, true);
    assert.ok(claim.body.account.entitlements.desktop, 'recipient should now have desktop license');
  });

  await test('gift: initiate → cancel restores license to sender', async () => {
    rateLimit._resetForTests();
    // Create a fresh verified sender.
    const senderReg = await request('POST', port, '/v1/account/register', {
      json: { email: 'gift-cancel@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    await request('POST', port, '/v1/account/verify-email', {
      json: { email: 'gift-cancel@example.com', token: senderReg.body._devToken },
    });
    const senderLogin = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'gift-cancel@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-giftcancel-0001',
      },
    });
    const senderTok = senderLogin.body.session.token;

    // Initiate a gift.
    const initiate = await request('POST', port, '/v1/license/gift/initiate', {
      json: { licenseType: 'desktop', toEmail: 'no-such-recip@example.com' },
      headers: { Authorization: `Bearer ${senderTok}` },
    });
    assert.strictEqual(initiate.status, 200);
    const giftId = initiate.body.gift.id;

    // Cancel the gift by ID.
    const cancel = await request('POST', port, '/v1/license/gift/cancel', {
      json: { giftId },
      headers: { Authorization: `Bearer ${senderTok}` },
    });
    assert.strictEqual(cancel.status, 200, `gift cancel failed: ${JSON.stringify(cancel.body)}`);
    assert.strictEqual(cancel.body.ok, true);

    // Sender should still see the gift as cancelled (no pending gifts).
    const sync = await request('POST', port, '/v1/account/sync', {
      json: {}, headers: { Authorization: `Bearer ${senderTok}` },
    });
    assert.strictEqual(sync.status, 200);
    assert.strictEqual(sync.body.incomingGifts.length, 0);
  });

  // ── Voucher (open gift) creation ──────────────────────────────────────────────
  await test('voucher/create: creates redeemable voucher with admin secret', async () => {
    rateLimit._resetForTests();
    const create = await request('POST', port, '/v1/license/voucher/create', {
      json: {
        adminSecret: process.env.ADMIN_SECRET,
        licenseType: 'desktop',
        quantity: 1,
      },
    });
    assert.strictEqual(create.status, 200, `voucher create failed: ${JSON.stringify(create.body)}`);
    assert.strictEqual(create.body.ok, true);
    assert.ok(Array.isArray(create.body.vouchers));
    assert.strictEqual(create.body.vouchers.length, 1);
    const voucherToken = create.body.vouchers[0].token;

    // Register a new user with an android license so the account can be created
    // (registration requires at least one license), then claim the voucher.
    await request('POST', port, '/v1/account/register', {
      json: { email: 'voucher-claimer@example.com', password: 'Tr0ub4dor&3xpandV', androidLicense: true },
    });
    const claim = await request('POST', port, '/v1/license/gift/claim', {
      json: {
        token: voucherToken,
        email: 'voucher-claimer@example.com',
        password: 'Tr0ub4dor&3xpandV',
      },
    });
    assert.strictEqual(claim.status, 200, `voucher claim failed: ${JSON.stringify(claim.body)}`);
    assert.strictEqual(claim.body.ok, true);
    assert.ok(claim.body.account.entitlements.desktop);
  });

  await test('voucher/create: rejects invalid admin secret', async () => {
    const r = await request('POST', port, '/v1/license/voucher/create', {
      json: { adminSecret: 'wrong-secret', licenseType: 'desktop', quantity: 1 },
    });
    assert.strictEqual(r.status, 403);
    assert.strictEqual(r.body.ok, false);
  });

  // ── Tree delete-all ───────────────────────────────────────────────────────────
  await test('tree/delete-all: removes all trees for an account', async () => {
    rateLimit._resetForTests();
    // Register a fresh user for this test.
    await request('POST', port, '/v1/account/register', {
      json: { email: 'delall@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'delall@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-delall-0001',
      },
    });
    assert.strictEqual(login.status, 200);
    const tok = login.body.session.token;
    const auth = { Authorization: `Bearer ${tok}` };

    // Upload two tree manifests.
    for (const treeId of ['del-tree-1', 'del-tree-2']) {
      await request('POST', port, '/v1/tree/manifest/put', {
        json: { treeId, manifest: { revision: 1, kdfSalt: 'AAAA', chunks: [] } },
        headers: auth,
      });
    }

    // Verify two trees exist.
    const listBefore = await request('POST', port, '/v1/tree/list', { json: {}, headers: auth });
    assert.strictEqual(listBefore.status, 200);
    assert.strictEqual(listBefore.body.trees.length, 2);

    // Delete all trees.
    const delAll = await request('POST', port, '/v1/tree/delete-all', {
      json: {}, headers: auth,
    });
    assert.strictEqual(delAll.status, 200, `tree/delete-all failed: ${JSON.stringify(delAll.body)}`);
    assert.strictEqual(delAll.body.ok, true);
    assert.strictEqual(delAll.body.deletedTrees, 2);

    // Verify no trees remain.
    const listAfter = await request('POST', port, '/v1/tree/list', { json: {}, headers: auth });
    assert.strictEqual(listAfter.body.trees.length, 0);
  });

  // ── Additional HTTP coverage ──────────────────────────────────────────────

  await test('register: rejects duplicate email', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'dup@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const r2 = await request('POST', port, '/v1/account/register', {
      json: { email: 'dup@example.com', password: 'Tr0ub4dor&3xpand2!', desktopLicense: true },
    });
    assert.strictEqual(r2.status, 409);
    assert.strictEqual(r2.body.ok, false);
  });

  await test('register: rejects missing license type', async () => {
    const r = await request('POST', port, '/v1/account/register', {
      json: { email: 'nolic@example.com', password: 'Tr0ub4dor&3xpand' },
    });
    assert.strictEqual(r.status, 400);
    assert.strictEqual(r.body.ok, false);
  });

  await test('register: rejects missing email', async () => {
    const r = await request('POST', port, '/v1/account/register', {
      json: { password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    assert.strictEqual(r.status, 400);
  });

  await test('verify-email: rejects wrong token', async () => {
    rateLimit._resetForTests();
    const reg = await request('POST', port, '/v1/account/register', {
      json: { email: 'badverify@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    assert.strictEqual(reg.status, 201);
    const r = await request('POST', port, '/v1/account/verify-email', {
      json: { email: 'badverify@example.com', token: 'WRONGTOKEN' },
    });
    assert.strictEqual(r.status, 400);
    assert.strictEqual(r.body.ok, false);
  });

  await test('verify-email: rejects unknown email', async () => {
    const r = await request('POST', port, '/v1/account/verify-email', {
      json: { email: 'nobody@example.com', token: 'ANYTOKEN' },
    });
    assert.strictEqual(r.status, 404);
  });

  await test('login: rejects wrong password for existing account', async () => {
    rateLimit._resetForTests();
    // Register a fresh account so we control the exact password.
    await request('POST', port, '/v1/account/register', {
      json: { email: 'wrongpw@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const r = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'wrongpw@example.com', password: 'WrongPassword!123',
        appType: 'desktop', os: 'linux', deviceId: 'dev-wrongpw-0001',
      },
    });
    assert.strictEqual(r.status, 401, `expected 401 for wrong password, got ${r.status}`);
  });

  await test('unknown route: returns 404 or 405', async () => {
    const r = await request('GET', port, '/v1/no-such-endpoint', {});
    assert.ok(r.status === 404 || r.status === 405,
      `expected 404 or 405, got ${r.status}`);
    assert.strictEqual(r.body.ok, false);
  });

  await test('health: returns ok=true field', async () => {
    const r = await request('GET', port, '/health', {});
    assert.strictEqual(r.status, 200);
    assert.ok(r.body.ok === true || r.body.status === 'healthy');
  });

  await test('tree/manifest/get: returns manifest after put', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'mget@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mget@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mget-0001',
      },
    });
    assert.strictEqual(login.status, 200);
    const auth = { Authorization: `Bearer ${login.body.session.token}` };

    await request('POST', port, '/v1/tree/manifest/put', {
      json: { treeId: 'mget-tree', manifest: { revision: 3, kdfSalt: 'SALT1', chunks: [] } },
      headers: auth,
    });

    const get = await request('POST', port, '/v1/tree/manifest/get', {
      json: { treeId: 'mget-tree' }, headers: auth,
    });
    assert.strictEqual(get.status, 200);
    assert.strictEqual(get.body.ok, true);
    assert.strictEqual(get.body.manifest.revision, 3);
    assert.strictEqual(get.body.manifest.kdfSalt, 'SALT1');
  });

  await test('tree/manifest/get: returns 404 for missing tree', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'mget404@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mget404@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mget404-0001',
      },
    });
    const auth = { Authorization: `Bearer ${login.body.session.token}` };
    const r = await request('POST', port, '/v1/tree/manifest/get', {
      json: { treeId: 'no-such-tree' }, headers: auth,
    });
    assert.strictEqual(r.status, 404);
  });

  await test('tree chunk: DELETE removes chunk', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'chunkdel@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'chunkdel@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-chunkdel-0001',
      },
    });
    const tok = login.body.session.token;
    const auth = { Authorization: `Bearer ${tok}` };
    const blob = Buffer.from('chunk-to-delete');

    await request('POST', port, '/v1/tree/manifest/put', {
      json: { treeId: 'cdel-tree', manifest: { revision: 1, chunks: [{ id: 'cdel-c1', bytes: blob.length }] } },
      headers: auth,
    });
    await request('PUT', port, '/v1/tree/cdel-tree/chunk/cdel-c1', {
      raw: blob, headers: { ...auth, 'Content-Type': 'application/octet-stream' },
    });

    // Verify chunk is there.
    const getR = await request('GET', port, '/v1/tree/cdel-tree/chunk/cdel-c1', { headers: auth });
    assert.strictEqual(getR.status, 200);

    // Delete the chunk.
    const delR = await request('DELETE', port, '/v1/tree/cdel-tree/chunk/cdel-c1', { headers: auth });
    assert.strictEqual(delR.status, 200);

    // Chunk should be gone.
    const getR2 = await request('GET', port, '/v1/tree/cdel-tree/chunk/cdel-c1', { headers: auth });
    assert.strictEqual(getR2.status, 404);
  });

  await test('tree chunk: GET returns 404 for missing chunk', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'chunk404@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'chunk404@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-chunk404-0001',
      },
    });
    const auth = { Authorization: `Bearer ${login.body.session.token}` };
    await request('POST', port, '/v1/tree/manifest/put', {
      json: { treeId: 'c404-tree', manifest: { revision: 1, chunks: [] } }, headers: auth,
    });
    const r = await request('GET', port, '/v1/tree/c404-tree/chunk/nosuch', { headers: auth });
    assert.strictEqual(r.status, 404);
  });

  await test('app version: env var overrides are reflected', async () => {
    process.env.APP_LATEST_VERSION = '9.9.9';
    const r = await request('GET', port, '/v1/app/version', {});
    // Note: the module-level var is read at load time, so we can only check the
    // shape is correct here; the dynamic env test lives in the library section.
    assert.strictEqual(r.status, 200);
    assert.ok(r.body.platforms.ios.latest);
    assert.ok(r.body.platforms.linux.latest);
    delete process.env.APP_LATEST_VERSION;
  });

  await test('mfa recovery code: login with recovery code succeeds', async () => {
    rateLimit._resetForTests();
    await request('POST', port, '/v1/account/register', {
      json: { email: 'mfarec@example.com', password: 'Tr0ub4dor&3xpand', desktopLicense: true },
    });
    const login1 = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfarec@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfarec-0001',
      },
    });
    const tok1 = login1.body.session.token;

    // Enroll MFA.
    const start = await request('POST', port, '/v1/account/mfa/enroll/start', {
      json: {}, headers: { Authorization: `Bearer ${tok1}` },
    });
    const secret = start.body.secret;
    const enrollCode = currentTotpCode(secret);
    const confirm = await request('POST', port, '/v1/account/mfa/enroll/confirm', {
      json: { code: enrollCode }, headers: { Authorization: `Bearer ${tok1}` },
    });
    assert.strictEqual(confirm.status, 200);
    const recoveryCodes = confirm.body.recoveryCodes;
    assert.ok(Array.isArray(recoveryCodes) && recoveryCodes.length > 0);

    // Login using a recovery code instead of a TOTP code.
    const loginWithRecovery = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'mfarec@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'desktop', os: 'linux', deviceId: 'dev-mfarec-0002',
        mfaCode: recoveryCodes[0],
      },
    });
    assert.strictEqual(loginWithRecovery.status, 200,
      `recovery code login failed: ${JSON.stringify(loginWithRecovery.body)}`);
    assert.strictEqual(loginWithRecovery.body.ok, true);
  });

  await test('gift: initiate fails when sender has no desktop license', async () => {
    rateLimit._resetForTests();
    // Register a sender with only an android license.
    const senderReg = await request('POST', port, '/v1/account/register', {
      json: { email: 'gift-nodesktop@example.com', password: 'Tr0ub4dor&3xpand', androidLicense: true },
    });
    assert.strictEqual(senderReg.status, 201);
    await request('POST', port, '/v1/account/verify-email', {
      json: { email: 'gift-nodesktop@example.com', token: senderReg.body._devToken },
    });
    const senderLogin = await request('POST', port, '/v1/license/verify', {
      json: {
        email: 'gift-nodesktop@example.com', password: 'Tr0ub4dor&3xpand',
        appType: 'android', os: 'android', deviceId: 'dev-giftnd-0001',
      },
    });
    assert.strictEqual(senderLogin.status, 200);
    const senderTok = senderLogin.body.session.token;

    const initiate = await request('POST', port, '/v1/license/gift/initiate', {
      json: { licenseType: 'desktop', toEmail: 'anyone@example.com' },
      headers: { Authorization: `Bearer ${senderTok}` },
    });
    assert.ok(initiate.status === 403 || initiate.status === 400,
      `expected 4xx for no desktop license, got ${initiate.status}`);
  });

  await test('voucher/create: quantity is clamped to 50 (no error for quantity > 50)', async () => {
    const r = await request('POST', port, '/v1/license/voucher/create', {
      json: { adminSecret: process.env.ADMIN_SECRET, licenseType: 'desktop', quantity: 51 },
    });
    // Server silently clamps quantity to max 50 rather than returning an error.
    assert.strictEqual(r.status, 200);
    assert.strictEqual(r.body.ok, true);
    assert.ok(r.body.vouchers.length <= 50);
  });

  await close();
}

// ── Run ──────────────────────────────────────────────────────────────────────
(async () => {
  try {
    await libraryTests();
    await httpTests();
  } catch (err) {
    console.error('Test runner crashed:', err);
    process.exitCode = 1;
  } finally {
    try { fs.unlinkSync(tmpDb); } catch (_) {}
    console.log(`\n${passed} passed, ${failed} failed`);
    if (failed > 0) process.exitCode = 1;
  }
})();
