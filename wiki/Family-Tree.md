# Family Tree

Vetviona offers three interconnected tree-visualization screens plus a relationship-finding tool. All views are interactive and start from the configured [Home Person](Settings-and-Customization#home-person).

---

## Family Tree Diagram

*Home drawer → Family Tree*

The **Tree Diagram** is the main interactive canvas. It renders a focused family unit and lets you expand the view incrementally — so you never get overwhelmed with hundreds of nodes at once.

### Initial View (Focused Family Unit)

When you open the tree it shows the **Home Person's immediate family**:

| Included in initial view |
|--------------------------|
| The home person |
| Their partners |
| Their parents (and each parent's partner) |
| Their children |

If no Home Person is configured the first person in the database is used as the default.

### Expanding the Tree

Tap any person node to open their **bottom sheet**, then use the expand buttons to grow the tree:

| Button | What it adds |
|--------|-------------|
| **Show Parents** | The selected person's parents + their partners |
| **Show Children** | All children of the selected person |
| **Show Siblings** | Other children of the same parents (hidden siblings only) |

These buttons only appear when there are people to add (already-visible relatives are not shown again).

### AppBar Actions

| Button | Action |
|--------|--------|
| 🏠 Home | Reset the view back to the Home Person's immediate family |
| 🔳 Legend | Toggle the colour-coding legend overlay |
| 📊 Pedigree | Open the Pedigree Chart |
| ⊞ Reset view | Restore pan/zoom to the default position |

### Search

Type in the search bar (below the AppBar) to highlight matching person nodes in amber. A count badge shows how many people match across the whole tree (not just the currently visible nodes).

### Person Bottom Sheet

Tap any person node to see:

- Name, birth/death years, birth place
- Occupation (if recorded)
- **Full Profile** — navigate to the person's detail page
- **Focus** — re-centre the tree on this person's immediate family and reset the view
- **Show Parents / Show Children / Show Siblings** — contextual expand buttons (only shown when relevant hidden relatives exist)

### Colour Coding

| Colour | Meaning |
|--------|---------|
| Primary (teal) | Male |
| Error (red) | Female |
| Secondary (sage) | Unknown / Other gender |
| Amber border | Search match |
| Primary border | Currently selected person |

### Couple Knots

When two people have a recorded **Partnership**, a small circular **couple knot** node appears between them. The knot shows the marriage year (last two digits) if a start date is set, or a heart icon otherwise. Parent → child edges are routed through the knot.

### Node Layout Constants

| Constant | Value |
|----------|-------|
| Node width | 128 px |
| Node height | 88 px |
| Column gap | 44 px |
| Row gap | 100 px |

---

## Pedigree Chart

*Family Tree AppBar → pedigree icon, or Home drawer → Pedigree Chart*

The Pedigree Chart shows **ancestors only** — it traces backwards through time from a selected person.

### Focus Person Picker

A **searchable dropdown** at the top of the screen lets you choose the starting person. Start typing to filter alphabetically. The chart defaults to the configured [Home Person](Settings-and-Customization#home-person).

### Generation Depth

Use the layers menu (AppBar → layers icon) to show 2, 3, or 4 generations of ancestors. Each generation doubles the number of slots.

| Generations | Max ancestor slots |
|-------------|-------------------|
| 2 | 2 |
| 3 | 4 |
| 4 | 8 |

### Pedigree Box

Each ancestor box is colour-coded by gender. Tap a box to go to that person's detail screen. **Long-press** a box to re-centre the chart on that person.

### Navigation

The chart is fully pannable and zoomable (pinch or use the interactive viewer).

---

## Descendants Screen

*Home drawer → Descendants, or AppBar in PersonDetailScreen*

The Descendants Screen renders a **top-down tree** of all children, grandchildren, etc. of a chosen ancestor.

- Uses the **Buchheim-Walker algorithm** (via `graphview`) for clean node layout
- All descendants are collected via **BFS** (breadth-first search)
- Tap any node to open that person's detail screen

---

## Relationship Finder

*Home drawer → Relationship Finder*

Enter any two people and Vetviona calculates the **shortest relationship path** between them using a BFS over the person graph.

Results show the full ancestry chain: e.g. "Alice → parent of → Bob → parent of → Carol".

---

## Home Person

The **Home Person** controls which person is used as the default starting point for all tree views. Set it in *Settings → Display → Home Person*.

See [Settings and Customization](Settings-and-Customization#home-person) for details.

---

## Tips

- Use **Focus** in the person bottom sheet to quickly re-centre the tree on anyone.
- The **Reset to Home** (🏠) button restores the original focused family view if you've expanded far.
- The Pedigree and Descendants screens complement the main diagram — use them for deep ancestor or descendant chains where the main tree would get crowded.
