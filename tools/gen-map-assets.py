#!/usr/bin/env python3
"""Regenerate the world-map assets used by the NordVPN panel.

Writes `core/worldMap.mjs` (land silhouette) and `core/geo.mjs` (country
label points + name lookup) from Natural Earth 110m vectors (public domain,
nvkelso/natural-earth-vector). Both outputs say "regenerate rather than
hand-edit" — this is the regenerator. Run from the plugin root:

    python3 tools/gen-map-assets.py [cache-dir]

Missing GeoJSON inputs are downloaded into the cache dir (default: a temp
directory).
"""

import json
import os
import unicodedata
import re
import subprocess
import sys
import tempfile

BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"
INPUTS = ("ne_110m_land.geojson", "ne_110m_admin_0_countries.geojson")

# Equirectangular window: cut the far south so Antarctica does not eat vertical
# space in a 400 px wide panel.
LAT_MIN, LAT_MAX = -58.0, 84.0

# Smallest bounding-box area (deg^2) kept for the silhouette: at 412 px wide one
# pixel is ~0.87 deg, so anything under this is a speck.
MIN_BOX_AREA = 2.0

# States the 110m generalisation drops (too small) but NordVPN's server list
# offers. Labels match `nordvpn countries`.
MICRO = {
    "AD": (1.6, 42.5),
    "AG": (-61.8, 17.1),
    "MV": (73.5, 3.2),
    "BH": (50.55, 26.05),
    "BB": (-59.6, 13.1),
    "BM": (-64.75, 32.3),
    "CV": (-23.6, 15.1),
    "KY": (-81.25, 19.32),
    "KM": (43.3, -11.6),
    "GU": (144.8, 13.45),
    "HK": (114.15, 22.32),
    "IM": (-4.55, 54.2),
    "JE": (-2.13, 49.21),
    "LI": (9.55, 47.14),
    "MU": (57.55, -20.3),
    "MT": (14.4, 35.9),
    "MC": (7.42, 43.73),
    "LC": (-60.98, 13.9),
    "SC": (55.5, -4.62),
    "SG": (103.82, 1.35),
}

# Labels for the states in MICRO — the 110m vectors have no row for them, so
# NAMES needs these explicitly.
MICRO_NAMES = {
    "Andorra": "AD",
    "Antigua_And_Barbuda": "AG",
    "Maldives": "MV",
    "Bahrain": "BH",
    "Barbados": "BB",
    "Bermuda": "BM",
    "Cape_Verde": "CV",
    "Cayman_Islands": "KY",
    "Comoros": "KM",
    "Guam": "GU",
    "Hong_Kong": "HK",
    "Isle_Of_Man": "IM",
    "Jersey": "JE",
    "Liechtenstein": "LI",
    "Mauritius": "MU",
    "Malta": "MT",
    "Monaco": "MC",
    "Saint_Lucia": "LC",
    "Seychelles": "SC",
    "Singapore": "SG",
}

# Every label `nordvpn countries` prints, verbatim. NAMES gets an entry for
# each one (resolved against the 110m vectors, MICRO_NAMES, or CLI_ALIASES), so
# the runtime lookup stays an exact match and the generator fails loudly if a
# future CLI release adds a country it cannot place on the map.
CLI_LABELS = (
    "Afghanistan",
    "Albania",
    "Algeria",
    "Andorra",
    "Angola",
    "Antigua_And_Barbuda",
    "Argentina",
    "Armenia",
    "Australia",
    "Austria",
    "Azerbaijan",
    "Bahamas",
    "Bahrain",
    "Bangladesh",
    "Barbados",
    "Belgium",
    "Belize",
    "Benin",
    "Bermuda",
    "Bhutan",
    "Bolivia",
    "Bosnia_And_Herzegovina",
    "Botswana",
    "Brazil",
    "Brunei_Darussalam",
    "Bulgaria",
    "Burkina_Faso",
    "Cambodia",
    "Canada",
    "Cape_Verde",
    "Cayman_Islands",
    "Chad",
    "Chile",
    "Colombia",
    "Comoros",
    "Costa_Rica",
    "Croatia",
    "Cyprus",
    "Czech_Republic",
    "Denmark",
    "Dominican_Republic",
    "Ecuador",
    "Egypt",
    "El_Salvador",
    "Estonia",
    "Ethiopia",
    "Fiji",
    "Finland",
    "France",
    "Gambia",
    "Georgia",
    "Germany",
    "Ghana",
    "Greece",
    "Greenland",
    "Guam",
    "Guatemala",
    "Guyana",
    "Honduras",
    "Hong_Kong",
    "Hungary",
    "Iceland",
    "India",
    "Indonesia",
    "Iraq",
    "Ireland",
    "Isle_Of_Man",
    "Israel",
    "Italy",
    "Jamaica",
    "Japan",
    "Jersey",
    "Jordan",
    "Kazakhstan",
    "Kenya",
    "Kuwait",
    "Kyrgyzstan",
    "Lao_Peoples_Democratic_Republic",
    "Latvia",
    "Lebanon",
    "Liberia",
    "Libyan_Arab_Jamahiriya",
    "Liechtenstein",
    "Lithuania",
    "Luxembourg",
    "Madagascar",
    "Malawi",
    "Malaysia",
    "Maldives",
    "Malta",
    "Mauritania",
    "Mauritius",
    "Mexico",
    "Moldova",
    "Monaco",
    "Mongolia",
    "Montenegro",
    "Morocco",
    "Mozambique",
    "Myanmar",
    "Nepal",
    "Netherlands",
    "New_Zealand",
    "Nigeria",
    "North_Macedonia",
    "Norway",
    "Pakistan",
    "Panama",
    "Papua_New_Guinea",
    "Paraguay",
    "Peru",
    "Philippines",
    "Poland",
    "Portugal",
    "Puerto_Rico",
    "Qatar",
    "Romania",
    "Saint_Lucia",
    "Senegal",
    "Serbia",
    "Seychelles",
    "Sierra_Leone",
    "Singapore",
    "Slovakia",
    "Slovenia",
    "Somalia",
    "South_Africa",
    "South_Korea",
    "Spain",
    "Sri_Lanka",
    "Suriname",
    "Sweden",
    "Switzerland",
    "Taiwan",
    "Tajikistan",
    "Tanzania",
    "Thailand",
    "Trinidad_And_Tobago",
    "Tunisia",
    "Turkey",
    "Ukraine",
    "United_Arab_Emirates",
    "United_Kingdom",
    "United_States",
    "Uruguay",
    "Uzbekistan",
    "Venezuela",
    "Vietnam",
    "Yemen",
    "Zambia",
)

