# claude-election-chats

Replication code for the Free Systems post "Quantifying the Information
Layer": how people use Claude for politics, and what happens when a state
holds a primary, from the Anthropic Economic Index's June 2026 release
(state-month conversation topic shares, April and May 2026).

Headline result: when a state holds its May 2026 primary, the share of its
Claude conversations about politics rises by 0.10 percentage points
(s.e. 0.04) relative to later-primary states - about 22 percent. The same
design run on all 210 estimable topic series puts the politics t-statistic
3rd of 210 (randomization-inference p = 0.024).

## Running it

`Rscript code/master.R` reproduces every figure in the post. The cleaning
script downloads the AEI release CSV (~210MB, too large for GitHub) from
Hugging Face on first run; everything else ships with the repo, including the
hand-compiled 2026 primary calendar (`original_data/primary_dates/`, sources
in its readme) and the derived analysis files in `modified_data/`, so the
figures can also be rebuilt without the big download by running only the
`make_*` scripts. R dependencies: pacman, tidyverse, fixest, glue, cowplot,
patchwork, tidytext.

## Pipeline

1. `clean_aei_topics.R` - extract US/country/global/state topic shares and
   context metrics from the AEI release (CC-BY,
   https://huggingface.co/datasets/Anthropic/EconomicIndex)
2. `prep_did_data.R` - the politics diff-in-diff panel: balanced Apr/May
   state panel with primary-timing treatment (March-primary states excluded)
3. `estimate_topic_dids.R` - the politics estimates (main and excluding
   June-primary controls), four pre-specified comparison topics, and the
   same design on every estimable topic (the empirical null)
4. `make_*.R` - one script per figure, in post order; shared styling in
   `_blog_style.R`; each writes pdf + png to `output/`

| Figure | Script |
|---|---|
| Share of US conversations, by request topic | `make_us_topic_shares.R` |
| Political and news topic shares, by taxonomy level | `make_taxonomy_levels.R` |
| Politics-topic share, by country | `make_country_shares.R` |
| Artifacts produced: politics vs. all conversations | `make_artifacts_dumbbell.R` |
| Conversation outputs, by political topic | `make_topic_outputs.R` |
| Composition of political conversations | `make_politics_composition.R` |
| Change in politics-topic share, by state | `make_politics_arrows.R` |
| Group-average change summary | `make_did_group_change.R` |
| Politics-topic share before and after a primary | `make_did_spaghetti.R` |
| Estimated effect of a May primary, by topic | `make_topic_effects.R` |
| t-statistics across all estimable topics | `make_tstat_distribution.R` |

## Notes on the data

- A missing state-topic cell means "below the AEI privacy threshold," not
  zero; values are published rounded to two decimals.
- Topic names can repeat across hierarchy levels in this release, so
  everything is keyed on (topic, level).
- Topic taxonomies are re-estimated in each AEI release; nothing here
  compares shares across releases.
