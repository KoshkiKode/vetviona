#!/usr/bin/env python3
"""
build_geonames_db.py – rebuild app/assets/geonames_cities.db.

Usage (recommended – no internet required):
    python tools/build_geonames_db.py --from-csv tools/vetviona_places_import.csv

Usage (original – downloads ~350 MB from GeoNames):
    python tools/build_geonames_db.py

The CSV mode reads the pre-generated pycountry subdivision CSV produced by
tools/generate_vetviona_places_csv_v2.py and converts it directly into the
SQLite database.  This is the preferred approach because it works offline,
completes in seconds, and requires no disk space beyond the CSV itself.

The GeoNames download mode fetches the full allCountries.txt dataset and
filters it to administrative divisions and populated places.  This produces a
much larger database (~25 MB, ~1 M rows) but requires internet access and
~500 MB of temporary disk space.

The resulting database replaces app/assets/geonames_cities.db and is
automatically included in the app bundle via the existing `assets/` wildcard
in pubspec.yaml.

Requirements:
    pip install pycountry            # for --from-csv mode
    pip install requests pycountry  # for GeoNames download mode

Data license (GeoNames mode):
    GeoNames data is licensed under Creative Commons Attribution 4.0.
    See https://www.geonames.org/about.html
"""

import argparse
import csv
import io
import os
import sqlite3
import sys
import zipfile

try:
    import pycountry
except ImportError:
    sys.exit("pycountry is required: pip install pycountry")

GEONAMES_DUMP_URL = "https://download.geonames.org/export/dump/allCountries.zip"
ADMIN1_URL = "https://download.geonames.org/export/dump/admin1CodesASCII.txt"
ADMIN2_URL = "https://download.geonames.org/export/dump/admin2Codes.txt"

OUTPUT_DB = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "app", "assets", "geonames_cities.db",
)

# Feature codes to include
# ADM1/2/3/4 = administrative divisions; PPL* = populated places
INCLUDE_FEATURE_CODES = {
    "ADM1", "ADM2", "ADM3", "ADM4", "ADMD",
    "PPL", "PPLA", "PPLA2", "PPLA3", "PPLA4",
    "PPLC",   # capital
    "PPLF",   # farm village
    "PPLS",   # populated places
    "STLMT",  # israeli settlement (genealogy-relevant)
}

CONTINENT_MAP = {
    "AF": "Africa", "NA": "Americas", "SA": "Americas", "OC": "Oceania",
    "AS": "Asia", "EU": "Europe", "AN": "Other",
}


def build_country_info():
    """Return mapping iso2 -> {name, iso3, continent}."""
    info = {}
    for c in pycountry.countries:
        cc = c.alpha_2
        iso3 = getattr(c, "alpha_3", "")
        info[cc] = {"name": c.name, "iso3": iso3, "continent": "Unknown"}
    return info


def download_text(url, label):
    print(f"  Downloading {label}…", end=" ", flush=True)
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    print(f"{len(r.content) // 1024} KB")
    return r.text


def load_admin1(text):
    """Return dict: 'CC.admin1code' -> name."""
    mapping = {}
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            mapping[parts[0]] = parts[1]
    return mapping


def load_admin2(text):
    """Return dict: 'CC.admin1code.admin2code' -> name."""
    mapping = {}
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            mapping[parts[0]] = parts[1]
    return mapping


