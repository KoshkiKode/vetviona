'use strict';

// Phase 3 — opt-in encrypted cloud tree backup & sync.
//
// IMPORTANT: the server only ever sees ciphertext.  The Flutter client
// derives a key from the user's password (PBKDF2-SHA256) and AES-256-GCM
// encrypts each tree chunk before upload; the server has no way to read
// trees and cannot decrypt them even with full database access.
//
// Storage layout (when AWS_S3_BUCKET is set):
//
//   s3://<bucket>/<prefix>/users/<accountId>/trees/<treeId>/manifest.json
//   s3://<bucket>/<prefix>/users/<accountId>/trees/<treeId>/chunks/<chunkId>.bin
//
// Each manifest is small JSON tracking revision, chunk list, ciphertext
// byte counts, and a salt for password-key derivation.  Manifests are also
// mirrored into the license database so we can enforce quotas without an
// extra S3 round-trip on every list/quota check.

const crypto = require('crypto');

// Cost guardrails — operators tune these via env vars.
const MAX_BYTES_PER_ACCOUNT =
  Number(process.env.TREE_MAX_BYTES_PER_ACCOUNT || 50 * 1024 * 1024); // 50 MiB
const MAX_TREES_PER_ACCOUNT = Number(process.env.TREE_MAX_PER_ACCOUNT || 25);
const MAX_CHUNKS_PER_TREE = Number(process.env.TREE_MAX_CHUNKS_PER_TREE || 1024);
const MAX_CHUNK_BYTES = Number(process.env.TREE_MAX_CHUNK_BYTES || 2 * 1024 * 1024); // 2 MiB

const PREFIX = process.env.AWS_S3_TREE_PREFIX || 'vetviona-trees';

// In-memory fallback used when S3 is not configured (development only).
const _memStore = new Map(); // key = `${accountId}/${treeId}/${chunkId}` => Buffer

function _accountTrees(db, accountId) {
  if (!db.userTrees || typeof db.userTrees !== 'object') db.userTrees = {};
  if (!db.userTrees[accountId] || typeof db.userTrees[accountId] !== 'object') {
    db.userTrees[accountId] = {};
  }
  return db.userTrees[accountId];
}

function _accountUsage(trees) {
  let bytes = 0;
  let count = 0;
  for (const t of Object.values(trees)) {
    if (!t) continue;
    bytes += Number(t.bytes || 0);
    count += 1;
  }
  return { bytes, count };
}

function _validId(id, label) {
  if (typeof id !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(id)) {
    return `${label} must be 1-64 chars, alphanumeric / dash / underscore.`;
  }
  return null;
}

function listTrees(db, accountId) {
  const trees = _accountTrees(db, accountId);
  const usage = _accountUsage(trees);
  return {
    quotaBytes: MAX_BYTES_PER_ACCOUNT,
    usedBytes: usage.bytes,
    quotaTrees: MAX_TREES_PER_ACCOUNT,
    usedTrees: usage.count,
    trees: Object.entries(trees).map(([id, t]) => ({
      id,
      revision: t.revision || 0,
      updatedAt: t.updatedAt || null,
      bytes: t.bytes || 0,
      chunks: (t.chunks || []).length,
      kdfSalt: t.kdfSalt || null,
    })),
  };
}

function getManifest(db, accountId, treeId) {
  const idErr = _validId(treeId, 'treeId');
  if (idErr) return { ok: false, status: 400, message: idErr };
  const trees = _accountTrees(db, accountId);
  const t = trees[treeId];
  if (!t) return { ok: false, status: 404, message: 'Tree not found in cloud.' };
  return {
    ok: true,
    manifest: {
      id: treeId,
      revision: t.revision || 0,
      updatedAt: t.updatedAt || null,
      bytes: t.bytes || 0,
      kdfSalt: t.kdfSalt || null,
      chunks: t.chunks || [],
    },
  };
}

