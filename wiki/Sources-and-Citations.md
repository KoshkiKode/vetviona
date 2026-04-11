# Sources and Citations

Vetviona uses a **Source** record to attach evidence to any fact in a person's profile. Sources can cover birth certificates, census records, newspaper clippings, online databases, oral interviews, photographs, and more.

---

## What is a Source?

A source is a citation record linked to **one person** and optionally to **one or more specific facts** (e.g., "Birth Date", "Death Place"). When you have conflicting evidence from multiple sources for the same fact, the [Conflict Resolver](#conflict-resolver) helps you pick which source to trust.

---

## Source Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Auto-generated |
| `personId` | String | The person this source is about |
| `title` | String | Descriptive title (e.g. "1881 England Census") |
| `type` | String | Category (see types below) |
| `url` | String? | URL to online record or finding aid |
| `imagePath` | String? | Local path to a scanned image or document |
| `extractedInfo` | String? | Transcription or key facts from the source |
| `citedFacts` | List\<String\> | Facts this source supports (e.g. `["Birth Date", "Birth Place"]`) |
| `author` | String? | Author or creator of the source |
| `publisher` | String? | Publisher or issuing authority |
| `publicationDate` | String? | Date published or issued |
| `repository` | String? | Archive, library, or database name |
| `volumePage` | String? | Volume, folio, page, or frame reference |
| `retrievalDate` | String? | Date the URL was last accessed (for web sources) |
| `confidence` | String? | Reliability rating (see below) |
| `treeId` | String? | Which tree this source belongs to |

---

## Source Types

Common values (free text — you can use any type label):

- Birth Certificate
- Death Certificate
- Marriage Certificate
- Census Record
- Church Record (Baptism / Burial / Marriage)
- Probate / Will
- Military Record
- Immigration Record / Passenger List
- Newspaper Article / Obituary
- Photograph
- Oral Interview / Family Story
- DNA Evidence
- Online Database (Ancestry, FamilySearch, FindMyPast, etc.)
- Land / Property Record
- Court Record
- School Record
- Other

---

## Confidence Ratings

| Rating | Label | Meaning |
|--------|-------|---------|
| **A** | Reliable | Original primary source; high confidence |
| **B** | Secondary | Derivative or published index; generally accurate |
| **C** | Questionable | Transcription errors possible; treat with caution |
| **D** | Unreliable | Known problems or bias; do not rely on alone |
| **F** | Conflicting | Directly contradicts another source |

---

## Cited Facts

When you add a source you can tag it with the **facts it supports**. These fact names are the same identifiers used by the Conflict Resolver:

| Fact name | Description |
|-----------|-------------|
| Birth Date | Person's birth date |
| Birth Place | Person's birth place |
| Death Date | Person's death date |
| Death Place | Person's death place |
| Marriage Date | Partnership start date |
| Marriage Place | Partnership start place |

You can enter any free-text fact name for other fields.

---

## Adding a Source

1. Open a person's detail page → **Sources** section → **+**.
2. Or from the main drawer → **Sources** page → **+**.
3. Fill in title, type, and at least one cited fact.
4. Optionally attach an image (scan of a document), URL, confidence rating, and repository details.
5. Tap **Save**.

---

## Sources Page

*Drawer → Sources*

A tree-level list of **all sources** across all people. You can:
- Browse by person or by source type
- Search by title, author, or repository
- Tap a source to edit or view its details

---

## Conflict Resolver

*Drawer → Conflict Resolver*

The Evidence Conflict Resolver automatically scans for **facts where two or more sources disagree** on the same person. Currently tracked fact types:

- Birth Date
- Birth Place
- Death Date
- Death Place

For each conflict it shows:
- The person
- The disputed fact
- All sources with their differing values and confidence ratings

You can **select the preferred source** for each fact. The choice is saved in the person's `preferredSourceIds` map (`fact name → source ID`).

---

## Sources in GEDCOM Export

Sources are exported as `SOUR` records with standard sub-tags:

```
0 @S001@ SOUR
1 TITL 1881 England Census
1 AUTH Office for National Statistics
1 PUBL The National Archives
1 REPO PRO, Kew, Surrey
1 NOTE Piece 1234, folio 56, page 7
```

Fact citations appear inline in `INDI` records:

```
1 BIRT
2 DATE 12 MAR 1881
2 PLAC Leeds, Yorkshire, England
2 SOUR @S001@
```

---

## Source Privacy

If a source is attached to a **private person** (`isPrivate = true`), that source is excluded from GEDCOM exports and RootLoop™ sync along with the person record.
