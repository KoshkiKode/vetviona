# Life Events and Timeline

Life events let you record dated milestones beyond the standard birth, marriage, and death — baptisms, census appearances, military service, immigration, graduations, and more.

---

## Timeline Screen

*Home drawer → Timeline, or from PersonDetailScreen*

The Timeline shows all of a person's life events in **chronological order**:

- Birth and death dates
- All custom life events (with date, place, notes)
- Partnership start/end dates

Each row shows the event title, date, and place. Tap an event to view or edit its details.

---

## Life Event Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Auto-generated |
| `personId` | String | The person this event belongs to |
| `title` | String | Event name (see standard types below) |
| `date` | DateTime? | Date of the event |
| `place` | String? | Where the event occurred |
| `notes` | String? | Additional context or transcribed text |
| `treeId` | String? | Which tree this event belongs to |

---

## Standard Event Types

Vetviona supports these named event types (used for GEDCOM tag mapping on export):

| Event title | GEDCOM tag | Description |
|-------------|-----------|-------------|
| Baptism | `BAPM` | Religious baptism |
| Christening | `CHR` | Christening / naming ceremony |
| Confirmation | `CONF` | Religious confirmation |
| Bar / Bat Mitzvah | — | Jewish coming-of-age |
| Graduation | `GRAD` | Academic graduation |
| Military Service | `MILI` | Military enlistment or service period |
| Immigration | `IMMI` | Arrival in a new country |
| Emigration | `EMIG` | Departure from home country |
| Naturalisation | `NATU` | Citizenship grant |
| Census | `CENS` | Appearance in a census record |
| Occupation Change | — | New job or career |
| Residence | `RESI` | Documented place of residence |
| Illness | — | Significant illness or hospitalisation |
| Other | — | Any other event |

You can also enter a completely custom event title — it will be saved as **Other** in GEDCOM export.

---

## Adding a Life Event

1. Open a person's detail page → **Life Events** section → **+**.
2. Choose an event type from the dropdown (or enter a custom title).
3. Fill in date, place, and optional notes.
4. Tap **Save**.

---

## Calendar Screen

*Home drawer → Calendar*

The Calendar shows upcoming **birthdays** and **anniversaries** for the current and next month. Events are listed in date order with the person's name and the number of years since the original event.

---

## GEDCOM Export

Life events are exported as individual event blocks within `INDI` records:

```
1 IMMI
2 DATE 14 APR 1912
2 PLAC New York, USA
2 NOTE Arrived aboard SS Mauretania
```

Events with no matching GEDCOM tag are exported as `EVEN` with a `TYPE` sub-tag:

```
1 EVEN
2 TYPE Graduation
2 DATE JUN 1934
2 PLAC Oxford, England
```
