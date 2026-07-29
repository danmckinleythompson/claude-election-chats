# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Build the Google Trends state-week event-study panel
##

primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)

trends = read_csv(file.path(root, "modified_data/google_trends_weekly.csv"),
                  show_col_types = FALSE) |>
  filter(state_po != "US") |>
  left_join(primaries |> select(state_po, primary_date), by = "state_po",
            relationship = "many-to-one")
stopifnot(sum(is.na(trends$primary_date)) == 0)

# Trends weeks start on Sunday; the primary's event week is the week containing
# the primary date (all 2026 primaries are Tue except LA's Sat May 16, which
# falls in the same Sun-Sat week convention)
trends = trends |>
  mutate(
    primary_week_start = primary_date - (as.integer(format(primary_date, "%w"))),
    event_week = as.integer(week_start - primary_week_start) %/% 7L
  )

# States whose full -8..+4 event window sits inside the complete-week data
# (primaries through Jun 23); used for the raw-means figure so the set of
# states is identical at every event week
trends = trends |>
  mutate(balanced_window = primary_date <= as.Date("2026-06-23"))

write_csv(trends, file.path(root, "modified_data/trends_event_study_data.csv"))
