# Master script: runs the full pipeline in order
# Project: do Claude conversations shift toward politics when a state holds
# its primary? Diff-in-diff on the AEI Apr/May 2026 state-month topic shares,
# benchmarked against the same design in Google search data.
# NB: code/memo/master_memo.R (descriptive memo, AH) runs separately.
root = "~/Dropbox/AIElectionResearch"

# Set up the Claude data
source(file.path(root, "code/clean_aei_election_topics.R"))
source(file.path(root, "code/prep_aei_did_data.R"))

# Set up the Google search data (see original_data/google_trends/readme.txt
# for how the raw pulls were collected)
source(file.path(root, "code/clean_google_trends.R"))
source(file.path(root, "code/check_google_trends_decode.R"))
source(file.path(root, "code/prep_search_did_data.R"))

# Tables and figures (the table scripts also run the estimation)
source(file.path(root, "code/make_aei_did_table.R"))
source(file.path(root, "code/make_aei_politics_did.R"))
source(file.path(root, "code/make_aei_change_hist.R"))
source(file.path(root, "code/make_search_did_table.R"))
source(file.path(root, "code/make_search_did_plot.R"))
source(file.path(root, "code/make_search_event_study.R"))

# Blog figures in the Free Systems style (shared styling in _freesystems_style.R)
source(file.path(root, "code/make_did_spaghetti.R"))
source(file.path(root, "code/make_politics_arrows.R"))
