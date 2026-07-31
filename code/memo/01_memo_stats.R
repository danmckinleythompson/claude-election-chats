# 01_memo_stats.R -----------------------------------------------------------
# Generates every number, table, and macro used by draft/politics_memo.
# Nothing in the memo is typed by hand: this script writes generated_*.tex
# files that the draft pulls in via \input{}.
#
# Specifications documented inline; see the memo appendix for the full design.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, fixest, glue)
set.seed(42)
options(scipen = 999)
# Resolve the project root: run from the repo root and it just works;
# otherwise fall back to the repo-wide convention.
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

outdir = file.path(root, "output/memo")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

message("[01] reading AEI release (~210MB) ...")
aei = read_csv(file.path(root,
  "original_data/anthropic_economic_index/release_2026_06_26/aei_claude_ai_2026-06-26.csv"),
  show_col_types = FALSE)
primaries = read_csv(file.path(root, "original_data/primary_dates/primary_dates_2026.csv"),
                     show_col_types = FALSE)

# LaTeX-safe text for topic names appearing in tables
tex_escape = function(x) str_replace_all(x, c("&" = "\\\\&", "%" = "\\\\%", "_" = "\\\\_"))
fmt = function(x, d = 2) formatC(x, format = "f", digits = d)

macros = c()
add_macro = function(name, value) {
  macros <<- c(macros, glue("\\newcommand{{\\{name}}}{{{value}}}"))
}

# Panel header for tables that mix taxonomy levels or metric families. Rows
# within a panel are mutually comparable; rows across panels are not.
panel = function(title, ncol) {
  c("\\addlinespace",
    glue("\\multicolumn{{{ncol}}}{{l}}{{\\textit{{{title}}}}} \\\\[0.5mm]"))
}

## ==========================================================================
## PART A — DESCRIPTIVES
## ==========================================================================

req = aei |> filter(category_name == "request", metric_id == "pct")

# --- A1. Headline scale: US national politics share, by month ---------------
natl = req |> filter(geo_id == "USA") |>
  transmute(topic = node_name, lvl = hierarchy_level,
            mo = if_else(date_start == "2026-04-01", "apr", "may"), pct = value)

get_natl = function(tp, m) {
  v = natl |> filter(topic == tp, mo == m) |> pull(pct)
  if (length(v) == 0) NA_real_ else v[1]
}
add_macro("polNatlApr", fmt(get_natl("Politics and public record", "apr")))
add_macro("polNatlMay", fmt(get_natl("Politics and public record", "may")))
add_macro("elecNatlApr", fmt(get_natl("Elections", "apr")))
add_macro("elecNatlMay", fmt(get_natl("Elections", "may")))
add_macro("newsNatlMay", fmt(get_natl("News aggregation", "may")))

# One in N conversations framing
add_macro("polOneInN", round(100 / get_natl("Politics and public record", "may")))

# --- A2. Political topic decomposition, with state coverage -----------------
POLITICAL = c("News aggregation", "Politics and public record", "News writing",
              "Geopolitics and strategy", "Politics", "Geopolitics",
              "Elections", "Public records lookup", "Government filings")

st = req |> filter(str_starts(geo_id, "US-")) |>
  transmute(topic = node_name, lvl = hierarchy_level,
            state_po = str_remove(geo_id, "US-"),
            mo = if_else(date_start == "2026-04-01", "apr", "may"), pct = value)

topic_levels = st |> distinct(topic, lvl)
topic_tab = tibble(topic = POLITICAL) |>
  left_join(topic_levels, by = "topic") |>
  mutate(apr = map_dbl(topic, get_natl, m = "apr"),
         may = map_dbl(topic, get_natl, m = "may"),
         n_apr = map_int(topic, \(t) sum(st$topic == t & st$mo == "apr")),
         n_may = map_int(topic, \(t) sum(st$topic == t & st$mo == "may"))) |>
  arrange(desc(lvl), desc(may))
write_csv(topic_tab, file.path(outdir, "topic_decomposition.csv"))

