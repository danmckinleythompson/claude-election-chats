# claude-election-chats

Do Claude conversations shift toward politics when a state holds its primary?
A difference-in-differences on the Anthropic Economic Index's public state-month
topic shares (April vs May 2026), using the staggered 2026 primary calendar.

Main result: holding a May primary raises a state's politics-topic conversation
share by 0.10 percentage points (s.e. 0.04) on a 0.48 percent base, about 22
percent. Write-up: `draft/aei_memo/aei_memo.pdf`.

The same design run in Google search data ("primary election" interest,
weekly by state) gives a proportional response about twice as large, and its
longer panel supports the parallel-trends and anticipation checks the
two-month AEI window cannot.

## Pipeline

`code/master.R` runs everything in order:

1. `clean_aei_election_topics.R` - extract topic shares from the AEI June 2026
   release (CC-BY, https://huggingface.co/datasets/Anthropic/EconomicIndex)
2. `prep_aei_did_data.R` - merge hand-compiled 2026 primary dates (NCSL/FVAP),
   build the treatment and the balanced 30-state panel
3. `clean_google_trends.R` / `check_google_trends_decode.R` /
   `prep_search_did_data.R` - build the state-month search panel from the raw
   Trends pulls in `original_data/google_trends/` (see its readme for how they
   were collected) and validate them against Google's own export
4. `make_aei_did_table.R` - estimate the three Claude specifications, write the table
5. `make_aei_politics_did.R` / `make_aei_change_hist.R` - the two Claude figures
6. `make_search_did_table.R` / `make_search_did_plot.R` /
   `make_search_event_study.R` - the Claude-vs-search comparison table and the
   search figures

`code/memo/master_memo.R` builds the separate descriptive memo (AH).

## Running it

The repo runs out of the box: `Rscript code/master.R` reproduces everything.
The cleaning script downloads the AEI release CSV (~210MB, too large for
GitHub) from Hugging Face on first run. Everything else ships with the repo:
the hand-compiled primary calendar (`original_data/primary_dates/`), the raw
Google Trends pulls (`original_data/google_trends/`), and the derived analysis
files in `modified_data/`, so the tables and figures can also be reproduced
without the big download by running only the `make_*` scripts. R dependencies:
pacman, tidyverse, fixest, glue, broom.

`code/xarchive/` holds an archived earlier pipeline that benchmarked the result
against a Google Trends event study around the same primaries.
