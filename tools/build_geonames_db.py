#!/usr/bin/env python3
"""
build_geonames_db.py – rebuild app/assets/geonames_cities.db from full GeoNames data.

Usage:
    python tools/build_geonames_db.py

This script downloads the full GeoNames allCountries.txt dataset (~350 MB
uncompressed, ~1.5 B place entries) and filters it to administrative divisions
(ADM1–ADM4) and populated places (PPL, PPLA, PPLC, etc.) to create a
comprehensive SQLite database suitable for genealogy research.

The resulting database replaces app/assets/geonames_cities.db and is
automatically included in the app bundle via the existing `assets/` wildcard
in pubspec.yaml.

Requirements:
    pip install requests pycountry

Disk space:
    ~500 MB during build (download + unzip), ~25 MB final DB.

Data license:
    GeoNames data is licensed under Creative Commons Attribution 4.0.
    See https://www.geonames.org/about.html
"""

import csv
import io
import os
import sqlite3
import sys
import zipfile

try:
    import requests
except ImportError:
    sys.exit("requests is required: pip install requests")

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


def main():
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