def build_db(all_countries_zip_bytes, admin1_map, admin2_map, country_info):
    """Parse allCountries.txt from zip bytes and write SQLite DB."""
    os.makedirs(os.path.dirname(OUTPUT_DB), exist_ok=True)
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    conn = sqlite3.connect(OUTPUT_DB)
    cur = conn.cursor()

    cur.execute("""CREATE TABLE places (
        id INTEGER PRIMARY KEY,
        geonameid INTEGER,
        name TEXT NOT NULL,
        country TEXT NOT NULL,
        iso3 TEXT,
        continent TEXT,
        state TEXT,
        county TEXT,
        feature_code TEXT,
        population INTEGER,
        latitude REAL,
        longitude REAL
    )""")
    cur.execute("CREATE INDEX idx_name ON places(name COLLATE NOCASE)")
    cur.execute("CREATE INDEX idx_country ON places(country)")
    cur.execute("CREATE INDEX idx_continent ON places(continent)")

    COLUMNS = [
        "geonameid", "name", "asciiname", "alternatenames",
        "latitude", "longitude", "feature_class", "feature_code",
        "country_code", "cc2", "admin1_code", "admin2_code", "admin3_code",
        "admin4_code", "population", "elevation", "dem", "timezone",
        "modification_date",
    ]

    batch = []
    inserted = 0
    skipped = 0

    print("  Parsing allCountries.txt…", end=" ", flush=True)
    with zipfile.ZipFile(io.BytesIO(all_countries_zip_bytes)) as zf:
        with zf.open("allCountries.txt") as fh:
            reader = csv.reader(io.TextIOWrapper(fh, encoding="utf-8"), delimiter="\t")
            for row in reader:
                if len(row) < 19:
                    continue
                d = dict(zip(COLUMNS, row))
                fc = d["feature_code"]
                if fc not in INCLUDE_FEATURE_CODES:
                    skipped += 1
                    continue

                cc = d["country_code"]
                info = country_info.get(cc, {"name": cc, "iso3": "", "continent": "Unknown"})
                admin1_key = f"{cc}.{d['admin1_code']}"
                admin2_key = f"{cc}.{d['admin1_code']}.{d['admin2_code']}"
                state = admin1_map.get(admin1_key, "")
                county = admin2_map.get(admin2_key, "")

                try:
                    pop = int(d["population"])
                except ValueError:
                    pop = 0
                try:
                    lat = float(d["latitude"])
                    lng = float(d["longitude"])
                except ValueError:
                    lat = lng = 0.0

                batch.append((
                    int(d["geonameid"]),
                    d["name"],
                    info["name"],
                    info["iso3"],
                    info["continent"],
                    state,
                    county,
                    fc,
                    pop,
                    lat,
                    lng,
                ))
                inserted += 1
                if len(batch) >= 10_000:
                    cur.executemany(
                        """INSERT INTO places
                           (geonameid, name, country, iso3, continent, state, county,
                            feature_code, population, latitude, longitude)
                           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                        batch,
                    )
                    batch.clear()

    if batch:
        cur.executemany(
            """INSERT INTO places
               (geonameid, name, country, iso3, continent, state, county,
                feature_code, population, latitude, longitude)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            batch,
        )

    print(f"{inserted:,} rows ({skipped:,} skipped)")

    print("  Building FTS5 index…", end=" ", flush=True)
    cur.execute("""CREATE VIRTUAL TABLE places_fts USING fts5(
        name, country, state, county,
        content='places', content_rowid='id'
    )""")
    cur.execute("""INSERT INTO places_fts(rowid, name, country, state, county)
                   SELECT id, name, country,
                          COALESCE(state, ''), COALESCE(county, '')
                   FROM places""")
    print("done")

    conn.commit()
    conn.close()

    size_mb = os.path.getsize(OUTPUT_DB) / 1024 / 1024
    print(f"  Written {OUTPUT_DB} ({size_mb:.1f} MB, {inserted:,} places)")


