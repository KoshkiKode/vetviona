# App Tiers and Pricing

Vetviona uses a **three-tier model** — one free mobile tier and two paid tiers. All tiers use the same codebase; the tier is determined at compile time via `--dart-define` flags.

---

## Tier Comparison

| Feature | Mobile Free | Mobile Paid | Desktop Pro |
|---------|:-----------:|:-----------:|:-----------:|
| **Platform** | Android / iOS | Android / iOS | Windows / macOS / Linux |
| **Price** | Free | One-time purchase | One-time purchase (required) |
| **People per tree** | Up to 100 | Unlimited | Unlimited |
| **RootLoop™ Manual sync** | ✅ | ✅ | ✅ |
| **RootLoop™ Auto sync** | ❌ | ✅ | ✅ |
| **GEDCOM import / export** | ✅ | ✅ | ✅ |
| **PDF export** | ✅ | ✅ | ✅ |
| **Source citations** | ✅ | ✅ | ✅ |
| **Medical history** | ✅ | ✅ | ✅ |
| **Research tasks** | ✅ | ✅ | ✅ |
| **Bluetooth pairing** | ✅ | ✅ | ✅ (where supported) |
| **Unlimited trees** | ✅ | ✅ | ✅ |

---

## Mobile Free

- Default tier on first install (Android & iOS).
- All core genealogy features are available.
- Capped at **100 people per tree**.
- Sync is **manual only** (Bluetooth, QR code, or manual IP entry).

---

## Mobile Paid

Upgrade via **in-app purchase**:

1. *Settings → App Tiers* → **Upgrade to Mobile Paid**.
2. Follow the Google Play / App Store purchase flow.
3. The purchase receipt is stored in SharedPreferences (`vetviona_mobile_paid_purchased`).
4. The tier is restored automatically on reinstall via `PurchaseService.init()`.

**Product ID:** `com.koshkikode.vetviona.mobile_paid`

Unlocks:
- **Unlimited people**
- **RootLoop™ Auto** (WiFi auto-sync, mDNS discovery)

---

## Desktop Pro

Desktop builds **always require** the `PAID=true` compile-time flag:

```bash
flutter build windows --dart-define=PAID=true
flutter build macos   --dart-define=PAID=true
flutter build linux   --dart-define=PAID=true
```

If a desktop build is run **without** the flag, a lock screen is shown at startup.

Unlocks everything — equivalent to Mobile Paid on desktop.

---

## Cross-Device Pairing (Free + Pro)

When a **Mobile Free** device pairs with a **Desktop Pro** device for RootLoop™ sync:

- The pairing works normally.
- Sync is capped at **100 people** per session (the free device's limit).
- WiFi Auto-Sync falls back to **Manual only** for that pairing.

A note in *Settings → Paired Devices* indicates when a paired device is free-tier.

---

## Compile-Time Build Flags

| Flag | Tier |
|------|------|
| *(none)* | Mobile Free (default) |
| `--dart-define=MOBILE_PAID=true` | Mobile Paid |
| `--dart-define=PAID=true` | Desktop Pro |

---

## Tier Detection at Runtime

The current tier is determined in `app/lib/config/app_config.dart`:

```dart
enum AppTier { mobileFree, mobilePaid, desktopPro }

AppTier get currentAppTier {
  if (isPaidDesktop)    return AppTier.desktopPro;
  if (_isMobilePaid)    return AppTier.mobilePaid;
  return AppTier.mobileFree;
}
```

`_isPaidDesktop` and `_isMobilePaid` are set by `--dart-define` flags at build time.

The `isProTier` getter returns `true` for both `mobilePaid` and `desktopPro`.
