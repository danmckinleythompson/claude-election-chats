# 02_memo_figures.R ---------------------------------------------------------
# Plain figures for draft/politics_memo. Geometry lives in fig_defs.R, which
# 05_post_brand.R also uses, so the memo and the post can never show different
# versions of the same chart.
#
# Only the four figures the draft \includegraphics are written here; the rest
# are post-only and are produced by 05. Titles and subtitles are dropped: in
# the memo that job belongs to the LaTeX \caption.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue)
set.seed(42)
options(scipen = 999)
# Resolve the project root: run from the repo root and it just works;
# otherwise fall back to the repo-wide convention.
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

source(file.path(root, "code/memo/fig_defs.R"))
outdir = file.path(root, "output/memo")

memo_figs = FIGS |> filter(memo)
for (i in seq_len(nrow(memo_figs))) {
  f = memo_figs[i, ]
  spec = f$fn[[1]](memo_pal, outdir, root)
  ggsave(file.path(outdir, glue("fig_{f$key}.pdf")), spec$plot,
         width = spec$w, height = spec$h)
}

message("[02] wrote ", nrow(memo_figs), " memo figures to ", outdir)
print(tibble(slot = memo_figs$slot, file = glue("fig_{memo_figs$key}.pdf")))
