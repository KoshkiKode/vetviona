# Partnerships

A **Partnership** records the relationship between two people — marriage, civil partnership, co-parenting, or any other union. Partnerships are the mechanism through which children get two listed parents and couple knots appear in the Family Tree diagram.

---

## Creating a Partnership

1. Open either person's **detail page**.
2. Scroll to the **Partnerships** section.
3. Tap **Add Partnership**.
4. Select the second partner from the person list.
5. Fill in the details (status, dates, etc.) and **Save**.

---

## Partnership Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Auto-generated |
| `person1Id` | String | First partner's UUID |
| `person2Id` | String | Second partner's UUID |
| `status` | String | Current status (see table below) |
| `startDate` | DateTime? | Wedding / union start date |
| `startPlace` | String? | Location of ceremony / start |
| `endDate` | DateTime? | Date of divorce, separation, death, or annulment |
| `endPlace` | String? | Location where union ended |
| `ceremonyType` | String? | Type of ceremony (see table below) |
| `sourceIds` | List\<String\> | Evidence citations (marriage certificate, etc.) |
| `witnesses` | String? | Names of witnesses, free text |
| `notes` | String? | Additional notes |
| `treeId` | String? | Which tree this partnership belongs to |

---

## Status Values

| Value | Label | Description |
|-------|-------|-------------|
| `married` | Married | Active legal marriage |
| `partnered` | Partnered | Committed partnership (civil union, de facto, etc.) |
| `divorced` | Divorced | Marriage legally dissolved |
| `separated` | Separated | Partners living apart but not legally divorced |
| `annulled` | Annulled | Marriage declared void |
| `other` | Other | Any other union type |

Use `isEnded` (computed helper) to check whether a partnership has a status of divorced, separated, annulled, or a set `endDate`.

---

## Ceremony Types

| Value | Description |
|-------|-------------|
| `civil` | Civil / registry ceremony |
| `religious` | Church, synagogue, mosque, temple, etc. |
| `traditional` | Indigenous or cultural ceremony |
| `common-law` | Common-law / de facto |
| `other` | Any other ceremony format |

---

## Attaching Sources

Marriage certificates, civil records, and newspaper announcements can be attached as **Source** records. Add them via the partnership's **Sources** section or from the [Sources and Citations](Sources-and-Citations) page.

---

## How Partnerships Relate to Children

When two partners each list the same child in their `childIds`, Vetviona links the child to the **partnership** (the couple knot in the tree). Specifically:

- A child has up to two entries in `parentIds`.
- If both those parent IDs match the `person1Id` and `person2Id` of a partnership, the child's parent → child edge in the Family Tree is drawn from the **couple knot** node rather than from either parent individually.

This means children appear visually below the couple knot, making it clear they belong to both parents.

---

## Multiple Partnerships

A person can have multiple partnerships (sequential marriages, co-parenting with different partners, etc.). Each appears as a separate record. All active and ended partnerships are shown in the person's detail screen.

---

## GEDCOM Export

Partnerships are exported as `FAM` records:

```
0 @F001@ FAM
1 HUSB @I001@
1 WIFE @I002@
1 MARR
2 DATE 15 JUN 1965
2 PLAC London, England
1 DIV
2 DATE 03 MAR 1982
```

(Husband/wife labels are used for GEDCOM compatibility regardless of actual gender or ceremony type.)

---

## Editing and Deleting a Partnership

Open either partner's detail page → **Partnerships** section → tap the partnership row to edit, or swipe to delete. Deleting a partnership does **not** remove the people or their parent/child links — it only removes the union record itself.
