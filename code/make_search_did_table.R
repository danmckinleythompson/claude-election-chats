# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest, glue)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Table: the same Apr/May diff-in-diff in Claude conversations and in Google
# searches, in logs so the two proportional responses are comparable
##

aei = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
               show_col_types = FALSE) |>
  filter(!march_primary) |>
  mutate(month = if_else(post, as.Date("2026-05-01"), as.Date("2026-04-01")))

search = read_csv(file.path(root, "modified_data/search_did_data.csv"),
                  show_col_types = FALSE) |>
  filter(month >= as.Date("2026-04-01"), !march_primary) |>
  mutate(post = month == as.Date("2026-05-01"))

specs = list(
  claude     = feols(log(politics_broad) ~ treat_may * post | state_po + month,
                     data = aei, cluster = ~state_po),
  search_aei = feols(log1p(mean_index) ~ treat_may * post | state_po + month,
                     data = search |> filter(aei_sample), cluster = ~state_po),
  search_all = feols(log1p(mean_index) ~ treat_may * post | state_po + month,
                     data = search, cluster = ~state_po)
)
samples = list(claude = aei, search_aei = search |> filter(aei_sample),
               search_all = search)

est = imap(specs, \(m, name) {
  dat = samples[[name]]
  tibble(
    spec = name,
    estimate = coef(m)[["treat_mayTRUE:postTRUE"]],
    se = se(m)[["treat_mayTRUE:postTRUE"]],
    n_obs = nobs(m),
    n_states = n_distinct(dat$state_po),
    n_treated = n_distinct(dat$state_po[dat$treat_may]),
    mde = se(m)[["treat_mayTRUE:postTRUE"]] * 2.80
  )
}) |>
  list_rbind()
print(est)

fmt = function(x, d = 2) formatC(x, format = "f", digits = d)

table_body = c(
  "\\begin{table}[t]",
  "\\centering",
  "\\caption{\\textbf{The Primary-Month Shift Is About Twice as Large in Google Searches as in Claude Conversations.}\\label{tab:search_did}}",
  "\\begin{tabular}{lccc}",
  "\\toprule \\toprule",
  " & Claude Politics & \\multicolumn{2}{c}{Google ``Primary Election'' Searches} \\\\",
  "\\cmidrule(lr){2-2} \\cmidrule(lr){3-4}",
  " & (1) & (2) & (3) \\\\",
  "\\midrule",
  glue("Primary $\\times$ May & {fmt(est$estimate[1])} & {fmt(est$estimate[2])} & {fmt(est$estimate[3])} \\\\"),
  glue(" & ({fmt(est$se[1])}) & ({fmt(est$se[2])}) & ({fmt(est$se[3])}) \\\\[2mm]"),
  glue("\\# States & {est$n_states[1]} & {est$n_states[2]} & {est$n_states[3]} \\\\"),
  glue("\\# Treated States & {est$n_treated[1]} & {est$n_treated[2]} & {est$n_treated[3]} \\\\"),
  glue("\\# Observations & {est$n_obs[1]} & {est$n_obs[2]} & {est$n_obs[3]} \\\\"),
  glue("Minimum Detectable Effect & {fmt(est$mde[1])} & {fmt(est$mde[2])} & {fmt(est$mde[3])} \\\\"),
  "\\midrule",
  "State Fixed Effects & Yes & Yes & Yes \\\\",
  "Month Fixed Effects & Yes & Yes & Yes \\\\",
  "AEI 30-State Sample & Yes & Yes & No \\\\",
  "\\bottomrule \\bottomrule",
  "\\multicolumn{4}{p{0.95\\textwidth}}{\\footnotesize \\textit{Notes}: Each column reports the same April-versus-May 2026 difference-in-differences with a log outcome, so estimates are comparable as proportional effects. Column 1 is the log politics-topic share of Claude conversations (as in Table~1, column 3). Columns 2 and 3 are log Google search interest in ``primary election,'' aggregated from weekly state series to calendar months; column 2 uses the same 30 states as column 1, and column 3 uses every jurisdiction except the five March-primary states. Trends indices are normalized within collection batch, a state-specific scaling absorbed by the state fixed effects under the log transformation. Standard errors clustered by state are in parentheses. The minimum detectable effect is 2.80 times the standard error.} \\\\",
  "\\end{tabular}",
  "\\end{table}"
)
cat(table_body, file = file.path(root, "output/search_did_table.tex"), sep = "\n")

# Slides twin: same numbers, no notes paragraph
slides_body = table_body[!str_detect(table_body, "footnotesize")]
cat(slides_body, file = file.path(root, "output/search_did_table_slides.tex"), sep = "\n")
