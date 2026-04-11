# People and Profiles

Every individual in your family tree is represented by a **Person** record. Person records hold biographical, genealogical, and physical data, plus links to photos, sources, life events, and medical history.

---

## Creating a Person

1. Tap **+** on the Home Screen (or drawer → *Add Person*).
2. Enter at least a **name** — all other fields are optional.
3. Tap **Save**.

---

## Person Detail Screen

Open any person from the Home Screen list or from a tree node to reach their **detail page**. It is divided into sections:

| Section | Contents |
|---------|----------|
| **Basic Info** | Name, gender, maiden name, nationality, occupation |
| **Birth** | Date, place, postal code, map coordinate |
| **Death** | Date, place, cause, postal code, map coordinate |
| **Burial** | Date, place, postal code, map coordinate |
| **Physical Traits** | Blood type, eye colour, hair colour, height |
| **Background** | Religion, education, aliases |
| **Privacy** | `isPrivate` toggle |
| **Notes** | Free-text notes |
| **Photos** | Photo gallery |
| **Relationships** | Parent, child, and sibling links |
| **Partnerships** | Marriages / co-parenting relationships |
| **Life Events** | Custom dated events (baptism, census, etc.) |
| **Sources** | Citation records attached to this person |
| **Medical History** | Heritable conditions and health records |
| **Research Tasks** | To-do items linked to this person |

---

## All Person Fields

### Identity

| Field | Type | Notes |
|-------|------|-------|
| `id` | String (UUID) | Auto-generated; never edited |
| `name` | String | Required |
| `gender` | String? | "Male", "Female", or free text |
| `maidenName` | String? | Birth surname |
| `nationality` | String? | Free text |
| `occupation` | String? | Free text |
| `aliases` | String? | Semicolon-separated alternate names |
| `notes` | String? | Free-form biographical notes |

### Vital Dates & Places

| Field | Type | Notes |
|-------|------|-------|
| `birthDate` | DateTime? | |
| `birthPlace` | String? | Free text; can use Place Picker for geocoding |
| `birthCoord` | GeoCoord? | Lat/lng + reverse-geocoded city/county/state/country |
| `birthPostalCode` | String? | Postal / ZIP code |
| `deathDate` | DateTime? | |
| `deathPlace` | String? | |
| `deathCoord` | GeoCoord? | |
| `deathPostalCode` | String? | |
| `causeOfDeath` | String? | Free text |
| `burialDate` | DateTime? | |
| `burialPlace` | String? | |
| `burialCoord` | GeoCoord? | |
| `burialPostalCode` | String? | |

### Physical Traits

| Field | Type | Example values |
|-------|------|---------------|
| `bloodType` | String? | A+, B−, O+, AB+, etc. |
| `eyeColour` | String? | brown, hazel, blue, grey, green |
| `hairColour` | String? | auburn, black, blonde, grey, white |
| `height` | String? | Free text (e.g. "178 cm", "5′10″") |

### Background

| Field | Type | Notes |
|-------|------|-------|
| `religion` | String? | Free text |
| `education` | String? | Free text (e.g. "Bachelor of Arts, Oxford 1952") |

### References & Privacy

| Field | Type | Notes |
|-------|------|-------|
| `treeId` | String? | Which family tree this person belongs to |
| `sourceIds` | List\<String\> | IDs of attached [Source](Sources-and-Citations) records |
| `photoPaths` | List\<String\> | Local file paths to photos |
| `isPrivate` | bool | If true: excluded from GEDCOM export **and** all RootLoop™ sync |
| `preferredSourceIds` | Map\<String, String\> | Fact name → preferred source ID (for [Conflict Resolver](Sources-and-Citations#conflict-resolver)) |

### Relationship IDs

| Field | Type | Notes |
|-------|------|-------|
| `parentIds` | List\<String\> | Up to 2 parent person UUIDs |
| `parentRelTypes` | Map\<String, String\> | Per-parent: "biological", "adoptive", "step", "foster", "unknown" |
| `childIds` | List\<String\> | Child person UUIDs |

---

## Photos

Open a person's detail page → **Photos** section → tap **+** to add from the device gallery or camera.

The **Photo Gallery Screen** shows all images in a scrollable grid. Tap an image to view full-screen. Long-press to delete or reorder.

Photo paths are stored as local file paths (`photoPaths` field). Photos are **not synced** — they stay on the device where they were added.

---

## Privacy Flag (`isPrivate`)

Enable *Private* on a person to:

- **Exclude them from GEDCOM exports** — they will not appear in `.ged` files you share.
- **Exclude them from RootLoop™ sync** — their data is never transmitted to peer devices.

Use this for living family members whose personal details (address, phone, email in notes, etc.) should never leave the device.

> **Tip:** Parent/child relationships involving a private person are also suppressed in exports and sync to avoid indirectly leaking their existence.

---

## Place Picker

When editing birth, death, or burial place, tap the **map pin** icon to open the **Place Picker**:

1. Pan/zoom the map (powered by OpenStreetMap / flutter_map) to the location.
2. Tap to drop a pin, or use the search box to search by place name.
3. The reverse-geocoded address (city, county, state, country, postal code) is automatically filled in.

The coordinate is saved as a `GeoCoord` object and displayed in the person's detail view.

---

## Relationship Types

When adding a parent link you can specify the **relationship type**:

| Type | Description |
|------|-------------|
| biological | Natural birth parent |
| adoptive | Legal adoption |
| step | Step-parent via marriage |
| foster | Foster care relationship |
| unknown | Relationship type not established |

---

## Searching and Filtering People

From the Home Screen:

- **Search bar** — instant filter by name, birth place, death place, or notes.
- **Sort** — alphabetically (A–Z / Z–A) or by birth date (oldest / newest first).
- **Filter** — show all / living only / deceased only; filter by gender.

---

## Deleting a Person

Open the person's detail page → overflow menu (⋮) → **Delete**. This removes the person and also removes their ID from all `parentIds` and `childIds` lists of other people. Partnerships where this person was a partner are also deleted.
