# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Build the state-month Google search panel that mirrors the Claude analysis
##

primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)

# The 30-state AEI analysis sample, so the search analysis can subset to it
aei_states = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
                      show_col_types = FALSE) |>
  filter(!march_primary) |>
  distinct(state_po)

# Assign each Trends week to the calendar month containing its midpoint, so the
# week of the Jun 2 primaries (starting May 31) counts as June, matching the
# AEI's calendar-month windows
search_monthly = read_csv(file.path(root, "modified_data/google_trends_weekly.csv"),
                          show_col_types = FALSE) |>
  filter(state_po != "US") |>
  mutate(month = floor_date(week_start + 3, "month")) |>
  group_by(state_po, month) |>
  summarize(mean_index = mean(index), .groups = "drop") |>
  filter(month >= as.Date("2025-07-01"), month <= as.Date("2026-05-01")) |>
  left_join(primaries |> select(state_po, primary_date), by = "state_po",
            relationship = "many-to-one") |>
  mutate(
    treat_may = primary_date >= as.Date("2026-05-01") & primary_date <= as.Date("2026-05-31"),
    march_primary = primary_date < as.Date("2026-04-01"),
    aei_sample = state_po %in% aei_states$state_po
  )

# 51 jurisdictions x 11 months, and the AEI subset matches the Claude panel
stopifnot(n_distinct(search_monthly$state_po) == 51)
stopifnot(search_monthly |> count(state_po) |> pull(n) |> unique() == 11)
stopifnot(sum(search_monthly$aei_sample) / 11 == 30)

write_csv(search_monthly, file.path(root, "modified_data/search_did_data.csv"))
