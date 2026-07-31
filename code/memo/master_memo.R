# master_memo.R -------------------------------------------------------------
# Reproduces draft/politics_memo/politics_memo.pdf end to end.
#
#   Rscript code/memo/master_memo.R
#
# Requires the AEI release CSV in original_data/ (downloaded by
# code/clean_aei_election_topics.R on first run of the main pipeline).
# ---------------------------------------------------------------------------
# Resolve the project root: run from the repo root and it just works;
# otherwise fall back to the repo-wide convention.
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

# R owns the estimation, tables and macros; Python owns every chart. The split
# is clean because figures.py reads only the CSVs 01 writes.
#
# Superseded by code/memo/figures.py and safe to delete: 02_memo_figures.R,
# fig_defs.R, 03_post_table_images.R, 03_post_images.R, 05_post_brand.R and
# 04_fig_politics_in_context.R. NB 05_cross_release_series.R is NOT one of
# them -- it is unrelated and still live.
source(file.path(root, "code/memo/01_memo_stats.R"))    # numbers/tables -> output/memo/

# plain PDFs -> output/memo/ (for the draft), branded PNGs -> output/post/
stopifnot(system2("python3", shQuote(file.path(root, "code/memo/figures.py"))) == 0)

# Compile the draft twice so refs resolve
memo = file.path(root, "draft/politics_memo")
for (i in 1:2) {
  system2("pdflatex", c("-interaction=nonstopmode", "-output-directory", shQuote(memo),
                        shQuote(file.path(memo, "politics_memo.tex"))), stdout = NULL)
}
message("[master] memo compiled: ", file.path(memo, "politics_memo.pdf"))
