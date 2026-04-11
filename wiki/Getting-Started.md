# Getting Started

This page walks you through installing Vetviona, running it for the first time, and completing the onboarding flow.

---

## Installation

### Android & iOS (Mobile)

1. Download Vetviona from the **Google Play Store** or **Apple App Store**.
2. The app launches in **Mobile Free** mode by default (up to 100 people per tree, manual sync only).
3. To upgrade to **Mobile Paid**, go to *Settings → App Tiers* and follow the in-app purchase flow.

### Windows / macOS / Linux (Desktop Pro)

Desktop builds require the `PAID=true` compile-time flag — they are always Desktop Pro.

```bash
# Windows
flutter build windows --dart-define=PAID=true

# macOS
flutter build macos --dart-define=PAID=true

# Linux
flutter build linux --dart-define=PAID=true
```

Pre-built installers (when available) already include the flag.

> If you run a desktop build **without** `--dart-define=PAID=true` the app will show a lock screen at startup. Pass the flag to unlock it.

---

## First Launch — Onboarding

When you open Vetviona for the first time the **Onboarding Screen** walks you through:

1. **Welcome** — brief introduction to the app and its philosophy.
2. **Feature overview** — tree builder, sources, sync, timelines, medical history.
3. **Privacy note** — your data never leaves your device unless you explicitly sync.
4. **Done** — the onboarding flag (`onboardingDone`) is saved in SharedPreferences. You will not see this screen again unless you clear app data.

After onboarding you land on the **Home Screen**.

---

## Home Screen Overview

The Home Screen is the central hub of the app.

| Area | Description |
|------|-------------|
| **Person list** | Searchable, filterable, sortable list of everyone in the current tree |
| **Search bar** | Real-time search by name, birth place, death place, notes |
| **Sort / Filter controls** | Sort by name, birth date; filter by gender or living/deceased |
| **Quick-add button** | Floating button to add a new person immediately |
| **Drawer menu** | Access all major sections: Tree views, Sync, Calendar, Research Tasks, GEDCOM, PDF export, Settings |
| **App bar actions** | Shortcut to Family Tree diagram |

---

## Adding Your First Person

1. Tap the **+** floating action button on the Home Screen (or open the drawer → *Add Person*).
2. Fill in at minimum a **name**. All other fields are optional.
3. Tap **Save**. The person appears in the list.

See [People and Profiles](People-and-Profiles) for a full description of every field.

---

## Connecting People

After adding two or more people you can link them:

- **Parent / child links** — open a person's detail page → *Relationships* section → *Add Parent* or *Add Child*.
- **Partnerships (marriages)** — open a person's detail page → *Partnerships* section → *Add Partnership*. See [Partnerships](Partnerships).

---

## Setting the Home Person

The **Home Person** is the default focal point for tree views (Family Tree diagram, Pedigree Chart). Set it once and all tree views will start there.

*Settings → Display → Home Person (tree focal point)* — type to search, select a person, done.

---

## Navigation Reference

| Screen | How to reach it |
|--------|----------------|
| Family Tree | Home drawer → *Family Tree* or AppBar shortcut |
| Pedigree Chart | Family Tree AppBar → pedigree icon |
| Descendants | Drawer → *Descendants* |
| Sync | Drawer → *RootLoop™ Sync* |
| Settings | Drawer → *Settings* |
| Calendar | Drawer → *Calendar* |
| Research Tasks | Drawer → *Research Tasks* |
| GEDCOM Import | Drawer → *Import GEDCOM* |
| PDF Export | Drawer → *Export Family Book PDF* |
| Person detail | Tap any person in the list |

---

## Next Steps

- [Add detailed profiles for people](People-and-Profiles)
- [Link parents, children, and partners](Partnerships)
- [Attach sources and citations to facts](Sources-and-Citations)
- [Set up RootLoop™ sync with your other devices](RootLoop-Sync)
