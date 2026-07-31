# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Diff-in-diff estimates for the blog's inference figures: the politics main
# and no-June-controls specifications, four pre-specified comparison topics,
# and the same design run on every estimable topic (the empirical null)
##

# Spec throughout: y_st = b (May primary_s x May_t) + state FE + month FE on
# the balanced Apr/May panel, SEs clustered by state, March-primary states
# (TX, NC, IL) dropped. Design due to the repo's DiD; permutation check by AH.

primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)
panel = read_csv(file.path(root, "modified_data/state_topic_panel.csv"),
                 show_col_types = FALSE)

# Balanced Apr/May panel for one (topic, level) series, with treatment coding
build_panel = function(tp, lv) {
  d = panel |> filter(topic == tp, lvl == lv)
  stopifnot(!any(duplicated(d[c("state_po", "month")])))
  bal = d |> count(state_po) |> filter(n == 2) |> pull(state_po)
  d |> filter(state_po %in% bal) |>
    left_join(primaries |> select(state_po, primary_date), by = "state_po") |>
    filter(!is.na(primary_date), primary_date >= as.Date("2026-04-01")) |>
    mutate(post = month == "may",
           treat_may = primary_date >= as.Date("2026-05-01") &
                       primary_date <= as.Date("2026-05-31"))
}

run_did = function(tp, lv, drop_june = FALSE, min_treated = 4, min_states = 20) {
  d = build_panel(tp, lv)
  if (drop_june) d = d |> filter(treat_may | primary_date >= as.Date("2026-07-01"))
  n_tr = n_distinct(d$state_po[d$treat_may]); n_st = n_distinct(d$state_po)
  if (n_tr < min_treated || n_st < min_states) return(NULL)
  m = feols(pct ~ treat_may * post | state_po + month, data = d, cluster = ~state_po)
  nm = "treat_mayTRUE:postTRUE"
  if (!nm %in% names(coef(m))) return(NULL)
  tibble(topic = tp, lvl = lv, n_states = n_st, n_treated = n_tr,
         est = coef(m)[[nm]], se = se(m)[[nm]], t = est / se)
}

##
# The politics specifications and the pre-specified comparison topics
# (comparisons use a lower coverage bar of 15 states: they are pre-specified,
# not screened, and News writing and Geopolitics publish in only 16 states)
##

COMPARISONS = c("News aggregation", "News writing", "Geopolitics and strategy",
                "Personal finance")
comp_keys = panel |> filter(topic %in% COMPARISONS) |> count(topic, lvl) |>
  group_by(topic) |> slice_max(n, n = 1, with_ties = FALSE) |> ungroup()

topic_effects = bind_rows(
  run_did("Politics and public record", 1) |>
    mutate(spec = "Main specification", group = "politics"),
  run_did("Politics and public record", 1, drop_june = TRUE, min_states = 15) |>
    mutate(spec = "Excluding June-primary controls", group = "politics"),
  pmap(list(comp_keys$topic, comp_keys$lvl),
       \(tp, lv) run_did(tp, lv, min_states = 15)) |>
    compact() |> list_rbind() |> mutate(spec = topic, group = "comparison")
)
write_csv(topic_effects, file.path(root, "modified_data/topic_effects.csv"))

##
# The empirical null: the identical design on every estimable topic series
##

all_keys = panel |> distinct(topic, lvl)
null_dist = pmap(list(all_keys$topic, all_keys$lvl), run_did) |>
  compact() |> list_rbind() |>
  # Same-named series at two levels that are numerically identical are one
  # series; genuinely different ones stay as distinct (topic, level) series
  distinct(topic, est, se, n_states, n_treated, .keep_all = TRUE)
stopifnot(nrow(null_dist) > 50, !any(duplicated(null_dist[c("topic", "lvl")])))
write_csv(null_dist, file.path(root, "modified_data/null_distribution.csv"))

# Print the headline results so the console shows them
pol_t = null_dist$t[null_dist$topic == "Politics and public record"]
cat(sprintf("politics: %.3f (SE %.3f) | no-June: %.3f | null n = %d | rank %d | RI p = %.4f\n",
            topic_effects$est[1], topic_effects$se[1], topic_effects$est[2],
            nrow(null_dist), sum(null_dist$t >= pol_t),
            mean(abs(null_dist$t) >= abs(pol_t))))
