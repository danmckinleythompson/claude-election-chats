# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Extract election- and politics-related request-topic shares, by state and by
# nation, from the four public Anthropic Economic Index releases
##

# Data comes from https://huggingface.co/datasets/Anthropic/EconomicIndex (CC-BY)
# Five observation windows: Aug 4-11 2025, Nov 13-20 2025, Feb 5-12 2026, and
# calendar months Apr and May 2026. Downloaded 7/27/2026.

# NB: the request-topic taxonomy is re-clustered each release, so cluster names
# (and boundaries) are not comparable across releases. We tag each release's
# closest match to two concepts and keep the release label attached so that
# analysis scripts can stay within a taxonomy:
#   elections_narrow - the release's specifically-electoral detailed cluster
#   politics_broad   - the release's broader politics/government cluster
# The Aug 2025 release has no specifically-electoral cluster at any level.

concept_lookup = tribble(
  ~release,   ~concept,           ~cluster_name,                                                                       ~cluster_level,
  "aug2025",  "politics_broad",   "Provide information and analysis about political systems and governance",           0,
  "nov2025",  "elections_narrow", "Assist with practical political campaign work and electoral information research",  0,
  "nov2025",  "politics_broad",   "Research government, political, educational, and defense information and policies", 1,
  "feb2026",  "elections_narrow", "Assist with practical political campaign work and electoral information research",  0,
  "feb2026",  "politics_broad",   "Assist with civic information, government services, and institutional research",    1,
  "apr2026",  "elections_narrow", "Elections",                                                                         0,
  "apr2026",  "politics_broad",   "Politics and public record",                                                        1,
  "may2026",  "elections_narrow", "Elections",                                                                         0,
  "may2026",  "politics_broad",   "Politics and public record",                                                        1
)

##
# Releases from Sep 2025 through Mar 2026 share one schema (facet/cluster_name)
##

# NB: the Aug 2025 file codes states as bare postal codes with geography
# "state_us"; the Nov 2025 and Feb 2026 files use US-XX with "country-state"
read_old_schema = function(file, release_label) {
  read_csv(file.path(root, file), show_col_types = FALSE) |>
    filter(facet == "request", variable == "request_pct") |>
    filter(geography %in% c("state_us", "country-state", "country")) |>
    filter(geography != "country" | geo_id == "US") |>
    filter(geography != "country-state" | str_starts(geo_id, "US-")) |>
    mutate(
      release = release_label,
      state_po = case_when(
        geography == "state_us" ~ geo_id,
        geography == "country-state" ~ str_remove(geo_id, "US-"),
        geography == "country" ~ NA_character_
      ),
      geo_level = if_else(geography == "country", "national", "state"),
      cluster_level = as.integer(level)
    ) |>
    select(release, date_start, date_end, geo_level, state_po,
           cluster_name, cluster_level, pct = value)
}

aug2025 = read_old_schema(
  "original_data/anthropic_economic_index/release_2025_09_15/aei_raw_claude_ai_2025-08-04_to_2025-08-11.csv",
  "aug2025")
nov2025 = read_old_schema(
  "original_data/anthropic_economic_index/release_2026_01_15/aei_raw_claude_ai_2025-11-13_to_2025-11-20.csv",
  "nov2025")
feb2026 = read_old_schema(
  "original_data/anthropic_economic_index/release_2026_03_24/aei_raw_claude_ai_2026-02-05_to_2026-02-12.csv",
  "feb2026")

##
# The Jun 2026 release has its own schema and holds the Apr and May 2026 months
##

jun_release = read_csv(
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
         cluster_name = node_name, cluster_level, pct = value)

##
# Keep the tagged concept clusters and save
##

aei_topics = bind_rows(aug2025, nov2025, feb2026, jun_release) |>
  inner_join(concept_lookup, by = c("release", "cluster_name", "cluster_level"),
             relationship = "many-to-one") |>
  arrange(release, concept, geo_level, state_po)

# Every release-concept pair in the lookup should appear for the nation
national_check = aei_topics |>
  filter(geo_level == "national") |>
  count(release, concept)
stopifnot(nrow(national_check) == nrow(concept_lookup))

# A state should never appear twice for the same release-concept
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
  print(n = 20)
