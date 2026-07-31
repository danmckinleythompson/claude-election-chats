# 03_post_table_images.R ----------------------------------------------------
# Renders each memo table to a cropped, high-resolution PNG by compiling the
# SAME generated_*.tex fragments the memo uses, via the standalone class.
# The post's tables are therefore typographically identical to the memo's and
# cannot drift from them.
#
# Output is numbered in presentation order (post_01_... .. post_11_...) so the
# whole set can be multi-selected and dragged into the Google Doc in sequence.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, fixest, glue)
set.seed(42)
options(scipen = 999)
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

memo_dir = file.path(root, "output/memo")
post_dir = file.path(root, "output/post")
tmp_dir  = file.path(post_dir, "_tex")
dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
fmt = function(x, d = 2) formatC(x, format = "f", digits = d)

## --- T5: a clean post version of the main DiD table -------------------------
# The repo's output/aei_did_table.tex is a full float with a notes paragraph;
# for the post we want the bare tabular, recomputed rather than transcribed.
aei = read_csv(file.path(root, "modified_data/aei_did_data.csv"), show_col_types = FALSE)
main = aei |> filter(!march_primary)
no_june = main |> filter(treat_may | primary_date >= as.Date("2026-07-01"))
nm = "treat_mayTRUE:postTRUE"
fit = function(d, log = FALSE) feols(
  if (log) log(politics_broad) ~ treat_may * post | state_po + release
  else politics_broad ~ treat_may * post | state_po + release,
  data = d, cluster = ~state_po)
ms = list(fit(main), fit(no_june), fit(main, log = TRUE))
ds = list(main, no_june, main)
b  = map_chr(ms, \(m) fmt(coef(m)[[nm]]))
s  = map_chr(ms, \(m) paste0("(", fmt(se(m)[[nm]]), ")"))
ns = map_chr(ds, \(d) as.character(n_distinct(d$state_po)))
nt = map_chr(ds, \(d) as.character(n_distinct(d$state_po[d$treat_may])))
cm = map_chr(ds, \(d) fmt(mean(d$politics_broad[!d$treat_may & d$post])))
c("\\begin{tabular}{lccc}", "\\toprule \\toprule",
  " & \\multicolumn{2}{c}{Politics-Topic Share (\\%)} & Log Share \\\\",
  "\\cmidrule(lr){2-3} \\cmidrule(lr){4-4}",
  " & (1) & (2) & (3) \\\\", "\\midrule",
  glue("Primary $\\times$ May & {b[1]} & {b[2]} & {b[3]} \\\\"),
  glue(" & {s[1]} & {s[2]} & {s[3]} \\\\[2mm]"),
  glue("\\# States & {ns[1]} & {ns[2]} & {ns[3]} \\\\"),
  glue("\\# Treated States & {nt[1]} & {nt[2]} & {nt[3]} \\\\"),
  glue("Control May Mean & {cm[1]} & {cm[2]} & {cm[3]} \\\\"), "\\midrule",
  "State Fixed Effects & Yes & Yes & Yes \\\\",
  "Month Fixed Effects & Yes & Yes & Yes \\\\",
  "Excl.\\ June-Primary Controls & No & Yes & No \\\\",
  "\\bottomrule \\bottomrule", "\\end{tabular}") |>
  writeLines(file.path(memo_dir, "generated_post_did_table.tex"))

## --- presentation order ------------------------------------------------------
items = tribble(
  ~slot, ~kind,    ~src,                                ~out,
  "T1",  "table",  "generated_topic_table.tex",         "post_01_T1_topics",
  "F1",  "figure", "fig_topic_decomposition.pdf",       "post_02_F1_topic_decomposition",
  "F2",  "figure", "fig_country_shares.pdf",            "post_03_F2_country_shares",
  "T2",  "table",  "generated_composition_table.tex",   "post_04_T2_composition",
  "F3",  "figure", "fig_artifacts.pdf",                 "post_05_F3_artifacts",
  "T3",  "table",  "generated_artifact_table.tex",      "post_06_T3_artifacts",
  "T4",  "table",  "generated_profile_table.tex",       "post_07_T4_info_action_by_topic",
  "T5",  "table",  "generated_post_did_table.tex",      "post_08_T5_did",
  "T6",  "table",  "generated_specificity_table.tex",   "post_09_T6_specificity",
  "F4",  "figure", "fig_null_distribution.pdf",         "post_10_F4_null_distribution",
  "T7",  "table",  "generated_null_top_table.tex",      "post_11_T7_null_top"
)

## --- render -----------------------------------------------------------------
preamble = c(
  "\\documentclass[border=12pt,varwidth=\\maxdimen]{standalone}",
  "\\usepackage{booktabs}", "\\usepackage[T1]{fontenc}",
  "\\usepackage{newtxtext,newtxmath}", "\\usepackage{xcolor}",
  "\\begin{document}")

for (i in seq_len(nrow(items))) {
  it = items[i, ]
  out_base = file.path(post_dir, it$out)
  if (it$kind == "figure") {
    system2("pdftoppm", c("-png", "-r", "200", "-singlefile",
                          shQuote(file.path(memo_dir, it$src)), shQuote(out_base)))
  } else {
    texfile = file.path(tmp_dir, paste0(it$out, ".tex"))
    c(preamble, readLines(file.path(memo_dir, it$src)), "\\end{document}") |>
      writeLines(texfile)
    system2("pdflatex", c("-interaction=nonstopmode", "-output-directory",
                          shQuote(tmp_dir), shQuote(texfile)), stdout = NULL, stderr = NULL)
    pdf = file.path(tmp_dir, paste0(it$out, ".pdf"))
    if (!file.exists(pdf)) stop("failed to compile table ", it$slot, " (", it$src, ")")
    system2("pdftoppm", c("-png", "-r", "300", "-singlefile", shQuote(pdf), shQuote(out_base)))
  }
}

made = file.path(post_dir, paste0(items$out, ".png"))
stopifnot(all(file.exists(made)))
message("[03] rendered ", nrow(items), " assets to ", post_dir)
print(tibble(slot = items$slot, file = paste0(items$out, ".png"),
             kb = round(file.size(made) / 1024)))