def build_db_from_csv(csv_path):
    """Build the SQLite DB from a pre-generated pycountry CSV file.

    The CSV must have the columns produced by generate_vetviona_places_csv_v2.py:
        continent, country_code, country_name, level1_name, name, ...

    iso3 codes are resolved from pycountry using country_code.
    population, latitude, and longitude are set to 0 as the CSV does not
    contain that information.
    """
    iso3_map = {c.alpha_2: getattr(c, "alpha_3", "") for c in pycountry.countries}

    os.makedirs(os.path.dirname(OUTPUT_DB), exist_ok=True)
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    conn = sqlite3.connect(OUTPUT_DB)
    cur = conn.cursor()

    cur.execute("""CREATE TABLE places (
        id INTEGER PRIMARY KEY,
        geonameid INTEGER,
        name TEXT NOT NULL,
        country TEXT NOT NULL,
        iso3 TEXT,
        continent TEXT,
        state TEXT,
        population INTEGER,
        latitude REAL,
        longitude REAL
    )""")
    cur.execute("CREATE INDEX idx_name ON places(name COLLATE NOCASE)")
    cur.execute("CREATE INDEX idx_country ON places(country)")
    cur.execute("CREATE INDEX idx_continent ON places(continent)")

    batch = []
    inserted = 0

    with open(csv_path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            cc = row["country_code"]
            iso3 = iso3_map.get(cc, "")
            continent = row["continent"] or "Unknown"
            country = row["country_name"]
            name = row["name"]
            state = row["level1_name"]

            if not name or not country:
                continue

            batch.append((0, name, country, iso3, continent, state, 0, 0.0, 0.0))
            inserted += 1

            if len(batch) >= 10_000:
                cur.executemany(
                    """INSERT INTO places
                       (geonameid, name, country, iso3, continent, state,
                        population, latitude, longitude)
                       VALUES (?,?,?,?,?,?,?,?,?)""",
                    batch,
                )
                batch.clear()

    if batch:
        cur.executemany(
            """INSERT INTO places
               (geonameid, name, country, iso3, continent, state,
                population, latitude, longitude)
               VALUES (?,?,?,?,?,?,?,?,?)""",
            batch,
        )

    print(f"  {inserted:,} rows inserted")

    print("  Building FTS5 index…", end=" ", flush=True)
    cur.execute("""CREATE VIRTUAL TABLE places_fts USING fts5(
        name, country, state,
        content='places', content_rowid='id'
    )""")
    cur.execute("""INSERT INTO places_fts(rowid, name, country, state)
                   SELECT id, name, country, COALESCE(state, '')
                   FROM places""")
    print("done")

    conn.commit()
    conn.close()

    size_mb = os.path.getsize(OUTPUT_DB) / 1024 / 1024
    print(f"  Written {OUTPUT_DB} ({size_mb:.1f} MB, {inserted:,} places)")


def main():
    parser = argparse.ArgumentParser(
        description="Rebuild app/assets/geonames_cities.db"
    )
    parser.add_argument(
        "--from-csv",
        metavar="CSV",
        default=None,
        help=(
            "Path to the pycountry CSV (produced by generate_vetviona_places_csv_v2.py). "
            "Using this flag avoids any internet download and completes in seconds. "
            "Default CSV path: tools/vetviona_places_import.csv"
        ),
    )
    args = parser.parse_args()

    # If --from-csv is given without a value it stays None; treat a bare flag
    # invocation that passed the default as using the bundled CSV.
    csv_path = args.from_csv

    if csv_path is not None:
        # ── CSV mode ──────────────────────────────────────────────────────────
        print("=== Vetviona – CSV-based places database builder ===")
        print(f"Input:  {csv_path}")
        print(f"Output: {OUTPUT_DB}\n")
        if not os.path.exists(csv_path):
            sys.exit(f"CSV file not found: {csv_path}")
        print("Building SQLite database from CSV…")
        build_db_from_csv(csv_path)
        print("\nDone! Rebuild the app to pick up the new database.")
        return

    # ── GeoNames download mode ────────────────────────────────────────────────
    try:
        import requests  # noqa: F401 – only needed in this path
    except ImportError:
        sys.exit("requests is required for GeoNames download mode: pip install requests")

    print("=== Vetviona – Full GeoNames database builder ===")
    print(f"Output: {OUTPUT_DB}\n")

    print("Step 1/4 – Loading country info from pycountry…")
    country_info = build_country_info()
    print(f"  {len(country_info)} countries loaded")

    print("Step 2/4 – Downloading admin1 and admin2 code tables…")
    admin1_text = download_text(ADMIN1_URL, "admin1CodesASCII.txt")
    admin2_text = download_text(ADMIN2_URL, "admin2Codes.txt")
    admin1_map = load_admin1(admin1_text)
    admin2_map = load_admin2(admin2_text)
    print(f"  admin1: {len(admin1_map):,}  admin2: {len(admin2_map):,}")

    print("Step 3/4 – Downloading allCountries.zip (≈350 MB)…")
    r = requests.get(GEONAMES_DUMP_URL, stream=True, timeout=300)
    r.raise_for_status()
    chunks = []
    downloaded = 0
    for chunk in r.iter_content(chunk_size=1 << 20):
        chunks.append(chunk)
        downloaded += len(chunk)
        print(f"\r  {downloaded // (1 << 20)} MB downloaded", end="", flush=True)
    print()
    zip_bytes = b"".join(chunks)
    print(f"  {len(zip_bytes) // (1 << 20)} MB downloaded")

    print("Step 4/4 – Building SQLite database…")
    build_db(zip_bytes, admin1_map, admin2_map, country_info)

    print("\nDone! Rebuild the app to pick up the new database.")


if __name__ == "__main__":
    main()
