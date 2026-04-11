# GEDCOM Import and Export

**GEDCOM** (Genealogical Data Communication) is the de facto industry standard for exchanging genealogical data between applications. Vetviona supports **GEDCOM 5.5.1** for both import and export.

---

## Importing a GEDCOM File

*Home drawer → Import GEDCOM*

### Steps

1. Tap **Import GEDCOM** in the drawer.
2. Use the file picker to select a `.ged` file from your device storage.
3. Choose the import mode:
   - **Clean import** — imports everyone as new records.
   - **Merge mode** — deduplicates against your existing tree.
4. Tap **Start Import**.
5. The importer works in **batches** and shows a progress bar. You can **pause** and **resume** at any time.

### Merge Mode

When merge mode is active the importer **deduplicates by name + birth year**:

- If an incoming person matches an existing person (same name, same birth year), the import **skips** the incoming record and **remaps all relationship IDs** to point to the existing person instead.
- This avoids duplicates when re-importing an updated version of a file you previously imported.

Progress (including the batch position and ID-remap table) is **persisted in SharedPreferences** so the import can survive app restarts.

---

## Supported GEDCOM Tags (Import)

### Individual (`INDI`)

| Tag | Field |
|-----|-------|
| `NAME` | Name (with `GIVN`, `SURN`, `_MARNM` sub-tags) |
| `SEX` | Gender (M/F/U) |
| `OCCU` | Occupation |
| `RELI` | Religion |
| `BIRT` | Birth (with `DATE`, `PLAC`, `SOUR`) |
| `DEAT` | Death (with `DATE`, `PLAC`, `SOUR`) |
| `BURI` | Burial (with `DATE`, `PLAC`) |
| `BAPM` | Baptism → LifeEvent |
| `CHR` | Christening → LifeEvent |
| `CONF` | Confirmation → LifeEvent |
| `GRAD` | Graduation → LifeEvent |
| `IMMI` | Immigration → LifeEvent |
| `EMIG` | Emigration → LifeEvent |
| `NATU` | Naturalisation → LifeEvent |
| `RESI` | Residence → LifeEvent |
| `CENS` | Census → LifeEvent |
| `MILI` | Military Service → LifeEvent |
| `NOTE` | Notes |
| `SOUR` | Inline source citation |

### Family (`FAM`)

| Tag | Field |
|-----|-------|
| `HUSB` | Partner 1 |
| `WIFE` | Partner 2 |
| `CHIL` | Child |
| `MARR` | Marriage (with `DATE`, `PLAC`) |
| `DIV` | Divorce (with `DATE`) |

### Source (`SOUR`)

| Tag | Field |
|-----|-------|
| `TITL` | Title |
| `AUTH` | Author |
| `PUBL` | Publisher |

---

## Exporting a GEDCOM File

*Person detail page → overflow menu → Export GEDCOM, or drawer → Export*

The exporter produces a standards-compliant `.ged` file containing:

- All persons (excluding `isPrivate = true` records)
- All partnerships
- All life events
- Source citations

### Export Structure

```
0 HEAD
1 GEDC
2 VERS 5.5.1
1 CHAR UTF-8
0 @I001@ INDI
1 NAME John /Smith/
1 SEX M
1 BIRT
2 DATE 12 MAR 1881
2 PLAC Leeds, Yorkshire, England
1 DEAT
2 DATE 05 JAN 1952
2 PLAC Bradford, Yorkshire, England
1 OCCU Coal miner
1 NOTE Notes about this person
0 @F001@ FAM
1 HUSB @I001@
1 WIFE @I002@
1 MARR
2 DATE 14 SEP 1905
2 PLAC Halifax, Yorkshire, England
1 CHIL @I003@
0 @S001@ SOUR
1 TITL 1901 England Census
1 AUTH General Register Office
0 TRLR
```

---

## Limitations

| Feature | Status |
|---------|--------|
| Multimedia objects (`OBJE`) | Not supported |
| Nested source structures | Simplified flat export only |
| Non-standard `_` tags | Ignored on import |
| Private persons | Excluded from import output and all exports |
| Unicode / UTF-8 | Fully supported |
| GEDCOM 7.0 | Not yet supported (5.5.1 only) |

---

## Tips

- If you are importing a large file (thousands of records), use **Merge mode** so you can safely re-run the import if it is interrupted.
- After import, check the **Conflict Resolver** (*drawer → Conflict Resolver*) — imported sources may conflict with existing facts.
- Exported GEDCOM files can be opened in any standard genealogy software (Gramps, Ancestry, FamilySearch, MacFamilyTree, etc.).
