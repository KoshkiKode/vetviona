# Settings and Customization

*Home drawer → Settings*

The Settings screen is organised into sections. This page documents every available option.

---

## Appearance

### Dark Mode

Toggle between the **Slavic bookish light palette** and the **forest green dark palette**.

| Mode | Description |
|------|-------------|
| Light | Warm parchment background (`#F8F7F3`), dark ink text, green accents |
| Dark | Deep forest green surface (`#121412`), light ink text, green accents |

### Primary Color

Use the **color picker** to customise the primary brand colour. A live swatch shows the current selection. Tap **Reset to default** to restore the Vetviona palette colour for the active mode.

| Mode | Default primary |
|------|----------------|
| Light | `#1A3C34` (dark teal) |
| Dark | `#2D5A4F` (forest green) |

---

## Sound

### UI Sounds

Enable or disable **sound effects** for sync events (sync start, success, failure, warning tones). Uses the `audioplayers` package.

---

## Display

### Date Format

Choose how dates are displayed throughout the app:

| Option | Example |
|--------|---------|
| `dd MMM yyyy` | 01 Jan 2000 |
| `MM/dd/yyyy` | 01/01/2000 |
| `yyyy-MM-dd` | 2000-01-01 |

This preference is stored in SharedPreferences and applied to all date displays (birth dates, life events, partnership dates, etc.).

### Historical Place Names

Control how place names are displayed when historical context is available:

| Level | Description |
|-------|-------------|
| 0 — Modern names only | Show only the current country/place name |
| 1 — Also show colonizer names | Show the European colonial-era name alongside the modern name |
| 2 — Also show indigenous names | Show the indigenous / pre-colonial name alongside the modern name |

### Home Person (Tree Focal Point) {#home-person}

The **Home Person** is the default starting point for all tree views:

- [Family Tree Diagram](Family-Tree#family-tree-diagram) opens with this person's immediate family unit.
- [Pedigree Chart](Family-Tree#pedigree-chart) defaults to this person.
- The Home button (🏠) in the Family Tree AppBar resets to this person.

**To set the Home Person:**

1. Open Settings → Display.
2. Find **Home Person (tree focal point)**.
3. Start typing a name to search — the list is sorted alphabetically and filters as you type.
4. Select the person.

The choice is saved in SharedPreferences under the key `homePersonId` and persists across app restarts.

If no Home Person is configured, the first person in the database is used as a fallback.

---

## RootLoop™ Sync

Quick link to the **Sync Screen** plus:

- **Bluetooth Sync toggle** (Android / iOS only) — enable Bluetooth Low Energy discovery.
- **WiFi Auto-Sync toggle** (Mobile Paid / Desktop Pro only) — enable automatic background sync.

See [RootLoop Sync](RootLoop-Sync) for full documentation.

---

## Paired Devices

Lists all devices you have paired for sync. Each entry shows:

- Device UUID
- Tier of the paired device (mobileFree, mobilePaid, desktopPro)
- A masked shared secret

Tap the **delete icon** to remove a device. Future sync requests from that device will be refused.

> **Free mobile + Pro desktop pairing note:** If any paired device is `mobileFree`, a note is shown explaining the 100-person sync cap.

---

## Backup & Restore

### Create Backup

Exports the entire tree to a **JSON file**. Includes persons, sources, partnerships, life events, medical conditions, research tasks, and tree metadata.

Choose a save location with the file picker. The file can be stored anywhere (local storage, cloud drive, etc.).

### Restore from Backup

Imports a previously exported JSON backup. This **overwrites** all current tree data. A confirmation dialog appears before proceeding.

---

## Danger Zone

### Clear All Data

**Permanently deletes** all people, sources, partnerships, life events, medical conditions, research tasks, and settings from the local database.

A confirmation dialog (with a second tap required) appears before the delete runs. **This cannot be undone.**

---

## Privacy & Legal

- **Privacy Policy** — links to `https://vetviona.koshkikode.com/privacy`
- **Terms of Service** — links to `https://vetviona.koshkikode.com/terms`

---

## Version Info

Displayed at the bottom of the Settings screen:

```
Vetviona 1.0.0
RootLoop™ 1.0.0
```
