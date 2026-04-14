#!/usr/bin/env python3
import argparse
import csv
import re
import subprocess
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

try:
    import pycountry
except ImportError:
    print('pycountry is not installed. Install it with: python -m pip install pycountry', file=sys.stderr)
    raise

try:
    import pycountry_convert as pc
except ImportError:
    pc = None

CONTINENT_NAMES = {
    'AF': 'Africa',
    'AN': 'Antarctica',
    'AS': 'Asia',
    'EU': 'Europe',
    'NA': 'North America',
    'OC': 'Oceania',
    'SA': 'South America',
}


def slugify(text):
    text = (text or '').strip().lower()
    text = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode('ascii')
    text = re.sub(r"(\w)['’](\w)", r'\1\2', text)
    text = re.sub(r'[^a-z0-9\s-]', '-', text)
    text = re.sub(r'[-\s]+', '-', text).strip('-')
    return text


def get_country_name(country):
    return getattr(country, 'official_name', None) or getattr(country, 'name', '')


def get_continent_name(alpha2):
    if pc is None:
        return ''
    try:
        code = pc.country_alpha2_to_continent_code(alpha2)
        return CONTINENT_NAMES.get(code, code)
    except Exception:
        return ''


def build_indexes():
    subdivisions = list(pycountry.subdivisions)
    by_code = {s.code: s for s in subdivisions}
    children = defaultdict(list)
    for s in subdivisions:
        if getattr(s, 'parent_code', None):
            children[s.parent_code].append(s)
    return subdivisions, by_code, children


def subdivision_level(sub, by_code):
    level = 1
    seen = set()
    current = sub
    while getattr(current, 'parent_code', None):
        parent_code = current.parent_code
        if parent_code in seen:
            break
        seen.add(parent_code)
        parent = by_code.get(parent_code)
        if parent is None:
            break
        level += 1
        current = parent
    return level


def ancestor_chain(sub, by_code):
    chain = [sub]
    seen = {sub.code}
    current = sub
    while getattr(current, 'parent_code', None):
        parent = by_code.get(current.parent_code)
        if parent is None or parent.code in seen:
            break
        chain.append(parent)
        seen.add(parent.code)
        current = parent
    chain.reverse()
    return chain


def leaf_nodes(country_subs, children):
    return [sub for sub in country_subs if not children.get(sub.code)]


def place_type_for_leaf(leaf, level):
    raw_type = getattr(leaf, 'type', '') or ''
    if raw_type:
        return raw_type
    return f'admin_level_{level}'


def make_parent_slug(continent, country_name, parent_chain):
    parts = [slugify(continent), slugify(country_name)] + [slugify(node.name) for node in parent_chain]
    return '/'.join([p for p in parts if p])


def make_parent_import_key(country_code, parent, parent_level, continent, country_name, parent_chain):
    if parent is None:
        return f'{country_code}::country'
    parent_slug = make_parent_slug(continent, country_name, parent_chain)
    key = '::'.join([p for p in [country_code, parent.code or '', str(parent_level), slugify(parent.name)] if p])
    if parent_slug:
        key = key + '::' + parent_slug.replace('/', '::')
    return key


