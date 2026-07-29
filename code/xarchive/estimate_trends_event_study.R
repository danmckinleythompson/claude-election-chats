# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest, broom)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Event-study estimates: Google searches for "primary election" around each
# state's 2026 primary date
##

trends = read_csv(file.path(root, "modified_data/trends_event_study_data.csv"),
                  show_col_types = FALSE)

# Bin event time at -9 and +5 so every state-week keeps a bin; states whose
# primaries fall after the sample (Aug-Sep) only ever contribute to the far-lead
# bin and to the week fixed effects, which is what makes them controls
trends = trends |>
  mutate(
    event_bin = case_when(
      event_week <= -9 ~ -9L,
      event_week >= 5 ~ 5L,
      TRUE ~ as.integer(event_week)
    ),
    log_index = log1p(index),
    # Integer week counters for the Sun-Anderson-style estimator
    week_num = as.integer(week_start - min(week_start)) %/% 7L,
    cohort_num = as.integer(primary_week_start - min(week_start)) %/% 7L
  )

##
# Two-way fixed effects event study, reference week -1, clustered by state
##

twfe = feols(log_index ~ i(event_bin, ref = -1) | state_po + week_start,
             data = trends, cluster = ~state_po)

##
# Sun & Abraham interaction-weighted estimator as the staggered-timing check
##

sunab_fit = feols(log_index ~ sunab(cohort_num, week_num) | state_po + week_start,
                  data = trends, cluster = ~state_po)

# Harvest both sets of event-time coefficients into one tidy file
estimates = bind_rows(
  tidy(twfe, conf.int = TRUE) |>
    mutate(estimator = "twfe",
           event_week = as.integer(str_extract(term, "-?\\d+"))),
  tidy(sunab_fit, conf.int = TRUE) |>
    mutate(estimator = "sunab",
           event_week = as.integer(str_extract(term, "-?\\d+"))) |>
    filter(event_week >= -9, event_week <= 5)
) |>
  select(estimator, event_week, estimate, std.error, conf.low, conf.high)

write_csv(estimates, file.path(root, "modified_data/trends_event_study_estimates.csv"))

##
# Raw event-time means on the balanced -8..+4 window for the raw-data figure
##

event_means = trends |>
  filter(balanced_window, event_week >= -8, event_week <= 4) |>
  group_by(event_week) |>
  summarize(mean_index = mean(index), n_states = n(), .groups = "drop")
stopifnot(event_means$n_states |> unique() |> length() == 1)

write_csv(event_means, file.path(root, "modified_data/trends_event_week_means.csv"))

# Print the key coefficients so the console shows the result
print(coeftable(twfe)[c("event_bin::-2", "event_bin::0", "event_bin::1"), ])
cat("Balanced-window states:", event_means$n_states[1], "\n")
