# AIElectionResearch

Do Claude conversations shift toward politics when a state holds its primary?
A difference-in-differences on the Anthropic Economic Index's public state-month
topic shares (April vs May 2026), using the staggered 2026 primary calendar.

Main result: holding a May primary raises a state's politics-topic conversation
share by 0.10 percentage points (s.e. 0.04) on a 0.48 percent base, about 22
percent. Write-up: `draft/aei_memo/aei_memo.pdf`.

## Pipeline

`code/master.R` runs everything in order:

1. `clean_aei_election_topics.R` - extract topic shares from the AEI June 2026
   release (CC-BY, https://huggingface.co/datasets/Anthropic/EconomicIndex)
2. `prep_aei_did_data.R` - merge hand-compiled 2026 primary dates (NCSL/FVAP),
   build the treatment and the balanced 30-state panel
3. `make_aei_did_table.R` - estimate the three specifications, write the table
4. `make_aei_politics_did.R` / `make_aei_change_hist.R` - the two figures

Data are not tracked in git. Raw inputs go in `original_data/` (the AEI release
CSV and `primary_dates/primary_dates_2026.csv`); the cleaning scripts rebuild
everything in `modified_data/` from there.

`code/xarchive/` holds an archived earlier pipeline that benchmarked the result
against a Google Trends event study around the same primaries; the frozen full
paper draft is in `draft/full_paper_draft_jul2026/`.
