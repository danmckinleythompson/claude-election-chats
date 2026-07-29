# AIElectionResearch

Do Claude conversations shift toward politics when a state holds its primary?
Diff-in-differences on the Anthropic Economic Index state-month topic shares
(April vs May 2026), using the staggered 2026 primary calendar.

**Language:** R (tidyverse, fixest). Entry point: `code/master.R` — four steps:
clean -> prep -> table (which also runs the estimation) -> two figures.
Deliverable: `draft/aei_memo/aei_memo.pdf`.

## Data facts worth knowing

- Only `original_data/anthropic_economic_index/release_2026_06_26/` is used
  (CC-BY, Hugging Face `Anthropic/EconomicIndex`): monthly Apr + May 2026,
  state-level request-topic shares. Outcome = "Politics and public record"
  (level 1); the narrow "Elections" topic is published for too few states.
- AEI values are rounded to 2 decimals; a missing state-topic cell means
  "below privacy threshold," not zero. Topic taxonomies are re-clustered every
  release — never compare topic shares across releases.
- `original_data/primary_dates/primary_dates_2026.csv` is hand-compiled
  (NCSL + FVAP, they agree). Watch-outs: LA's May 16 primary is Senate/local
  only; TN holds county primaries in early May despite its Aug 6 statewide
  date; WI had an Apr 7 spring election.
- Main estimate: +0.10 pp (SE 0.04) on a 0.48% control base (~22%); robust to
  dropping June controls, logs, and dropping LA/WI/DC/TN.

## Archived (kept, not deleted)

- `code/xarchive/`: the full earlier pipeline — Google Trends collection
  (SVG-decode approach, see notes/google_trends_pull_notes.txt), the search
  event study, national series figures, and the four-release AEI extraction.
- Raw Google Trends pulls remain in `original_data/_archive/google_trends/`
  (immutable); derived Trends data are in `modified_data/_archive/`.
