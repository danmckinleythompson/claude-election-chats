# master.R -- the Google search benchmark only.
#
# THE POST IS PYTHON. Run `python3 code/master.py` for everything the post
# uses: code/analysis.py does the cleaning, panel construction and estimation,
# code/figures.py draws. Nothing below feeds the post.
#
# What is left here is the search-benchmark robustness check -- the same
# diff-in-differences design applied to Google Trends search volume, which the
# Claude estimate is benchmarked against. It is the last R in the repo and is
# pending a port to Python; until then it runs on its own.
#
# NB the Claude side of that comparison now comes from code/analysis.py, so
# make_aei_did_table.R / make_aei_politics_did.R / make_aei_change_hist.R
# recompute estimates Python already produces. Port or retire them together.
root = "~/Dropbox/AIElectionResearch"

# Google search data (see original_data/google_trends/readme.txt for how the
# raw pulls were collected)
source(file.path(root, "code/clean_google_trends.R"))
source(file.path(root, "code/check_google_trends_decode.R"))
source(file.path(root, "code/prep_search_did_data.R"))

# Estimation and outputs (the table script also runs the estimation)
source(file.path(root, "code/make_search_did_table.R"))
source(file.path(root, "code/make_search_did_plot.R"))
source(file.path(root, "code/make_search_event_study.R"))
