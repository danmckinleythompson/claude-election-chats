# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Extract state-month politics-topic shares from the Anthropic Economic Index
# June 2026 release (calendar months April and May 2026)
##

# Data comes from https://huggingface.co/datasets/Anthropic/EconomicIndex (CC-BY),
# release_2026_06_26. Downloaded 7/27/2026.
# NB: the request-topic taxonomy is re-clustered in every AEI release, so these
# topic shares are not comparable to earlier releases. The full four-release
# extraction used for descriptive national series is archived in
# code/xarchive/clean_aei_election_topics_all_releases.R.

# The two topics we track: "Politics and public record" is the broadest
# political category (hierarchy level 1); "Elections" is its narrow detailed
# subtopic (level 0), published for too few states to use as an outcome
concept_lookup = tribble(
  ~concept,           ~cluster_name,                 ~cluster_level,
  "elections_narrow", "Elections",                   0,
  "politics_broad",   "Politics and public record",  1
)

aei_topics = read_csv(
  file.path(root, "original_data/anthropic_economic_index/release_2026_06_26/aei_claude_ai_2026-06-26.csv"),
  show_col_types = FALSE) |>
  filter(category_name == "request", metric_id == "pct") |>
  filter(geo_id == "USA" | str_starts(geo_id, "US-")) |>
  mutate(
    release = if_else(date_start == "2026-04-01", "apr2026", "may2026"),
    state_po = if_else(geo_id == "USA", NA_character_, str_remove(geo_id, "US-")),
    geo_level = if_else(geo_id == "USA", "national", "state"),
    cluster_level = as.integer(hierarchy_level)
  ) |>
  select(release, date_start, date_end, geo_level, state_po,
         cluster_name = node_name, cluster_level, pct = value) |>
  inner_join(concept_lookup, by = c("cluster_name", "cluster_level"),
             relationship = "many-to-one") |>
  arrange(release, concept, geo_level, state_po)

# A state should never appear twice for the same month-concept
stopifnot(aei_topics |>
  filter(geo_level == "state") |>
  count(release, concept, state_po) |>
  pull(n) |> max() == 1)

write_csv(aei_topics, file.path(root, "modified_data/aei_election_topics.csv"))

# Print coverage so the console shows what we kept
aei_topics |>
  group_by(release, concept) |>
  summarize(n_states = sum(geo_level == "state"),
            national_pct = pct[geo_level == "national"], .groups = "drop") |>
  print()
