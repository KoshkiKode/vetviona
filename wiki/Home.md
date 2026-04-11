# Vetviona — Wiki Home

**Vetviona** is a private, local-first genealogy app by [KoshkiKode](https://vetviona.koshkikode.com). It lets you build detailed family trees, attach sources and evidence, track medical genealogy, and sync securely between your own devices — with no cloud account required.

---

## Quick Feature Map

| Feature | Where to learn more |
|---------|-------------------|
| Build & navigate family trees | [Family Tree](Family-Tree) |
| Add and edit people | [People and Profiles](People-and-Profiles) |
| Record marriages & partnerships | [Partnerships](Partnerships) |
| Cite evidence, sources, documents | [Sources and Citations](Sources-and-Citations) |
| Log life events, timeline view | [Life Events and Timeline](Life-Events-and-Timeline) |
| Track heritable medical history | [Medical History](Medical-History) |
| Manage genealogy research tasks | [Research Tasks](Research-Tasks) |
| Sync between devices (RootLoop™) | [RootLoop Sync](RootLoop-Sync) |
| Import / export GEDCOM files | [GEDCOM Import and Export](GEDCOM-Import-Export) |
| Themes, home person, date format | [Settings and Customization](Settings-and-Customization) |
| Free vs. Paid tiers | [App Tiers and Pricing](App-Tiers-and-Pricing) |
| Data models, DB schema, services | [Architecture and Technical Reference](Architecture-and-Technical-Reference) |
| Build the app from source | [Building and Development](Building-and-Development) |
| Encryption, privacy, security | [Security and Privacy](Security-and-Privacy) |

---

## Platform Support

| Platform | Tier available |
|----------|---------------|
| Android | Mobile Free, Mobile Paid |
| iOS | Mobile Free, Mobile Paid |
| Windows | Desktop Pro |
| macOS | Desktop Pro |
| Linux | Desktop Pro |

---

## Core Principles

- **Offline-first.** All data lives in a local SQLite database on your device. An internet connection is never required.
- **Zero-knowledge sync.** When you sync with another device you own, data is encrypted with AES-256 before it leaves the device. No central server ever sees your data.
- **Privacy controls.** Any person can be marked `isPrivate`, which excludes them from GEDCOM exports and all sync operations — their records stay strictly local.
- **Open standard.** GEDCOM 5.5.1 import and export means your data is never locked in.

---

## Getting Started

New to Vetviona? Start here → **[Getting Started](Getting-Started)**

---

## Version

| | |
|-|-|
| **App version** | 1.0.0 |
| **RootLoop™ version** | 1.0.0 |
| **Database schema** | v7 |
| **Dart SDK** | ≥ 3.0.0 |
| **Flutter** | ≥ 3.0.0 |