# Panelled by taxonomy level: Minor topics are aggregates, Detailed topics are
# leaves. AEI does not publish the parent-child map, so the two are shown
# separately rather than implying a nesting we cannot verify.
mk_rows = function(d) d |> mutate(
  line = glue("\\quad {tex_escape(topic)} & {fmt(apr)} & {fmt(may)} & {n_apr} & {n_may} \\\\")) |>
  pull(line)
c("\\begin{tabular}{lcccc}", "\\toprule \\toprule",
  " & \\multicolumn{2}{c}{US National Share (\\%)} & \\multicolumn{2}{c}{\\# States Reported} \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  " & April & May & April & May \\\\", "\\midrule",
  panel("Panel A. Minor topics (level 1, aggregates)", 5),
  mk_rows(filter(topic_tab, lvl == 1)),
  panel("Panel B. Detailed topics (level 0, leaves)", 5),
  mk_rows(filter(topic_tab, lvl == 0)),
  "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(outdir, "generated_topic_table.tex"))

# --- A3. Cross-country comparison (May 2026) --------------------------------
cty = req |> filter(geo_level == "country", node_name == "Politics and public record",
                    date_start == "2026-05-01") |>
  transmute(geo_id, pct = value) |> arrange(desc(pct))
write_csv(cty, file.path(outdir, "country_politics_shares.csv"))
add_macro("nCountries", nrow(cty))
add_macro("ctyTopName", cty$geo_id[1])
add_macro("ctyTopVal", fmt(cty$pct[1]))
add_macro("ctyBotName", cty$geo_id[nrow(cty)])
add_macro("ctyBotVal", fmt(cty$pct[nrow(cty)]))
add_macro("ctyRatio", fmt(cty$pct[1] / cty$pct[nrow(cty)], 1))
add_macro("usaRank", which(cty$geo_id == "USA"))

# --- A4. Composition: how people use Claude for politics (global only) ------
comp = aei |> filter(category_name == "request", geo_level == "global",
                     node_name == "Politics and public record") |>
  select(metric_id, date_start, value) |>
  pivot_wider(names_from = date_start, values_from = value) |>
  rename(apr = `2026-04-01`, may = `2026-05-01`)

pick = function(m) { v = comp |> filter(metric_id == m); if (nrow(v) == 0) NA else v$may[1] }
add_macro("usePersonal", fmt(pick("use_case_personal_pct"), 1))
add_macro("useWork", fmt(pick("use_case_work_pct"), 1))
add_macro("useCoursework", fmt(pick("use_case_coursework_pct"), 1))
add_macro("collabAutomation", fmt(pick("collaboration_bucket_automation_pct"), 1))
add_macro("collabAugmentation", fmt(pick("collaboration_bucket_augmentation_pct"), 1))

# One table, three panels. Each panel sums to 100 within itself; the panels are
# different classifications of the same conversations, not sub-rows of one
# another. Panel C's patterns are what Panel B's buckets are built from, which
# the panel titles state explicitly.
comp_spec = tribble(
  ~grp, ~label,           ~metric,                            ~defn,
  "A",  "Personal",       "use_case_personal_pct",            "",
  "A",  "Work",           "use_case_work_pct",                "",
  "A",  "Coursework",     "use_case_coursework_pct",          "",
  "B",  "Augmentation",   "collaboration_bucket_augmentation_pct", "Task iteration, learning, or validation",
  "B",  "Automation",     "collaboration_bucket_automation_pct",   "Directive or feedback loop",
  "C",  "Learning",       "collaboration_learning_pct",       "Seeking understanding",
  "C",  "Directive",      "collaboration_directive_pct",      "Minimal human interaction",
  "C",  "Task iteration", "collaboration_task_iteration_pct", "Human refines AI outputs",
  "C",  "Feedback loop",  "collaboration_feedback_loop_pct",  "Iterative dialogue with feedback",
  "C",  "Validation",     "collaboration_validation_pct",     "Human checking own work",
  "C",  "None",           "collaboration_none_pct",           "No pattern assigned"
) |> left_join(comp, by = c("metric" = "metric_id"))
write_csv(comp_spec, file.path(outdir, "composition.csv"))

comp_line = function(g, with_defn = TRUE) comp_spec |> filter(grp == g) |> arrange(desc(may)) |>
  mutate(line = if (with_defn)
    glue("\\quad {label} & {defn} & {fmt(apr,1)} & {fmt(may,1)} & {fmt(may-apr,1)} \\\\")
  else glue("\\quad {label} & & {fmt(apr,1)} & {fmt(may,1)} & {fmt(may-apr,1)} \\\\")) |> pull(line)

c("\\begin{tabular}{llccc}", "\\toprule \\toprule",
  " & Definition & April & May & Change \\\\", "\\midrule",
  panel("Panel A. Use case (sums to 100)", 5), comp_line("A", FALSE),
  panel("Panel B. Collaboration bucket (sums to 100, excludes \\textit{none})", 5), comp_line("B"),
  panel("Panel C. Collaboration pattern (sums to 100; Panel B is built from these)", 5), comp_line("C"),
  "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(outdir, "generated_composition_table.tex"))

# --- A5. Artifacts: what Claude actually produced in political conversations
# The artifact classifier records the most prominent concrete output of each
# conversation. Comparing the politics topic to all conversations separates
# information-seeking outputs (explanations, analyses) from "doing" outputs
# (messages, plans, documents) -- the information/representation distinction.
art = aei |> filter(geo_level == "global", date_start == "2026-05-01",
                    str_detect(metric_id, "^artifact_")) |>
  filter((category_name == "request" & node_name == "Politics and public record") |
           category_name == "overall") |>
  mutate(who = if_else(category_name == "overall", "all_convos", "politics"),
         artifact = str_remove_all(metric_id, "artifact_|_pct")) |>
  select(who, artifact, value) |>
  pivot_wider(names_from = who, values_from = value) |>
  mutate(diff = politics - all_convos) |> arrange(desc(politics))
write_csv(art, file.path(outdir, "artifacts.csv"))

art_pick = function(a) art$politics[art$artifact == a]
INFO_ART = c("explanation_or_answer", "analysis_or_summary")
DOING_ART = c("email_or_message", "plan_or_strategy", "marketing_or_social_content")
info_share = sum(map_dbl(INFO_ART, art_pick))
doing_share = sum(map_dbl(DOING_ART, art_pick))
add_macro("artInfoShare", fmt(info_share, 1))
add_macro("artDoingShare", fmt(doing_share, 1))
add_macro("artInfoDoingRatio", fmt(info_share / doing_share, 0))
add_macro("artExplain", fmt(art_pick("explanation_or_answer"), 1))
add_macro("artExplainAll", fmt(art$all_convos[art$artifact == "explanation_or_answer"], 1))
add_macro("artAnalysis", fmt(art_pick("analysis_or_summary"), 1))
add_macro("artEmail", fmt(art_pick("email_or_message"), 1))
add_macro("artEmailAll", fmt(art$all_convos[art$artifact == "email_or_message"], 1))
add_macro("artPlan", fmt(art_pick("plan_or_strategy"), 1))
add_macro("artNone", fmt(art_pick("none"), 1))

# Table: the artifacts that most distinguish political conversations. Rank by
# absolute gap, not signed gap -- only three artifacts are over-represented, so
# a top-5/bottom-5 split wastes rows on artifacts with near-zero differences.
art_show = art |> slice_max(abs(diff), n = 10) |> arrange(desc(diff))
art_rows = art_show |> mutate(
  label = str_to_sentence(str_replace_all(artifact, "_", " ")),
  line = glue("{label} & {fmt(politics,1)} & {fmt(all_convos,1)} & {fmt(diff,1)} \\\\")) |>
  pull(line)
c("\\begin{tabular}{lccc}", "\\toprule \\toprule",
  "Artifact produced & Politics (\\%) & All conversations (\\%) & Difference \\\\",
  "\\midrule", art_rows, "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(outdir, "generated_artifact_table.tex"))

# --- A6. Bucket construction check ------------------------------------------
add_macro("patLearning", fmt(comp$may[comp$metric_id == "collaboration_learning_pct"], 1))

# Verify the renormalisation claim so the memo's description cannot go stale
auto_raw = comp$may[comp$metric_id == "collaboration_directive_pct"] +
           comp$may[comp$metric_id == "collaboration_feedback_loop_pct"]
none_may = comp$may[comp$metric_id == "collaboration_none_pct"]
stopifnot(abs(100 * auto_raw / (100 - none_may) -
              comp$may[comp$metric_id == "collaboration_bucket_automation_pct"]) < 0.05)

# --- A6b. Information vs action, topic by topic ------------------------------
# The aggregate politics figure hides real heterogeneity: administrative topics
# behave nothing like civic-informational ones. Artifact metrics are published
# globally for the Detailed topics too, which lets us separate them.
INFO_KIND  = c("explanation_or_answer", "analysis_or_summary")
ACTION_KIND = c("email_or_message", "plan_or_strategy", "marketing_or_social_content")
DOC_KIND   = c("document_or_report", "resume_or_job_application", "data_or_spreadsheet")

PROFILE = c("Politics", "Elections", "Public records lookup", "Government filings",
            "Politics and public record")
prof = aei |> filter(geo_level == "global", date_start == "2026-05-01",
                     category_name == "request", node_name %in% PROFILE,
                     str_detect(metric_id, "^artifact_")) |>
  mutate(artifact = str_remove_all(metric_id, "artifact_|_pct")) |>
  group_by(topic = node_name) |>
  summarise(info = sum(value[artifact %in% INFO_KIND]),
            action = sum(value[artifact %in% ACTION_KIND]),
            doc = sum(value[artifact %in% DOC_KIND]), .groups = "drop") |>
  left_join(topic_levels, by = "topic") |>
  left_join(tibble(topic = PROFILE) |> mutate(natl = map_dbl(topic, get_natl, m = "may")),
            by = "topic") |>
  arrange(desc(info))
write_csv(prof, file.path(outdir, "info_action_profile.csv"))

prof_rows = prof |> mutate(
  lvl_lab = if_else(lvl == 1, "Minor", "Detailed"),
  line = glue("{tex_escape(topic)} & {lvl_lab} & {fmt(natl)} & {fmt(info,1)} & \\
               {fmt(action,1)} & {fmt(doc,1)} \\\\")) |> pull(line)
c("\\begin{tabular}{llcccc}", "\\toprule \\toprule",
  "Topic & Level & Share (\\%) & Information & Action & Document \\\\",
  "\\midrule", prof_rows, "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(outdir, "generated_profile_table.tex"))

gf = prof |> filter(topic == "Government filings")
el = prof |> filter(topic == "Elections")
add_macro("gfInfo", fmt(gf$info, 1)); add_macro("gfAction", fmt(gf$action, 1))
add_macro("gfDoc", fmt(gf$doc, 1));   add_macro("gfShare", fmt(gf$natl))
add_macro("elInfo", fmt(el$info, 1)); add_macro("elAction", fmt(el$action, 1))
add_macro("prInfo", fmt(prof$info[prof$topic == "Public records lookup"], 1))
add_macro("prAction", fmt(prof$action[prof$topic == "Public records lookup"], 1))
add_macro("polTopicInfo", fmt(prof$info[prof$topic == "Politics"], 1))

# --- A7. Topic taxonomy shape ------------------------------------------------
tax = aei |> filter(category_name == "request") |> distinct(node_name, hierarchy_level) |>
  count(hierarchy_level)
add_macro("nDetailed", tax$n[tax$hierarchy_level == 0])
add_macro("nMinor", tax$n[tax$hierarchy_level == 1])
add_macro("nMajor", tax$n[tax$hierarchy_level == 2])

## ==========================================================================
## PART B — PRIMARY ANALYSIS
## ==========================================================================
# Spec (all columns): y_st = b (Primary_s x May_t) + state FE + month FE,
# estimated on the balanced Apr/May state panel, SEs clustered by state.
# March-primary states (TX, NC, IL) dropped throughout.

# NB: 23 topic names appear at two hierarchy levels in this release, so the
# panel must be keyed on (topic, hierarchy level). Keying on the name alone
# silently duplicates state-months and breaks the balanced-panel test.
build_panel = function(topic, lvl = NULL) {
  sub = st |> filter(topic == !!topic)
  if (!is.null(lvl) && !is.na(lvl)) sub = sub |> filter(lvl == !!lvl)
  d = sub |>
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

run_did = function(topic, lvl = NULL, min_treated = 4, min_states = 20) {
  d = build_panel(topic, lvl)
  n_tr = n_distinct(d$state_po[d$treat_may]); n_st = n_distinct(d$state_po)
  if (n_tr < min_treated || n_st < min_states) return(NULL)
  m = feols(y ~ treat_may * post | state_po + release, data = d, cluster = ~state_po)
  nm = "treat_mayTRUE:postTRUE"
  if (!nm %in% names(coef(m))) return(NULL)
  tibble(topic = topic, lvl = lvl %||% NA_real_, n_states = n_st, n_treated = n_tr,
         ctrl_may = mean(d$y[!d$treat_may & d$post]),
         est = coef(m)[[nm]], se = se(m)[[nm]], t = coef(m)[[nm]] / se(m)[[nm]])
}

# --- B1. Main result --------------------------------------------------------
main = run_did("Politics and public record")
stopifnot(!is.null(main))
add_macro("mainEst", fmt(main$est))
add_macro("mainSE", fmt(main$se))
add_macro("mainT", fmt(main$t))
add_macro("mainBase", fmt(main$ctrl_may))
add_macro("mainPct", round(100 * main$est / main$ctrl_may))
add_macro("mainStates", main$n_states)
add_macro("mainTreated", main$n_treated)

# --- B2. Specificity: other political topics + a non-political comparison ---
# Comparison topics are pre-specified, so they use a lower coverage bar
# (>=15 states) than the uniform bar applied to the null distribution below.
SPEC = c("Politics and public record", "News aggregation", "News writing",
         "Geopolitics and strategy", "Personal finance")
spec_keys = st |> filter(topic %in% SPEC) |> distinct(topic, lvl) |>
  semi_join(st |> count(topic, lvl) |> group_by(topic) |>
              slice_max(n, n = 1, with_ties = FALSE), by = c("topic", "lvl"))
spec = pmap(list(spec_keys$topic, spec_keys$lvl),
            \(tp, lv) run_did(tp, lv, min_states = 15)) |> compact() |> list_rbind() |>
  arrange(desc(t))
write_csv(spec, file.path(outdir, "specificity.csv"))

spec_rows = spec |> mutate(
  bold = topic == "Politics and public record",
  nm = if_else(bold, glue("\\textbf{{{tex_escape(topic)}}}"), tex_escape(topic)),
  line = glue("{nm} & {fmt(est)} & ({fmt(se)}) & {fmt(t)} & {n_states} & {n_treated} \\\\")) |>
  pull(line)
c("\\begin{tabular}{lccccc}", "\\toprule \\toprule",
  "Topic & Estimate & (SE) & $t$ & \\# States & \\# Treated \\\\", "\\midrule", spec_rows,
  "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(outdir, "generated_specificity_table.tex"))

# --- B2b. Robustness specs, for the post's coefficient figure ---------------
# Same outcome and design as B1, varying only the control group and the
# functional form. Written to CSV so the figure cannot drift from the table.
pol_panel = build_panel("Politics and public record")
fit_did = function(d, log = FALSE) {
  m = feols(if (log) log(y) ~ treat_may * post | state_po + release
            else y ~ treat_may * post | state_po + release,
            data = d, cluster = ~state_po)
  nm = "treat_mayTRUE:postTRUE"
  tibble(est = coef(m)[[nm]], se = se(m)[[nm]],
         n_states = n_distinct(d$state_po),
         n_treated = n_distinct(d$state_po[d$treat_may]))
}
did_specs = bind_rows(
  fit_did(pol_panel) |> mutate(spec = "Main specification", units = "pp"),
  fit_did(pol_panel |> filter(treat_may | primary_date >= as.Date("2026-07-01"))) |>
    mutate(spec = "Excluding June-primary controls", units = "pp"),
  fit_did(pol_panel, log = TRUE) |> mutate(spec = "Log share", units = "log"))
write_csv(did_specs, file.path(outdir, "did_specs.csv"))

lg = did_specs |> filter(units == "log")
add_macro("logEst", fmt(lg$est)); add_macro("logSE", fmt(lg$se))
nj = did_specs |> filter(spec == "Excluding June-primary controls")
add_macro("noJuneEst", fmt(nj$est)); add_macro("noJuneSE", fmt(nj$se))

# --- B3. Permutation / empirical null across all estimable topics -----------
# Same specification applied to every request topic meeting the coverage
# thresholds. This is the paper's own randomization-inference check: how
# unusual is the politics estimate against the distribution of all topics?
message("[01] running DiD across all topics for the empirical null ...")
all_keys = st |> distinct(topic, lvl)
null_res = pmap(list(all_keys$topic, all_keys$lvl), run_did) |> compact() |> list_rbind()
# Some names appear at two hierarchy levels. Where the two series are
# numerically identical, keep one. Where they genuinely differ they are
# distinct series in the taxonomy, so both stay and the unit of the null
# distribution is the (topic, level) series.
null_res = null_res |> distinct(topic, est, se, n_states, n_treated, .keep_all = TRUE)
stopifnot(nrow(null_res) > 50, !any(duplicated(null_res[c("topic", "lvl")])))
write_csv(null_res, file.path(outdir, "null_distribution.csv"))

pol_t = null_res$t[null_res$topic == "Politics and public record"]
ranked = null_res |> arrange(desc(t))
add_macro("nullN", nrow(null_res))
add_macro("polRank", which(ranked$topic == "Politics and public record"))
add_macro("riP", fmt(mean(abs(null_res$t) >= abs(pol_t)), 3))
add_macro("nullSD", fmt(sd(null_res$t)))
add_macro("nullMean", fmt(mean(null_res$t)))
add_macro("nSig", sum(abs(null_res$t) >= 1.96))
add_macro("pctSig", round(100 * mean(abs(null_res$t) >= 1.96)))
add_macro("nAbove", sum(null_res$t >= pol_t))

top_rows = ranked |> head(5) |> mutate(
  bold = topic == "Politics and public record",
  nm = if_else(bold, glue("\\textbf{{{tex_escape(topic)}}}"), tex_escape(topic)),
  line = glue("{row_number()} & {nm} & {fmt(est)} & ({fmt(se)}) & {fmt(t)} \\\\")) |> pull(line)
c("\\begin{tabular}{clccc}", "\\toprule \\toprule",
  "Rank & Topic & Estimate & (SE) & $t$ \\\\", "\\midrule", top_rows,
  "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(outdir, "generated_null_top_table.tex"))

# --- B4. Sample selection: treated states lost to the balance requirement ----
may_states = primaries |>
  filter(primary_date >= as.Date("2026-05-01"), primary_date <= as.Date("2026-05-31"))
kept = build_panel("Politics and public record") |> filter(treat_may) |>
  distinct(state_po) |> pull()
dropped = setdiff(may_states$state_po, kept)
add_macro("nMayPrimary", nrow(may_states))
add_macro("nMayKept", length(kept))
add_macro("nMayDropped", length(dropped))
add_macro("mayDroppedList", paste(sort(dropped), collapse = ", "))

writeLines(macros, file.path(outdir, "generated_macros.tex"))
message("[01] wrote ", length(macros), " macros and 4 tables to ", outdir)

cat("\n=== MAIN ===\n"); print(main)
cat("\n=== SPECIFICITY ===\n"); print(spec)
cat("\n=== NULL: n =", nrow(null_res), "| politics rank",
    which(ranked$topic == "Politics and public record"),
    "| RI p =", round(mean(abs(null_res$t) >= abs(pol_t)), 4), "===\n")
