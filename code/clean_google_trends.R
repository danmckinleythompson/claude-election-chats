# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Stack the Google Trends batch downloads into one state-week panel
##

# Data comes from trends.google.com CSV exports for the search term
# "primary election", weekly, 7/1/2025-7/26/2026, pulled 7/27/2026 in batches
# of five geographies through the browser (see notes/google_trends_pull_notes.txt).
# NB: Trends normalizes each batch to its own within-batch max of 100, so
# levels are only comparable within a batch; analysis uses state fixed effects
# and logs, which absorb the batch-specific scaling.

batch_files = list.files(file.path(root, "original_data/google_trends"),
                         pattern = "^gt_primary_election_batch\\d+\\.csv$",
                         full.names = TRUE)
stopifnot(length(batch_files) == 11)

# Each file: two junk header lines, then Week + one column per geography named
# like "primary election: (Alabama)"; values are integers with "<1" for trace,
# so read everything as character and convert after reshaping
trends = map(batch_files, \(f) {
  read_csv(f, skip = 2, col_types = cols(.default = col_character())) |>
    pivot_longer(-Week, names_to = "geo_name", values_to = "index_raw") |>
    mutate(batch = basename(f))
}) |>
  list_rbind() |>
  mutate(
    geo_name = geo_name |> str_remove("^primary election: \\(") |> str_remove("\\)$"),
    week_start = as.Date(Week),
    # "<1" means a positive share too small to round to 1; the site's own chart
    # plots these weeks at 0, so code them as 0 to keep the downloaded batch
    # consistent with the SVG-decoded batches
    index = if_else(index_raw == "<1", 0, suppressWarnings(as.numeric(index_raw)))
  )

# Map the spelled-out geography names to postal codes; "United States" is the
# national series
state_xwalk = tibble(
  geo_name = c(state.name, "District of Columbia", "United States"),
  state_po = c(state.abb, "DC", "US")
)
trends = trends |>
  inner_join(state_xwalk, by = "geo_name", relationship = "many-to-one")

# The final week of the pull window is partial - drop it
trends = trends |> filter(week_start < as.Date("2026-07-26"))

# Expect 51 states + DC + national = 52 series over 56 complete weeks
stopifnot(n_distinct(trends$state_po) == 52)
stopifnot(trends |> count(state_po) |> pull(n) |> unique() == 56)
stopifnot(sum(is.na(trends$index)) == 0)

trends |>
  select(state_po, week_start, index, batch) |>
  arrange(state_po, week_start) |>
  write_csv(file.path(root, "modified_data/google_trends_weekly.csv"))

# Print a quick summary so the console shows what we built
trends |>
  summarize(n_series = n_distinct(state_po), n_weeks = n_distinct(week_start),
            mean_index = mean(index)) |>
  print()
