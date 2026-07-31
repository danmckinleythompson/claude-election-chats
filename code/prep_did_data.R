# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Build the politics diff-in-diff panel: balanced Apr/May state panel of the
# "Politics and public record" share with the primary-timing treatment
##

primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)

politics = read_csv(file.path(root, "modified_data/state_topic_panel.csv"),
                    show_col_types = FALSE) |>
  filter(topic == "Politics and public record", lvl == 1)

# Keep states observed in both months so the panel is balanced
balanced = politics |> count(state_po) |> filter(n == 2) |> pull(state_po)

did_panel = politics |>
  filter(state_po %in% balanced) |>
  left_join(primaries |> select(state_po, primary_date), by = "state_po",
            relationship = "many-to-one") |>
  mutate(
    post = month == "may",
    # Treatment: the state's regular statewide primary falls in May 2026;
    # March-primary states (TX, NC, IL here) are excluded as already treated
    treat_may = primary_date >= as.Date("2026-05-01") & primary_date <= as.Date("2026-05-31"),
    march_primary = primary_date < as.Date("2026-04-01")
  ) |>
  filter(!march_primary) |>
  select(state_po, month, post, treat_may, pct)
stopifnot(sum(!did_panel$post & did_panel$treat_may) == 8,
          sum(!did_panel$post & !did_panel$treat_may) == 22)

write_csv(did_panel, file.path(root, "modified_data/did_panel.csv"))
