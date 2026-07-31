# 03_post_images.R ----------------------------------------------------------
# Renders the post's assets to cropped, high-resolution PNGs.
#
# The post is figures only -- every finding that used to live in a table is now
# carried by a figure (the memo keeps the tables; see draft/politics_memo).
# This script therefore only rasterises PDFs; it no longer compiles LaTeX.
#
# Output is numbered in presentation order (post_01_... .. post_08_...) so the
# whole set can be multi-selected and dragged into the Google Doc in sequence.
#
# Depends on 02_memo_figures.R (output/memo) and 04_fig_politics_in_context.R
# (output/post), so master_memo.R sources 04 before this file.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue)
set.seed(42)
options(scipen = 999)
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

memo_dir = file.path(root, "output/memo")
post_dir = file.path(root, "output/post")
dir.create(post_dir, recursive = TRUE, showWarnings = FALSE)

## --- presentation order ------------------------------------------------------
# `dir` differs because the opening figure is built by 04 straight into
# output/post, while the rest are memo figures shared with the draft.
items = tribble(
  ~slot, ~dir,      ~src,                             ~out,
  "F0",  post_dir,  "fig_politics_in_context.pdf",    "post_01_F0_politics_in_context",
  "F1",  memo_dir,  "fig_topic_decomposition.pdf",    "post_02_F1_topic_breakdown",
  "F2",  memo_dir,  "fig_country_shares.pdf",         "post_03_F2_country_shares",
  "F3",  memo_dir,  "fig_artifacts.pdf",              "post_04_F3_artifacts",
  "F4",  memo_dir,  "fig_info_action.pdf",            "post_05_F4_info_vs_action",
  "F5",  memo_dir,  "fig_composition.pdf",            "post_06_F5_how_conducted",
  "F6",  memo_dir,  "fig_did_estimates.pdf",          "post_07_F6_did_estimates",
  "F7",  memo_dir,  "fig_null_distribution.pdf",      "post_08_F7_null_distribution"
)

## --- clear stale assets ------------------------------------------------------
# The post used to ship seven tables and a different numbering. Any post_*.png
# not in `items` is left over from that layout and would otherwise be dragged
# into the doc alongside its replacement.
keep = paste0(items$out, ".png")
stale = setdiff(basename(Sys.glob(file.path(post_dir, "post_*.png"))), keep)
if (length(stale)) {
  file.remove(file.path(post_dir, stale))
  message("[03] removed ", length(stale), " stale asset(s): ", paste(stale, collapse = ", "))
}

## --- render ------------------------------------------------------------------
for (i in seq_len(nrow(items))) {
  it = items[i, ]
  pdf = file.path(it$dir, it$src)
  if (!file.exists(pdf)) stop("missing source figure for ", it$slot, ": ", pdf)
  system2("pdftoppm", c("-png", "-r", "200", "-singlefile",
                        shQuote(pdf), shQuote(file.path(post_dir, it$out))))
}

made = file.path(post_dir, paste0(items$out, ".png"))
stopifnot(all(file.exists(made)))
message("[03] rendered ", nrow(items), " figures to ", post_dir)
print(tibble(slot = items$slot, file = paste0(items$out, ".png"),
             kb = round(file.size(made) / 1024)))
