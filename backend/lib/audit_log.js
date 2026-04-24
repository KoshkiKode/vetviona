'use strict';

// Auth audit log.  Lives next to the license database (S3 in prod, local
// file in dev).  Append-only, capped at the last N entries to keep the
// object small.
//
// Each entry: { ts, ip, email, event, ok, detail }
//   event ∈ {
//     'register', 'login', 'login.token', 'login.mfa',
//     'mfa.enroll', 'mfa.verify',
//     'password.change', 'password.reset.request', 'password.reset',
//     'gift.initiate', 'gift.claim', 'gift.cancel',
//     'session.revoke_all',
//     'rate_limit', 'lockout',
//     'tree.upload', 'tree.download', 'tree.delete',
//   }

const MAX_ENTRIES = Number(process.env.AUDIT_LOG_MAX_ENTRIES || 5_000);

function _list(db) {
  if (!db.auditLog || !Array.isArray(db.auditLog)) {
    db.auditLog = [];
  }
  return db.auditLog;
}

function append(db, entry) {
  const list = _list(db);
  list.push({
    ts: new Date().toISOString(),
    ip: entry.ip || null,
    email: entry.email || null,
    event: String(entry.event || 'unknown'),
    ok: entry.ok !== false,
    detail: entry.detail || null,
  });
  while (list.length > MAX_ENTRIES) list.shift();
}

module.exports = { append, MAX_ENTRIES };
