# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest, glue)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Table: diff-in-diff estimates of the primary-election effect on the Claude
# politics-topic share, Apr vs May 2026
##

aei = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
               show_col_types = FALSE)

# Main sample drops the already-treated March-primary states (TX, NC, IL)
main = aei |> filter(!march_primary)

# Anticipation check: June-primary states begin mail voting in May (CA, CO,
# UT are all- or mostly-mail), so also estimate against Jul-Sep controls only
no_june = main |> filter(treat_may | primary_date >= as.Date("2026-07-01"))

specs = list(
  main     = feols(politics_broad ~ treat_may * post | state_po + release,
                   data = main, cluster = ~state_po),
  no_june  = feols(politics_broad ~ treat_may * post | state_po + release,
                   data = no_june, cluster = ~state_po),
  log_main = feols(log(politics_broad) ~ treat_may * post | state_po + release,
                   data = main, cluster = ~state_po)
)

# One row per specification, with sample sizes and the control-group May mean
# recomputed from each estimation sample
est = imap(specs, \(m, name) {
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
print(est)

fmt = function(x, d = 2) formatC(x, format = "f", digits = d)

row_coef = glue("Primary $\\times$ May & {fmt(est$estimate[1])} & {fmt(est$estimate[2])} & {fmt(est$estimate[3])} \\\\")
row_se   = glue(" & ({fmt(est$se[1])}) & ({fmt(est$se[2])}) & ({fmt(est$se[3])}) \\\\[2mm]")

table_body = c(
  "\\begin{table}[t]",
  "\\centering",
  "\\caption{\\textbf{Claude Conversations Shift Toward Politics When a State Holds Its Primary.}\\label{tab:aei_did}}",
  "\\begin{tabular}{lccc}",
  "\\toprule \\toprule",
  " & \\multicolumn{2}{c}{Politics-Topic Share (\\%)} & Log Share \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-4}",
  " & (1) & (2) & (3) \\\\",
  "\\midrule",
  row_coef,
  row_se,
  glue("\\# States & {est$n_states[1]} & {est$n_states[2]} & {est$n_states[3]} \\\\"),
  glue("\\# Treated States & {est$n_treated[1]} & {est$n_treated[2]} & {est$n_treated[3]} \\\\"),
  glue("\\# Observations & {est$n_obs[1]} & {est$n_obs[2]} & {est$n_obs[3]} \\\\"),
  glue("Control May Mean & {fmt(est$control_may_mean[1])} & {fmt(est$control_may_mean[2])} & {fmt(est$control_may_mean[3])} \\\\"),
  glue("Minimum Detectable Effect & {fmt(est$mde[1])} & {fmt(est$mde[2])} & {fmt(est$mde[3])} \\\\"),
  "\\midrule",
  "State Fixed Effects & Yes & Yes & Yes \\\\",
  "Month Fixed Effects & Yes & Yes & Yes \\\\",
  "Excl.\\ June-Primary Controls & No & Yes & No \\\\",
  "\\bottomrule \\bottomrule",
  "\\multicolumn{4}{p{0.95\\textwidth}}{\\footnotesize \\textit{Notes}: Each column reports a difference-in-differences estimate comparing the politics-topic share of Claude conversations in April and May 2026 between states holding a statewide primary in May 2026 and states with later primaries. The outcome in columns 1 and 2 is the percent of a state's conversations assigned to the ``Politics and public record'' topic in the Anthropic Economic Index; column 3 uses its natural log. Texas, North Carolina, and Illinois, which held March primaries, are excluded. Column 2 further drops control states with June primaries, whose mail voting begins in May. Standard errors clustered by state are in parentheses. The minimum detectable effect is 2.80 times the standard error.} \\\\",
  "\\end{tabular}",
  "\\end{table}"
)
cat(table_body, file = file.path(root, "output/aei_did_table.tex"), sep = "\n")

# Slides twin: same numbers, no notes paragraph
slides_body = table_body[!str_detect(table_body, "footnotesize")]
cat(slides_body, file = file.path(root, "output/aei_did_table_slides.tex"), sep = "\n")
