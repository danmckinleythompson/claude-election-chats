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

source(file.path(root, "code/memo/01_memo_stats.R"))    # all numbers -> output/memo/
source(file.path(root, "code/memo/02_memo_figures.R"))  # all figures -> output/memo/

# Compile the draft twice so refs resolve
memo = file.path(root, "draft/politics_memo")
for (i in 1:2) {
  system2("pdflatex", c("-interaction=nonstopmode", "-output-directory", shQuote(memo),
                        shQuote(file.path(memo, "politics_memo.tex"))), stdout = NULL)
}
message("[master] memo compiled: ", file.path(memo, "politics_memo.pdf"))
