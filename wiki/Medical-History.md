# Medical History

The Medical History feature tracks **heritable health conditions** across your family tree. This helps you identify genetic patterns, share health context with medical professionals, and build a genealogical medical record that spans generations.

---

## Medical History Screen

*Person detail page → Medical History, or Home drawer → Medical History*

The screen shows all medical conditions recorded for a person (or across all people, depending on the entry point), grouped by **category** or listed per person.

You can:
- Filter by category or person
- Export all records to **PDF** for sharing with a doctor
- Tap a condition to edit or view details

---

## Medical Condition Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String (UUID) | Auto-generated |
| `personId` | String | The person affected |
| `condition` | String | Diagnosis or condition name |
| `category` | String | One of 18 categories (see below) |
| `ageOfOnset` | String? | Age or time period (e.g. "45", "childhood", "post-menopausal") |
| `notes` | String? | Clinical notes, severity, treatment, outcome |
| `attachmentPaths` | List\<String\> | Local file paths to scanned medical records |
| `treeId` | String? | Which tree this record belongs to |

---

## Medical Categories

| Category | Examples |
|----------|---------|
| **Cardiovascular** | Hypertension, coronary artery disease, stroke, arrhythmia |
| **Cancer** | Breast cancer, colorectal cancer, leukaemia, melanoma |
| **Mental Health** | Depression, bipolar disorder, schizophrenia, anxiety disorder |
| **Neurological** | Alzheimer's, Parkinson's, epilepsy, multiple sclerosis |
| **Metabolic / Endocrine** | Type 1/2 diabetes, hypothyroidism, PKU |
| **Autoimmune / Immune** | Lupus, rheumatoid arthritis, coeliac disease, Crohn's disease |
| **Respiratory** | Asthma, COPD, cystic fibrosis |
| **Genetic / Chromosomal** | Down syndrome, Huntington's disease, Marfan syndrome |
| **Musculoskeletal** | Osteoporosis, scoliosis, hereditary arthritis |
| **Gastrointestinal** | Coeliac disease, IBD, hereditary colon polyps |
| **Renal / Urological** | Polycystic kidney disease, hereditary nephritis |
| **Reproductive / Gynaecological** | PCOS, endometriosis, hereditary ovarian conditions |
| **Dermatological** | Psoriasis, eczema, hereditary skin conditions |
| **Sensory** | Hereditary deafness, colour blindness, glaucoma |
| **Haematological / Blood** | Haemophilia, sickle cell disease, thalassaemia |
| **Infectious / Tropical** | Tuberculosis (hereditary susceptibility), malaria |
| **Congenital / Developmental** | Cleft palate, congenital heart defects |
| **Other** | Any condition not in the above categories |

---

## Quick-Fill Suggestions

When adding a condition, the app shows **common condition suggestions** per category to speed up data entry. You can select a suggestion or type a custom name.

---

## Adding a Medical Condition

1. Open a person's detail page → **Medical History** section → **+**.
2. Choose a category.
3. Enter the condition name (or select from suggestions).
4. Optionally add age of onset, notes, and attach any scanned documents.
5. Tap **Save**.

---

## Attaching Medical Records

Tap **+ Attachment** when editing a condition to attach a scanned document (discharge summary, test results, death certificate with cause noted, etc.). Files are stored as local paths — they are not synced.

---

## PDF Export

From the Medical History screen tap the PDF export icon to generate a **family medical history report** covering all conditions across all people in the tree. This document can be shared with a GP or specialist.

---

## Privacy Note

Medical records are some of the most sensitive data in the app. For **living relatives**, consider marking their person record as `isPrivate = true` to ensure their conditions are never included in GEDCOM exports or RootLoop™ sync.
