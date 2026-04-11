# RootLoop™ Sync

**RootLoop™** is Vetviona's proprietary device-to-device sync system. It operates **entirely on your local network** (or Tailscale VPN) — no cloud server is involved. All data is **AES-256 encrypted** before it leaves your device.

---

## Tiers

| Tier | Who gets it | How it works |
|------|-------------|--------------|
| **RootLoop™ Manual** | All tiers (including Mobile Free) | User-initiated sync over WiFi, Bluetooth, Tailscale, or file share |
| **RootLoop™ Auto** | Mobile Paid + Desktop Pro | Automatic background sync when devices are on the same network |

---

## How to Open Sync

*Home drawer → RootLoop™ Sync* — opens the **Sync Screen**.

---

## Pairing Devices

Before two devices can sync they must be **paired**. Pairing establishes a **shared secret** (a random UUID) that is used to derive the AES-256 encryption key.

### QR Code Pairing (Recommended)

1. On **Device A** (the host): open Sync Screen → tap **Show QR Code**.  
   The QR code encodes the host IP address, port, and shared secret.
2. On **Device B**: open Sync Screen → tap **Scan QR Code**.  
   Point the camera at Device A's QR code.
3. Both devices now share the secret. The pairing is stored in the `devices` table.

### Manual Entry

If QR scanning is not possible:

1. On **Device A**: open Sync Screen → note the **IP address** and **port** shown.
2. On **Device B**: open Sync Screen → tap **Manual Entry** → enter the host IP, port, and the shared secret (copy/paste or type it in).

### Bluetooth Discovery

On supported platforms (Android, iOS):

1. Both devices open Sync Screen.
2. Tap **Discover via Bluetooth** — the app scans for nearby Vetviona devices using **Bluetooth Low Energy** (BLE).
3. Tap a discovered device in the list to initiate pairing.

BLE advertisements encode the peer's WiFi IP address and port. The actual data transfer still happens over **HTTP over WiFi** — Bluetooth is used only for discovery.

---

## Syncing (Manual Trigger)

After pairing, sync any time:

1. Open Sync Screen.
2. Tap the peer device in the **Discovered Peers** list (auto-discovered via mDNS / WiFi Auto).
3. Or tap **Sync Now** / select from paired devices list.
4. A progress indicator shows sync status.

### RootLoop™ Auto (WiFi Auto-Sync)

For Mobile Paid and Desktop Pro users, sync is **fully automatic** when both devices are on the same WiFi network (or Tailscale). No button press needed — the app detects peers via mDNS and syncs in the background.

---

## Encryption & Security

### Key Derivation

```
AES key = SHA-256(sharedSecret)   → 32-byte key
```

### Encryption

```
AES-256-CBC
IV:         16 random bytes, per message
Ciphertext: AES-CBC(plaintext, key, IV)
Wire format: base64(IV) :: base64(ciphertext)
```

The entire JSON payload (persons + sources + partnerships + ...) is encrypted as a **single string** before transmission.

### No Central Server

- No data is sent to KoshkiKode servers.
- No account required.
- The shared secret never leaves your devices (it is generated locally during pairing).

---

## Sync Protocol (HTTP)

RootLoop™ uses a simple HTTP server on each device:

**Endpoint:** `POST /sync`

**Request body (encrypted):**

```json
{
  "senderId": "<device-uuid>",
  "senderTier": "mobilePaid",
  "persons": [...],
  "sources": [...],
  "partnerships": [...],
  "devices": [...],
  "lifeEvents": [...],
  "medicalConditions": [...],
  "researchTasks": [...]
}
```

**Response body (encrypted):** Same structure with the peer's changes.

mDNS service type: `_vetviona._tcp`

---

## Conflict Resolution

RootLoop™ uses a **last-write-wins** strategy:

| Data type | Behaviour |
|-----------|-----------|
| Person records | Newer record overwrites older |
| Sources | Appended (no duplicates by ID) |
| Partnerships | Merged by person-pair combination |
| Devices (paired list) | Union of both devices' known pairs |
| Private persons | **Excluded entirely** — never transmitted |

---

## Tailscale Support

Vetviona automatically detects **Tailscale** IP addresses (the `100.64.0.0/10` CGNAT range). If a Tailscale IP is present in the device's network interface list, it is shown in the Sync Screen so you can manually sync over a Tailscale VPN across the internet.

---

## Bluetooth Low Energy (BLE) Details

| Detail | Value |
|--------|-------|
| BLE Company ID | `0x4B4B` (KoshkiKode informal identifier) |
| Magic signature bytes | `[0x56, 0x45, 0x54, 0x56]` (ASCII "VETV") |
| Encoded payload | Peer's IPv4 address + HTTP port |

---

## Free Mobile Tier Limits

When a **free mobile device** syncs with a Desktop Pro device:

- Sync mode falls back to **Manual only** (no WiFi Auto).
- Data is capped at **100 people per sync session** (the free tier person limit).

---

## File-Based Sync (AirDrop / Nearby Share)

On platforms where the above methods are unavailable, you can export an encrypted tree file via **Share** (AirDrop on iOS/macOS, Nearby Share on Android) and import it on the other device. This uses the same AES-256 encryption as network sync.

---

## Paired Devices

Paired devices are listed in *Settings → Paired Devices*. Each entry shows:
- Device ID (UUID)
- Tier of the paired device
- A masked shared secret

To remove a paired device, tap the delete icon. Future sync attempts from that device will be rejected.
