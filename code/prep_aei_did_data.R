# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Build the Claude (AEI) state-month diff-in-diff panel: Apr vs May 2026
##

primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)

aei = read_csv(file.path(root, "modified_data/aei_election_topics.csv"),
               show_col_types = FALSE) |>
  filter(release %in% c("apr2026", "may2026"), geo_level == "state") |>
  select(release, state_po, concept, pct) |>
  pivot_wider(names_from = concept, values_from = pct)

# Keep states observed in both months so the panel is balanced
balanced_states = aei |>
  filter(!is.na(politics_broad)) |>
  count(state_po) |>
  filter(n == 2) |>
  pull(state_po)

aei_did = aei |>
  filter(state_po %in% balanced_states) |>
  left_join(primaries |> select(state_po, primary_date, runoff_date),
            by = "state_po", relationship = "many-to-one") |>
  mutate(
    post = release == "may2026",
    # Treatment: the state's regular statewide primary falls in May 2026
    treat_may = primary_date >= as.Date("2026-05-01") & primary_date <= as.Date("2026-05-31"),
    # Already-treated March-primary states (TX, NC, IL here) are dropped from
    # the main sample; TX and NC also hold May runoffs, so they are neither
    # clean controls nor clean treateds
    march_primary = primary_date < as.Date("2026-04-01")
  )
stopifnot(sum(is.na(aei_did$primary_date)) == 0)

# DC is in the AEI data with a Jun 16 primary; it stays as a control
write_csv(aei_did, file.path(root, "modified_data/aei_did_data.csv"))

# Print the group counts so the console shows the design
aei_did |>
  filter(!post) |>
  count(march_primary, treat_may) |>
  print()