# CLI labels whose natural-earth name differs too much for the normalised
# lookup to catch.
CLI_ALIASES = {
    "Cape_Verde": "CV",
    "Libyan_Arab_Jamahiriya": "LY",
}

NAME_KEYS = ("NAME", "NAME_LONG", "ADMIN", "ABBREV", "FORMAL_EN", "BRK_NAME")


def fetch(cache):
    for name in INPUTS:
        path = os.path.join(cache, name)
        if not os.path.exists(path):
            subprocess.run(["curl", "-sS", "-L", "-o", path, f"{BASE}/{name}"], check=True)
    return [json.load(open(os.path.join(cache, n))) for n in INPUTS]


def rings(geometry):
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"][0]]
    if geometry["type"] == "MultiPolygon":
        return [poly[0] for poly in geometry["coordinates"]]
    return []


def normalise(text):
    """`Côte d'Ivoire` -> `COTEDIVOIRE`, matching the CLI's underscore labels."""
    folded = unicodedata.normalize("NFKD", str(text))
    return re.sub(r"[^A-Z]", "", folded.encode("ascii", "ignore").decode().upper())


def shoelace(ring):
    """Area and centroid of a ring; the largest ring per country decides the dot."""
    area = cx = cy = 0.0
    for i in range(len(ring) - 1):
        x0, y0 = ring[i][:2]
        x1, y1 = ring[i + 1][:2]
        cross = x0 * y1 - x1 * y0
        area += cross
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross
    if area == 0:
        return 0.0, ring[0][0], ring[0][1]
    return abs(area) / 2, cx / (3 * area), cy / (3 * area)


def silhouette(land):
    polys = []
    for feature in land["features"]:
        for ring in rings(feature["geometry"]):
            if len(ring) < 5:
                continue
            ys = [c[1] for c in ring]
            if sum(ys) / len(ys) < LAT_MIN + 3:
                continue  # Antarctica and subantarctic specks
            xs = [c[0] for c in ring]
            if (max(xs) - min(xs)) * (max(ys) - min(ys)) < MIN_BOX_AREA:
                continue
            out = []
            for lon, lat in ring:
                qx, qy = round(lon, 1), round(max(lat, LAT_MIN + 0.5), 1)
                if out and abs(out[-1][0] - qx) < 0.05 and abs(out[-1][1] - qy) < 0.05:
                    continue
                out.append([qx, qy])
            if len(out) >= 5:
                polys.append(out)
    return polys


def centroids(countries):
    points, aliases = {}, {}
    for feature in countries["features"]:
        props = feature["properties"]
        code = (props.get("ISO_A2_EH") or props.get("ISO_A2") or "").strip().upper()
        if len(code) != 2 or code == "-9":
            continue
        best = (0.0, 0.0, 0.0)
        for ring in rings(feature["geometry"]):
            area, cx, cy = shoelace(ring)
            if area > best[0]:
                best = (area, cx, cy)
        if best[0] == 0:
            continue
        if code not in points or best[0] > points[code][2]:
            points[code] = (round(best[1], 1), round(best[2], 1), best[0])
        for key in NAME_KEYS:
            value = props.get(key)
            if value:
                aliases.setdefault(normalise(value), code)
    for label, code in MICRO_NAMES.items():
        aliases[normalise(label)] = code
    for label, code in CLI_ALIASES.items():
        aliases[normalise(label)] = code
    return {code: (v[0], v[1]) for code, v in points.items()}, aliases


WORLD_HEADER = """// Generated by tools/gen-map-assets.py from Natural Earth 110m land
// (public domain, nvkelso/natural-earth-vector). Polygons are [lon, lat]
// pairs in the equirectangular window below; regenerate rather than
// hand-edit.
"""

