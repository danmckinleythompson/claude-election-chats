# claude-election-chats

Do Claude conversations shift toward politics when a state holds its primary?
A difference-in-differences on the Anthropic Economic Index's public state-month
topic shares (April vs May 2026), using the staggered 2026 primary calendar.

Main result: holding a May primary raises a state's politics-topic conversation
share by 0.10 percentage points (s.e. 0.04) on a 0.48 percent base, about 22
percent. Against the empirical null of the same design run on all 210 estimable
topic series, politics ranks 3rd (randomization-inference p = 0.024).

The same design run in Google search data ("primary election" interest, weekly
by state) gives a proportional response about twice as large, and its longer
panel supports the parallel-trends and anticipation checks the two-month AEI
window cannot.

## The post pipeline (Python)

```
python3 code/master.py
```

Two stages, deliberately separate, so a figure can never quietly disagree with
the number it plots:

1. **`code/analysis.py`** — cleaning, panel construction and every estimate.
   Reads the AEI release plus the hand-compiled primary calendar; writes the
   derived CSVs to `modified_data/`. Estimation uses `pyfixest`; each estimate
   is checked against the R pipeline it replaced and the run **fails** rather
   than publishing a number that has drifted.
2. **`code/figures.py`** — reads those CSVs and draws. Writes
   `output/post/post_01..11_*.png`, numbered in presentation order so the whole
   set can be multi-selected and dragged into the post in sequence.

Figures are in the Free Systems house style (off-white ground, deep teal, warm
copper, header rule, footer with the logo and site link). Titles describe what
is plotted and never state the conclusion; the argument lives in the prose.

Python dependencies: pandas, numpy, matplotlib, pyfixest, scipy, openpyxl.

## The search benchmark (still R)

```
Rscript code/master.R
```

The Google Trends robustness check — the same design applied to search volume,
which the Claude estimate is benchmarked against. This is the last R in the
repo and is pending a port to Python. It builds the state-week search panel
from the raw pulls in `original_data/google_trends/` (see its `readme.txt` for
how they were collected), validates them against Google's own export, and
writes the comparison table and figures.

`make_aei_did_table.R` / `make_aei_politics_did.R` / `make_aei_change_hist.R`
recompute estimates `analysis.py` already produces; port or retire them with
the rest. R dependencies: pacman, tidyverse, fixest, glue, broom.

## Running it

The repo runs out of the box. `analysis.py` downloads the AEI release CSV
(~210MB, too large for GitHub) from Hugging Face on first run; everything else
ships with the repo — the hand-compiled primary calendar
(`original_data/primary_dates/`), the hand-compiled primary turnout figures
(`original_data/primary_turnout/`, sources documented line by line in its
readme), and the raw Google Trends pulls (`original_data/google_trends/`).

`code/xarchive/` holds an archived earlier pipeline, including
`convert_trends_svg_decode.py`, which documents how the Trends data was
collected.

## Data notes worth knowing

- AEI values are rounded to 2 decimals, and a missing state-topic cell means
  "below privacy threshold", not zero.
- The request-topic taxonomy is re-clustered in every AEI release, so topic
  shares are never comparable across releases.
- 31 topic names appear at more than one hierarchy level in the June 2026
  release, so anything keyed on a topic must be keyed on (name, level) or
  state-months silently duplicate.
- The Google Trends pulls are batch-normalized: levels are only comparable
  within a pull batch, so the search design uses state fixed effects and logs.