def build_rows(include_non_leaf=False):
    countries = sorted(list(pycountry.countries), key=lambda c: c.alpha_2)
    subdivisions, by_code, children = build_indexes()
    subs_by_country = defaultdict(list)
    for s in subdivisions:
        subs_by_country[s.country_code].append(s)

    rows = []
    seen_import_keys = set()

    for country in countries:
        ccode = country.alpha_2
        cname = get_country_name(country)
        continent = get_continent_name(ccode)
        country_subs = sorted(subs_by_country.get(ccode, []), key=lambda s: s.code)

        if not country_subs:
            display_name = ', '.join([p for p in [cname, continent] if p])
            slug = '/'.join([p for p in [slugify(continent), slugify(cname)] if p])
            import_key = f'{ccode}::country'
            rows.append({
                'continent': continent,
                'country_code': ccode,
                'country_name': cname,
                'level1_name': '',
                'level1_type': '',
                'level2_name': '',
                'level2_type': '',
                'level3_name': '',
                'level3_type': '',
                'name': cname,
                'type': 'country',
                'parent_name': continent,
                'parent_type': 'continent' if continent else '',
                'parent_slug': slugify(continent) if continent else '',
                'parent_import_key': '',
                'display_name': display_name,
                'slug': slug,
                'import_key': import_key,
                'leaf_level': 0,
                'leaf_code': '',
                'leaf_type': '',
                'path': ' > '.join([p for p in [continent, cname] if p]),
            })
            seen_import_keys.add(import_key)
            continue

        targets = leaf_nodes(country_subs, children)
        if include_non_leaf:
            seen_codes = {s.code for s in targets}
            for s in country_subs:
                if s.code not in seen_codes:
                    targets.append(s)
            targets = sorted(targets, key=lambda s: (subdivision_level(s, by_code), s.code))
        else:
            targets = sorted(targets, key=lambda s: (subdivision_level(s, by_code), s.code))

        for leaf in targets:
            chain = ancestor_chain(leaf, by_code)
            chain_levels = {i + 1: node for i, node in enumerate(chain)}
            level1 = chain_levels.get(1)
            level2 = chain_levels.get(2)
            level3 = chain_levels.get(3)
            leaf_level = subdivision_level(leaf, by_code)
            leaf_type = place_type_for_leaf(leaf, leaf_level)

            parent = by_code.get(leaf.parent_code) if getattr(leaf, 'parent_code', None) else None
            if parent is not None:
                parent_name = parent.name
                parent_type = getattr(parent, 'type', '') or f'admin_level_{max(1, leaf_level - 1)}'
                parent_chain = ancestor_chain(parent, by_code)
                parent_level = subdivision_level(parent, by_code)
                parent_slug = make_parent_slug(continent, cname, parent_chain)
                parent_import_key = make_parent_import_key(ccode, parent, parent_level, continent, cname, parent_chain)
            else:
                parent_name = cname
                parent_type = 'country'
                parent_slug = '/'.join([p for p in [slugify(continent), slugify(cname)] if p])
                parent_import_key = f'{ccode}::country'

            hierarchy_names = [continent, cname] + [node.name for node in chain]
            display_name = ', '.join([p for p in reversed(hierarchy_names) if p])
            slug_parts = [slugify(continent), slugify(cname)] + [slugify(node.name) for node in chain]
            slug = '/'.join([p for p in slug_parts if p])

            import_key = '::'.join([p for p in [ccode, leaf.code or '', str(leaf_level), slugify(leaf.name)] if p])
            if slug:
                import_key = import_key + '::' + slug.replace('/', '::')
            if import_key in seen_import_keys:
                import_key = import_key + '::' + slugify(leaf_type)
            seen_import_keys.add(import_key)

            rows.append({
                'continent': continent,
                'country_code': ccode,
                'country_name': cname,
                'level1_name': level1.name if level1 else '',
                'level1_type': getattr(level1, 'type', '') if level1 else '',
                'level2_name': level2.name if level2 else '',
                'level2_type': getattr(level2, 'type', '') if level2 else '',
                'level3_name': level3.name if level3 else '',
                'level3_type': getattr(level3, 'type', '') if level3 else '',
                'name': leaf.name,
                'type': leaf_type,
                'parent_name': parent_name,
                'parent_type': parent_type,
                'parent_slug': parent_slug,
                'parent_import_key': parent_import_key,
                'display_name': display_name,
                'slug': slug,
                'import_key': import_key,
                'leaf_level': leaf_level,
                'leaf_code': leaf.code,
                'leaf_type': leaf_type,
                'path': ' > '.join([p for p in hierarchy_names if p]),
            })
    return rows


def write_csv(rows, path):
    with open(path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                'continent', 'country_code', 'country_name',
                'level1_name', 'level1_type',
                'level2_name', 'level2_type',
                'level3_name', 'level3_type',
                'name', 'type', 'parent_name', 'parent_type', 'parent_slug', 'parent_import_key',
                'display_name', 'slug', 'import_key',
                'leaf_level', 'leaf_code', 'leaf_type', 'path'
            ]
        )
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description='Export a Vetviona-ready genealogy CSV from pycountry subdivision hierarchies.')
    parser.add_argument('--csv-output', default='vetviona_places_import.csv')
    parser.add_argument('--include-non-leaf', action='store_true', help='Also emit non-leaf subdivisions, not just terminal places.')
    args = parser.parse_args()

    rows = build_rows(include_non_leaf=args.include_non_leaf)
    output = Path(args.csv_output)
    output.parent.mkdir(parents=True, exist_ok=True)
    write_csv(rows, output)
    print(f'Wrote {len(rows)} rows to {output}')


if __name__ == '__main__':
    main()
