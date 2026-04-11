# Research Tasks

Research Tasks help you **track genealogical to-do items** — records to find, archives to visit, relatives to contact, or hypotheses to test — directly within the app alongside your family data.

---

## Research Tasks Screen

*Home drawer → Research Tasks*

The screen shows all tasks, with controls to **filter by status** (to-do / in-progress / done) and **filter by priority** (low / normal / high).

Tasks can be tree-wide or linked to a specific person.

---

## Task Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Auto-generated |
| `personId` | String? | Optional link to a specific person; null = tree-wide |
| `title` | String | Brief description of the task |
| `notes` | String? | Longer description, context, or research notes |
| `status` | String | Current status (see below) |
| `priority` | String | Priority level (see below) |
| `treeId` | String? | Which tree this task belongs to |

---

## Status Values

| Value | Label | Meaning |
|-------|-------|---------|
| `todo` | To Do | Task not yet started |
| `in_progress` | In Progress | Actively being worked on |
| `done` | Done | Completed; kept for record |

---

## Priority Values

| Value | Label |
|-------|-------|
| `low` | Low |
| `normal` | Normal |
| `high` | High |

---

## Adding a Task

1. Navigate to *Home drawer → Research Tasks → **+***.
2. Enter a title and optional notes.
3. Set status and priority.
4. Optionally link to a person (select from the dropdown).
5. Tap **Save**.

Tasks linked to a person also appear in that person's **detail page** under the Research Tasks section.

---

## Updating a Task

Tap a task row to edit its title, notes, status, or priority. Swipe to delete.

---

## Example Use Cases

- *"Find baptism record for Heinrich Müller, born ~1842 Württemberg"* — linked to Heinrich, high priority, to-do.
- *"Verify whether the 1881 census John Smith is the right person"* — tree-wide task, normal priority, in-progress.
- *"Contact cousin Alice re: family photos"* — tree-wide, low priority.
- *"Order death certificate for Margaret Doyle d. 1923 Dublin"* — linked to Margaret, high priority, to-do.
