# Security and Privacy

Vetviona is designed around a **privacy-first, zero-knowledge** philosophy. This page explains the security architecture and privacy controls.

---

## Core Principles

1. **No cloud account required.** Your data never leaves your device unless you explicitly initiate a sync.
2. **Zero-knowledge sync.** When you sync with another device, all data is encrypted with AES-256 **before** it is transmitted. The app has no way to send unencrypted data to any server — there is no central server to send it to.
3. **Local authentication only.** Credentials are stored with salted SHA-256 hashing in device-local SharedPreferences. No passwords are sent over the network.
4. **Explicit private persons.** Any individual can be marked `isPrivate`, which completely excludes them from all exports and sync operations.
5. **Open standard export.** GEDCOM export means your data is never locked in to Vetviona.

---

## RootLoop™ Sync Encryption

### Key Derivation

```
sharedSecret  →  SHA-256(sharedSecret)  →  32-byte AES key
```

The shared secret is a UUID generated locally during pairing. It is never transmitted without being used as the encryption key itself.

### Encryption Algorithm

| Detail | Value |
|--------|-------|
| Algorithm | AES-256-CBC |
| IV length | 16 bytes (random, per message) |
| Key length | 32 bytes (SHA-256 of shared secret) |
| Wire format | `base64(IV) :: base64(ciphertext)` |
| Plaintext | Full JSON payload (all tree data) |

### What is Encrypted

The **entire sync payload** is encrypted as a single blob:

```json
{
  "senderId": "...",
  "senderTier": "...",
  "persons": [...],
  "sources": [...],
  "partnerships": [...],
  "devices": [...],
  "lifeEvents": [...],
  "medicalConditions": [...],
  "researchTasks": [...]
}
```

No metadata is transmitted in the clear.

### What is NOT Encrypted

- mDNS service advertisements (device name and port only; no tree data)
- BLE advertisements (IP address and port only; no tree data)

---

## Local Authentication

Credentials for the optional local login are stored in **SharedPreferences** on the device:

```
Key:   user_<username>
Value: <uuid-salt>:<sha256-hex-hash>

Hash = SHA-256(password + salt)
```

- Passwords are never stored in plaintext.
- No passwords or hashes are transmitted over the network.
- The login feature is **optional** — the app works without it for single-user local use.

---

## Private Persons (`isPrivate`)

Setting `isPrivate = true` on any person:

- **Excludes them from GEDCOM export** — they will not appear in any `.ged` file produced by the export feature.
- **Excludes them from RootLoop™ sync** — their person record, sources, life events, and medical conditions are never included in a sync payload.
- **Suppresses their relationships in exports** — parent/child edges involving a private person are also removed to avoid indirectly revealing their existence.

Use this for living family members whose contact details, addresses, health records, or other sensitive data must never leave the device.

---

## Data Storage

All data is stored in a **local SQLite database** at:

```
{ApplicationDocumentsDirectory}/vetviona.db
```

This directory is:
- On **Android**: internal app storage (not accessible to other apps without root)
- On **iOS**: app sandbox Documents directory (excluded from iCloud backup by default)
- On **Windows/macOS/Linux**: user's Documents directory

No data is written to cloud storage by the app itself.

---

## Photo Storage

Photos are stored as **local file paths** in the device's file system. They are:
- Not included in RootLoop™ sync.
- Not included in GEDCOM export.
- Only accessible from the device where they were added.

---

## Backup Files

When you use *Settings → Backup & Restore → Create Backup*, the exported JSON file contains all tree data **in plaintext**. Treat this file like any other sensitive document — store it securely and do not share it unencrypted.

---

## Paired Device Secrets

Each paired device has a **shared secret** (UUID) stored in the `devices` table. This secret:

- Is generated locally at pairing time (never sent to a server).
- Is the sole key for all encrypted communication with that device.
- Should be kept secret — anyone with the shared secret and knowledge of the IP/port could potentially sync with your device.
- Can be revoked by deleting the device from *Settings → Paired Devices*.

---

## Network Security

RootLoop™ sync operates over your **local network** (LAN or Tailscale VPN):

- The HTTP server only binds to local network interfaces (not exposed to the public internet by default).
- All payloads are AES-256 encrypted before transmission.
- mDNS discovery is local-subnet only (does not traverse the public internet).
- Tailscale connections are end-to-end encrypted at the VPN layer in addition to RootLoop™'s own encryption.

---

## Responsible Disclosure

Found a security vulnerability? Please report it responsibly by emailing the address listed in [SECURITY.md](https://github.com/KoshkiKode/vetviona/blob/main/SECURITY.md) rather than opening a public issue.

---

## Summary

| Threat | Mitigation |
|--------|-----------|
| Data theft from device | OS-level app sandbox; no cloud storage |
| Interception during sync | AES-256-CBC end-to-end encryption |
| Weak passwords | SHA-256 with random salt |
| Leaking living relatives' data | `isPrivate` flag excludes from all exports and sync |
| Backup file exposure | User responsibility; plaintext warning in docs |
| Rogue paired device | Delete from Settings → Paired Devices to revoke |
| mDNS fingerprinting | Service type reveals "Vetviona"; no tree data leaked |
