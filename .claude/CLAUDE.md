# AIElectionResearch

Do Claude conversations shift toward politics when a state holds its primary?
Diff-in-differences on the Anthropic Economic Index state-month topic shares
(April vs May 2026), using the staggered 2026 primary calendar, benchmarked
against the same design in Google search data.

**Language:** R (tidyverse, fixest). Entry point: `code/master.R` —
clean -> prep -> tables (which also run the estimation) -> figures, for both
the Claude and search sides. Deliverable: `draft/aei_memo/aei_memo.pdf`.
`code/memo/master_memo.R` is Andy Hall's separate descriptive memo pipeline
(merged from PR #1); don't fold it into master.R.

**R computes, Python draws.** `01_memo_stats.R` owns estimation, tables and
macros and writes CSVs to `output/memo/`. `code/memo/figures.py` owns EVERY
chart and reads only those CSVs. Superseded and deletable: `02_memo_figures.R`,
`fig_defs.R`, `03_post_table_images.R`, `03_post_images.R`, `05_post_brand.R`,
`04_fig_politics_in_context.R`. (`05_cross_release_series.R` and
`05_subtopic_did.R` are unrelated and still live.)

**Memo vs post.** One builder per figure, rendered twice. The memo
(`draft/politics_memo`) gets plain PDFs, keeps its tables, and titles via LaTeX
`\caption`. The post (`output/post/post_01..08_*.png`, dragged into a Google
Doc in filename order) is **figures only** -- every finding is carried by a
figure -- in the Free Systems house style: off-white `#FAFAF7`, teal
`#2B5B6C`, copper `#C4703E`, header rule + title + subtitle, footer with the
logo and `freesystems.substack.com`. Brand spec: `~/freesystems/CLAUDE.md`.
Figure titles **describe what is plotted and never state the conclusion**;
subtitles carry only neutral orienting facts (geography, month, what does not
sum). The argument goes in the post's prose, not on the chart.

**Never clean `output/post/` by exclusion.** Other scripts write figures there.
Delete stale assets from an explicit list (see `figures.py`); a
delete-what-I-don't-recognise rule destroyed `fig_cross_release_series.png`.

## Key results

- Claude DiD: +0.10 pp (SE 0.04) on a 0.48% base (~22%); logs +0.24 (SE 0.09).
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
- Main estimate: +0.10 pp (SE 0.04) on a 0.48% control base (~22%); robust to
  dropping June controls, logs, and dropping LA/WI/DC/TN.

## Archived (kept, not deleted)

- `code/xarchive/`: the full earlier pipeline — Google Trends collection
  (SVG-decode approach, see notes/google_trends_pull_notes.txt), the search
  event study, national series figures, and the four-release AEI extraction.
- Raw Google Trends pulls remain in `original_data/_archive/google_trends/`
  (immutable); derived Trends data are in `modified_data/_archive/`.
