# AIElectionResearch

Replication repo for the Free Systems post "Quantifying the Information
Layer" (with Andy Hall): descriptives on political Claude usage plus the
primary-timing diff-in-diff, all from the AEI June 2026 release.

**Language:** R (tidyverse, fixest). Entry point: `code/master.R` —
clean -> prep -> estimate -> one make_ script per blog figure (11 figures,
styling in `_blog_style.R` matched to the post's tan/teal charts).
The post's Google Doc is the source of truth for which figures exist.

## Key results

- Claude DiD: +0.10 pp (SE 0.04) on a 0.48% base (~22%); logs +0.24 (SE 0.09).
  Robust to dropping June controls, logs, and dropping LA/WI/DC/TN.
- Search, same design/sample/logs: +0.49 (SE 0.17) — about twice the
  proportional response. Pre-trends parallel (joint p=0.10 vs March); April
  already +0.63 (anticipation), so the DiDs are lower bounds.

## Data facts worth knowing

- Only `original_data/anthropic_economic_index/release_2026_06_26/` is used
  (CC-BY, Hugging Face `Anthropic/EconomicIndex`): monthly Apr + May 2026,
  state-level request-topic shares. Outcome = "Politics and public record"
  (level 1); the narrow "Elections" topic is published for too few states.
- AEI values are rounded to 2 decimals; a missing state-topic cell means
  "below privacy threshold," not zero. Topic taxonomies are re-clustered every
  release — never compare topic shares across releases.
- 31 request-topic names appear at MORE THAN ONE hierarchy level in the June
  2026 release (found by AH) — always filter topics on (name, level), never
  name alone, or state-months silently duplicate.
- `original_data/google_trends/` (raw weekly pulls, shipped in git) is
  batch-normalized: levels only comparable within a pull batch; use state FE +
  logs. Collection method documented in its readme.txt.
- `original_data/primary_dates/primary_dates_2026.csv` is hand-compiled
  (NCSL + FVAP, they agree). Watch-outs: LA's May 16 primary is Senate/local
  only; TN holds county primaries in early May despite its Aug 6 statewide
  date; WI had an Apr 7 spring election.

## Archived (kept locally, untracked in git since the blog-post refocus)

- `code/xarchive/`: everything superseded — the Google Trends pipeline
  (SVG-decode collection, search DiD/event study), the memo-era AEI scripts,
  the Free Systems blue/gray styling, and Andy's original memo pipeline
  (`xarchive/memo/`).
- `draft/`: the aei_memo, Andy's politics_memo, and the frozen full paper —
  all superseded by the blog post, all still in Dropbox.
- `output/_archive/` and `modified_data/_archive/`: superseded exhibits and
  derived data. Raw Google Trends pulls: `original_data/google_trends/`
  (untracked) and `original_data/_archive/google_trends/`.
