# Convert the SVG-decoded Google Trends batches into CSVs matching the format
# of the site's own "multiTimeline" export, so downstream cleaning treats every
# batch identically.
#
# Data provenance: trends.google.com explore charts for the search term
# "primary election", weekly, 7/1/2025-7/26/2026, read off the rendered chart
# SVG on 7/27/2026 because scripted download endpoints return 429. The decode
# was validated exactly (0 mismatches over 285 state-weeks) against the one
# batch the site's own CSV download produced; see
# code/check_google_trends_decode.R and notes/google_trends_pull_notes.txt.
import csv
import json
from datetime import date, timedelta
from pathlib import Path

path = Path.home() / "Dropbox" / "AIElectionResearch"
gt_dir = path / "original_data" / "google_trends"

state_names = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
    "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
    "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
    "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
    "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
    "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
    "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
    "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
    "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
    "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
    "WI": "Wisconsin", "WY": "Wyoming", "US": "United States",
}

# The chart's series colors follow the order of the compared geographies.
# Batches 1-3 were rendered in Chrome (first palette); batches 4-11 in the
# Playwright browser, which draws the same series in a different palette.
palettes = [
    ["#4c8df6", "#e46962", "#f7ce52", "#1ea446", "#886cd5"],
    ["#2196f3", "#f44336", "#ffca28", "#43a047", "#9c27b0"],
]

weeks = [date(2025, 6, 29) + timedelta(weeks=i) for i in range(57)]

for decode_file in sorted(gt_dir.glob("svg_decode_batch*.json")):
    batch = json.loads(decode_file.read_text())
    geos = batch["geos"]
    by_stroke = {s["stroke"]: s["vals"] for s in batch["out"]}
    assert len(by_stroke) == len(geos), f"{decode_file.name}: series/geo mismatch"
    palette = next(p for p in palettes if set(by_stroke) <= set(p))

    out_file = gt_dir / decode_file.name.replace("svg_decode_batch", "gt_primary_election_batch").replace(".json", ".csv")
    with open(out_file, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["Category: All categories"])
        w.writerow([])
        w.writerow(["Week"] + [f"primary election: ({state_names[g]})" for g in geos])
        for i, wk in enumerate(weeks):
            row = [wk.isoformat()]
            for j, g in enumerate(geos):
                v = by_stroke[palette[j]][i]
                row.append("" if v is None else (int(v) if float(v).is_integer() else v))
            w.writerow(row)
    print(f"{decode_file.name} -> {out_file.name}")
