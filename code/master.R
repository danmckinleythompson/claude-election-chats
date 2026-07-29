# Master script: runs the full pipeline in order
# Project: do Claude conversations shift toward politics when a state holds
# its primary? Diff-in-diff on the AEI Apr/May 2026 state-month topic shares.
# The Google Trends comparison and full paper pipeline are archived in
# code/xarchive/ (see xarchive/master_full_pipeline.R).
root = "~/Dropbox/AIElectionResearch"

# Set up the data
source(file.path(root, "code/clean_aei_election_topics.R"))
source(file.path(root, "code/prep_aei_did_data.R"))

# Table and figures (the table script also runs the estimation)
source(file.path(root, "code/make_aei_did_table.R"))
source(file.path(root, "code/make_aei_politics_did.R"))
source(file.path(root, "code/make_aei_change_hist.R"))
