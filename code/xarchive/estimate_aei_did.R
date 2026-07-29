# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest, broom)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Diff-in-diff estimates: Claude politics-topic share, Apr vs May 2026,
# May-primary states against later-primary states
##

aei = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
               show_col_types = FALSE)

# Main sample drops the already-treated March-primary states (TX, NC, IL)
main = aei |> filter(!march_primary)

# Anticipation check: June-primary states begin mail voting in May (CA, CO,
# UT are all- or mostly-mail), so also estimate against Jul-Sep controls only
no_june = main |> filter(treat_may | primary_date >= as.Date("2026-07-01"))

specs = list(
  main      = feols(politics_broad ~ treat_may * post | state_po + release,
                    data = main, cluster = ~state_po),
  no_june   = feols(politics_broad ~ treat_may * post | state_po + release,
                    data = no_june, cluster = ~state_po),
  log_main  = feols(log(politics_broad) ~ treat_may * post | state_po + release,
                    data = main, cluster = ~state_po)
)

# One row per specification, with sample sizes and the control-group May mean
# recomputed from each estimation sample
estimates = imap(specs, \(m, name) {
  dat = if (name == "no_june") no_june else main
  tibble(
    spec = name,
    estimate = coef(m)[["treat_mayTRUE:postTRUE"]],
    se = se(m)[["treat_mayTRUE:postTRUE"]],
    n_obs = nobs(m),
    n_states = n_distinct(dat$state_po),
    n_treated = n_distinct(dat$state_po[dat$treat_may]),
    control_may_mean = mean(dat$politics_broad[!dat$treat_may & dat$post]),
    mde = se(m)[["treat_mayTRUE:postTRUE"]] * 2.80
  )
}) |>
  list_rbind()

write_csv(estimates, file.path(root, "modified_data/aei_did_estimates.csv"))

##
# Group-by-month means for the raw-data figure, plus each state's pair of
# points so the figure can show the underlying data
##

group_means = main |>
  group_by(treat_may, post) |>
  summarize(mean_pct = mean(politics_broad), n = n(), .groups = "drop")
write_csv(group_means, file.path(root, "modified_data/aei_did_group_means.csv"))

main |>
  select(state_po, post, treat_may, politics_broad) |>
  write_csv(file.path(root, "modified_data/aei_did_state_points.csv"))

# Print the result so the console shows it
print(estimates)
