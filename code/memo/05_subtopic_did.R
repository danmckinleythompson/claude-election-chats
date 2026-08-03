# 05_subtopic_did.R ---------------------------------------------------------
# Can the primary-election diff-in-diff be estimated separately for the
# political SUB-topics, rather than only the broad "Politics and public
# record" aggregate?
#
# The design needs a state observed in BOTH April and May (two periods plus
# state fixed effects leaves no alternative), so the answer is governed by how
# many states clear AEI's privacy threshold in both months for each sub-topic.
# This script reports coverage, the estimate where one is possible, and the
# minimum detectable effect everywhere -- so that "no effect" is never
# confused with "no power".
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, fixest, glue)
set.seed(42)
options(scipen = 999)
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

outdir = file.path(root, "output/memo")
aei = read_csv(file.path(root,
  "original_data/anthropic_economic_index/release_2026_06_26/aei_claude_ai_2026-06-26.csv"),
  show_col_types = FALSE)
primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)

# Keyed on (topic, level): 23 topic names occur at two hierarchy levels.
st = aei |> filter(category_name == "request", metric_id == "pct", str_starts(geo_id, "US-")) |>
  transmute(topic = node_name, lvl = hierarchy_level,
            state_po = str_remove(geo_id, "US-"),
            mo = if_else(date_start == "2026-04-01", "apr", "may"), pct = value)

# Every political sub-topic in this release, at both levels.
SUBTOPICS = tribble(
  ~topic,                       ~lvl, ~kind,
  "Politics and public record",  1,   "Aggregate (benchmark)",
  "Politics",                    0,   "Politics, general",
  "Elections",                   0,   "Elections",
  "Political science",           0,   "Political science",
  "Political strategy",          0,   "Political strategy",
  "Government structure",        0,   "Government structure",
  "Public records lookup",       0,   "Public records",
  "Government filings",          1,   "Government filings",
  "Law and governance",          0,   "Law and governance",
  "Legislative drafting",        0,   "Legislative drafting",
  "Geopolitics and strategy",    1,   "Geopolitics (aggregate)",
  "Geopolitics",                 0,   "Geopolitics",
  "Energy geopolitics",          0,   "Energy geopolitics",
  "Trade policy",                0,   "Trade policy",
  "Health policy",               0,   "Health policy",
  "News aggregation",            0,   "News aggregation",
  "News writing",                0,   "News writing")

build_panel = function(tp, lv) {
  d = st |> filter(topic == tp, lvl == lv) |>
    transmute(state_po, release = if_else(mo == "apr", "apr2026", "may2026"), y = pct)
  stopifnot(!any(duplicated(d[c("state_po", "release")])))
  bal = d |> filter(!is.na(y)) |> count(state_po) |> filter(n == 2) |> pull(state_po)
  d |> filter(state_po %in% bal) |>
    left_join(primaries |> select(state_po, primary_date), by = "state_po") |>
    filter(!is.na(primary_date), primary_date >= as.Date("2026-04-01")) |>
    mutate(post = release == "may2026",
           treat_may = primary_date >= as.Date("2026-05-01") &
                       primary_date <= as.Date("2026-05-31"))
}

assess = function(tp, lv, kind) {
  seen = st |> filter(topic == tp, lvl == lv, !is.na(pct)) |> count(mo)
  n_apr = sum(seen$n[seen$mo == "apr"]); n_may = sum(seen$n[seen$mo == "may"])
  d = build_panel(tp, lv)
  n_st = n_distinct(d$state_po); n_tr = n_distinct(d$state_po[d$treat_may])
  out = tibble(kind = kind, topic = tp, lvl = lv, n_apr = n_apr, n_may = n_may,
               n_balanced = n_st, n_treated = n_tr,
               base = if (n_st > 0) mean(d$y[!d$treat_may & d$post], na.rm = TRUE) else NA_real_,
               est = NA_real_, se = NA_real_, t = NA_real_, mde = NA_real_, status = "")
  if (n_tr < 3 || n_st < 8) { out$status = "not estimable"; return(out) }
  m = try(feols(y ~ treat_may * post | state_po + release, data = d, cluster = ~state_po),
          silent = TRUE)
  nm = "treat_mayTRUE:postTRUE"
  if (inherits(m, "try-error") || !nm %in% names(coef(m))) {
    out$status = "not estimable"; return(out)
  }
  out$est = coef(m)[[nm]]; out$se = se(m)[[nm]]
  out$t = out$est / out$se; out$mde = 2.80 * out$se
  out$status = if (n_tr < 4 | n_st < 15) "estimable, very low power" else "estimable"
  out
}

res = pmap(list(SUBTOPICS$topic, SUBTOPICS$lvl, SUBTOPICS$kind), assess) |> list_rbind()
write_csv(res, file.path(outdir, "subtopic_did.csv"))

cat("\n=== COVERAGE AND ESTIMABILITY BY POLITICAL SUB-TOPIC ===\n")
res |> transmute(topic, lvl, states_apr = n_apr, states_may = n_may,
                 balanced = n_balanced, treated = n_treated, status) |>
  arrange(desc(balanced)) |> print(n = 30)

cat("\n=== ESTIMATES WHERE POSSIBLE ===\n")
res |> filter(status != "not estimable") |>
  transmute(topic, base = round(base, 3), est = round(est, 3), se = round(se, 3),
            t = round(t, 2), mde = round(mde, 3), n_balanced, n_treated, status) |>
  arrange(desc(t)) |> print(n = 20)

cat("\n=== why the narrow topics fail ===\n")
lost = res |> filter(status == "not estimable") |>
  transmute(topic, reported_apr = n_apr, reported_may = n_may, survive_balance = n_balanced,
            treated_left = n_treated)
print(lost, n = 20)
cat("\nA state must clear the privacy threshold in BOTH months to enter a\n",
    "two-period fixed-effects design. For the narrow topics most do not.\n", sep = "")
