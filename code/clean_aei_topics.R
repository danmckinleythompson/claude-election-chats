# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Extract everything the blog figures need from the AEI June 2026 release:
# US national topic shares, country politics shares, global context metrics
# for the political topics, and the state-month panel of all topic shares
##

# Data comes from https://huggingface.co/datasets/Anthropic/EconomicIndex (CC-BY),
# release_2026_06_26 (calendar months April and May 2026). Downloaded 7/27/2026.
# NB: 31 request-topic names appear at more than one hierarchy level in this
# release, so topics are always keyed on (topic, lvl), never the name alone.

# Download the release from Hugging Face if it is not already on disk (~210MB,
# too large for GitHub, so the repo fetches it on first run)
aei_file = file.path(root, "original_data/anthropic_economic_index/release_2026_06_26/aei_claude_ai_2026-06-26.csv")
if (!file.exists(aei_file)) {
  dir.create(dirname(aei_file), recursive = TRUE, showWarnings = FALSE)
  options(timeout = max(1200, getOption("timeout")))
  download.file(
    "https://huggingface.co/datasets/Anthropic/EconomicIndex/resolve/main/release_2026_06_26/data/aei_claude_ai_2026-06-26.csv",
    aei_file, mode = "wb")
}

aei = read_csv(aei_file, show_col_types = FALSE) |>
  mutate(month = if_else(date_start == "2026-04-01", "apr", "may"))

req = aei |> filter(category_name == "request", metric_id == "pct")

# The political and news topics the figures track (both taxonomy levels)
POLITICAL = c("News aggregation", "Politics and public record", "News writing",
              "Geopolitics and strategy", "Politics", "Geopolitics",
              "Elections", "Public records lookup", "Government filings")

# US national share of every request topic, by month and taxonomy level
req |> filter(geo_id == "USA") |>
  transmute(topic = node_name, lvl = hierarchy_level, month, pct = value) |>
  write_csv(file.path(root, "modified_data/us_topic_shares.csv"))

# Politics-topic share by country, May
req |> filter(geo_level == "country", node_name == "Politics and public record",
              month == "may") |>
  transmute(country = geo_id, pct = value) |>
  arrange(desc(pct)) |>
  write_csv(file.path(root, "modified_data/country_politics.csv"))

# Global context metrics (use case, collaboration, artifacts) for the
# political topics and for all conversations, May
bind_rows(
  aei |> filter(geo_level == "global", month == "may", category_name == "request",
                node_name %in% POLITICAL) |>
    transmute(topic = node_name, lvl = hierarchy_level, metric_id, value),
  aei |> filter(geo_level == "global", month == "may", category_name == "overall") |>
    transmute(topic = "All conversations", lvl = NA_real_, metric_id, value)
) |>
  write_csv(file.path(root, "modified_data/global_context.csv"))

# State-month panel of every published topic share, for the diff-in-diff and
# the all-topic permutation check
state_panel = req |> filter(str_starts(geo_id, "US-")) |>
  transmute(state_po = str_remove(geo_id, "US-"), topic = node_name,
            lvl = hierarchy_level, month, pct = value)
stopifnot(state_panel |> count(state_po, topic, lvl, month) |> pull(n) |> max() == 1)
write_csv(state_panel, file.path(root, "modified_data/state_topic_panel.csv"))

# Print coverage so the console shows what we built
cat("US topics:", req |> filter(geo_id == "USA", month == "may") |> nrow(),
    "| countries:", req |> filter(geo_level == "country",
                                  node_name == "Politics and public record",
                                  month == "may") |> nrow(),
    "| state-topic-months:", nrow(state_panel), "\n")