function putManifest(db, accountId, treeId, manifest) {
  const idErr = _validId(treeId, 'treeId');
  if (idErr) return { ok: false, status: 400, message: idErr };
  if (!manifest || typeof manifest !== 'object') {
    return { ok: false, status: 400, message: 'manifest object required.' };
  }
  const chunks = Array.isArray(manifest.chunks) ? manifest.chunks : [];
  if (chunks.length > MAX_CHUNKS_PER_TREE) {
    return {
      ok: false, status: 413,
      message: `Manifest exceeds chunk limit (${MAX_CHUNKS_PER_TREE}).`,
    };
  }
  for (const c of chunks) {
    if (!c || typeof c !== 'object') {
      return { ok: false, status: 400, message: 'chunk entries must be objects.' };
    }
    const ce = _validId(c.id, 'chunk.id');
    if (ce) return { ok: false, status: 400, message: ce };
    if (typeof c.bytes !== 'number' || c.bytes < 0 || c.bytes > MAX_CHUNK_BYTES) {
      return {
        ok: false, status: 400,
        message: `chunk.bytes must be 0..${MAX_CHUNK_BYTES}.`,
      };
    }
  }
  const totalBytes = chunks.reduce((acc, c) => acc + Number(c.bytes || 0), 0);
  const trees = _accountTrees(db, accountId);
  const existing = trees[treeId];
  // Quota check: project this manifest as the new state of this tree.
  const usage = _accountUsage(trees);
  const projected =
    usage.bytes - Number(existing?.bytes || 0) + totalBytes;
  if (projected > MAX_BYTES_PER_ACCOUNT) {
    return {
      ok: false, status: 413,
      message:
        `Cloud storage quota exceeded (${MAX_BYTES_PER_ACCOUNT} bytes per account). ` +
        `Delete an old tree or shrink this one.`,
    };
  }
  if (!existing && usage.count >= MAX_TREES_PER_ACCOUNT) {
    return {
      ok: false, status: 413,
      message: `Cloud tree count limit reached (${MAX_TREES_PER_ACCOUNT}).`,
    };
  }
  const kdfSalt = manifest.kdfSalt
    ? String(manifest.kdfSalt).slice(0, 256)
    : (existing && existing.kdfSalt) || null;
  const next = {
    revision: Number(manifest.revision || 0),
    updatedAt: new Date().toISOString(),
    bytes: totalBytes,
    kdfSalt,
    chunks: chunks.map((c) => ({
      id: String(c.id),
      bytes: Number(c.bytes),
      sha256: c.sha256 ? String(c.sha256).slice(0, 128) : null,
    })),
  };
  if (existing && Number(existing.revision || 0) > next.revision) {
    return {
      ok: false, status: 409,
      message:
        `Server has a newer revision (${existing.revision}). Pull and merge first.`,
      manifest: { ...existing, id: treeId },
    };
  }
  trees[treeId] = next;
  return { ok: true, manifest: { id: treeId, ...next } };
}

function deleteTree(db, accountId, treeId) {
  const idErr = _validId(treeId, 'treeId');
  if (idErr) return { ok: false, status: 400, message: idErr };
  const trees = _accountTrees(db, accountId);
  const existed = !!trees[treeId];
  delete trees[treeId];
  // Caller is responsible for purging chunks from S3 / memory store.
  for (const k of [..._memStore.keys()]) {
    if (k.startsWith(`${accountId}/${treeId}/`)) _memStore.delete(k);
  }
  return { ok: true, deleted: existed };
}

function deleteAllForAccount(db, accountId) {
  const trees = _accountTrees(db, accountId);
  const ids = Object.keys(trees);
  for (const id of ids) deleteTree(db, accountId, id);
  return { ok: true, deletedTrees: ids.length };
}

// ── Chunk storage helpers (kept tiny — actual S3 wiring lives in
//    license_server.js so the auth/audit layer stays in one place).

function chunkS3Key(accountId, treeId, chunkId) {
  return `${PREFIX}/users/${accountId}/trees/${treeId}/chunks/${chunkId}.bin`;
}

function memPut(accountId, treeId, chunkId, data) {
  if (data.length > MAX_CHUNK_BYTES) {
    throw new Error(`chunk too large (${data.length} > ${MAX_CHUNK_BYTES})`);
  }
  _memStore.set(`${accountId}/${treeId}/${chunkId}`, Buffer.from(data));
}

function memGet(accountId, treeId, chunkId) {
  return _memStore.get(`${accountId}/${treeId}/${chunkId}`) || null;
}

function memDelete(accountId, treeId, chunkId) {
  _memStore.delete(`${accountId}/${treeId}/${chunkId}`);
}

function memReset() { _memStore.clear(); }

// Quick sanity hash so the client can detect transport corruption.
function sha256Hex(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

module.exports = {
  MAX_BYTES_PER_ACCOUNT, MAX_TREES_PER_ACCOUNT,
  MAX_CHUNKS_PER_TREE, MAX_CHUNK_BYTES,
  listTrees, getManifest, putManifest, deleteTree, deleteAllForAccount,
  chunkS3Key, memPut, memGet, memDelete, memReset, sha256Hex,
};