GEO_HEADER = """// Generated by tools/gen-map-assets.py from Natural Earth 110m admin-0
// countries (public domain). A country's point is the centroid of its largest
// ring, so the US dot lands in the contiguous states instead of mid-Pacific and
// Japan's lands on Honshu. MICRO holds the small states that 110m generalisation
// drops but NordVPN still offers (Singapore, Hong Kong, Bermuda, ...).
"""


WORLD_TAIL = """
// [lon, lat] -> pixel position inside a width x height equirectangular map.
export function project(lonLat, width, height) {
  if (!lonLat) return null;
  const [lon, lat] = lonLat;
  return {
    x: (lon + 180) / 360 * width,
    y: (LAT_MAX - Math.min(Math.max(lat, LAT_MIN), LAT_MAX)) / (LAT_MAX - LAT_MIN) * height
  };
}

// Aspect ratio (height / width) of the map window, so the silhouette never
// stretches.
export function mapAspect() {
  return (LAT_MAX - LAT_MIN) / 360;
}
"""


def write_world(path, polys):
    body = ",\n".join("[" + ",".join(f"[{lon},{lat}]" for lon, lat in poly) + "]" for poly in polys)
    with open(path, "w") as fh:
        fh.write(WORLD_HEADER)
        fh.write(f"export const LAT_MIN = {LAT_MIN};\n")
        fh.write(f"export const LAT_MAX = {LAT_MAX};\n\n")
        fh.write("export const LAND = [\n")
        fh.write(body)
        fh.write("\n];\n")
        fh.write(WORLD_TAIL)
    return os.path.getsize(path)


def write_geo(path, points, aliases):
    pts = ",\n".join(
        f"  {code}: [{points[code][0]}, {points[code][1]}]" for code in sorted(points)
    )
    names = ",\n".join(
        f"  '{key}': '{aliases[key]}'" for key in sorted(aliases) if "'" not in key
    )
    micro = ",\n".join(f"  {code}: [{lon}, {lat}]" for code, (lon, lat) in sorted(MICRO.items()))
    with open(path, "w") as fh:
        fh.write(GEO_HEADER)
        fh.write("\n// ISO-2 country code -> [lon, lat].\n")
        fh.write("export const POINTS = {\n")
        fh.write(pts)
        fh.write("\n};\n")
        fh.write("\n// Normalised country label -> ISO-2 code (`United_States` -> `US`).\n")
        fh.write("export const NAMES = {\n")
        fh.write(names)
        fh.write("\n};\n")
        fh.write("\n// ISO-2 -> [lon, lat], states missing from the 110m vectors.\n")
        fh.write("export const MICRO = {\n")
        fh.write(micro)
        fh.write("\n};\n")
        fh.write(TAIL)
    return os.path.getsize(path)


TAIL = """
// Labels arrive as `United_States`, `Bosnia_And_Herzegovina`, ... — collapse
// them to the same shape the generated NAMES keys use.
export function normalise(text) {
  return String(text ?? "").toUpperCase().replace(/[^A-Z]/g, "");
}

// A country label (`United_States`) or a bare ISO-2 code -> ISO-2 code.
export function codeOf(label) {
  const key = String(label ?? "");
  if (/^[A-Za-z]{2}$/.test(key)) return key.toUpperCase();
  // NAMES carries an entry for every label the NordVPN CLI prints (plus the
  // 110m vector names), so an exact lookup is enough — fuzzy prefix matching
  // would map short labels onto unrelated countries (`Malta` -> `Malawi`).
  return NAMES[normalise(key)] ?? "";
}

// Country code (or label) -> [lon, lat] for the map dot, or null.
export function point(codeOrLabel) {
  const code = codeOf(codeOrLabel);
  return MICRO[code] ?? POINTS[code] ?? null;
}

"""


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    cache = sys.argv[1] if len(sys.argv) > 1 else tempfile.mkdtemp(prefix="ne-110m-")
    land, countries = fetch(cache)
    polys = silhouette(land)
    points, aliases = centroids(countries)
    # Every CLI label must land somewhere on the map: an unresolved label means
    # the runtime would fall back to the hostname's country code, and a label
    # whose code has no geometry means no dot at all.
    unresolved = [l for l in CLI_LABELS if normalise(l) not in aliases]
    if unresolved:
        raise SystemExit(f"CLI labels with no country match: {unresolved}")
    placeless = sorted({
        aliases[normalise(l)] for l in CLI_LABELS
        if aliases[normalise(l)] not in points and aliases[normalise(l)] not in MICRO
    })
    if placeless:
        raise SystemExit(f"countries with no map point (add to MICRO): {placeless}")
    world = write_world(os.path.join(root, "core", "worldMap.mjs"), polys)
    geo = write_geo(os.path.join(root, "core", "geo.mjs"), points, aliases)
    print(f"core/worldMap.mjs  {world} bytes, {len(polys)} polygons")
    print(f"core/geo.mjs       {geo} bytes, {len(points)} country points, {len(aliases)} names")


if __name__ == "__main__":
    main()
