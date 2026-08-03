# Master script: runs the full pipeline in order
# Project: does AI usage respond to upcoming elections the way search does?
root = "~/Dropbox/AIElectionResearch"

# Set up the data
# NB: the Google Trends batches in original_data/google_trends/ were collected
# through the browser (see notes/google_trends_pull_notes.txt); the decode
# step below converts them and is a python script:
#python: code/convert_trends_svg_decode.py
source(file.path(root, "code/clean_aei_election_topics.R"))
source(file.path(root, "code/clean_google_trends.R"))
source(file.path(root, "code/check_google_trends_decode.R"))
source(file.path(root, "code/prep_aei_did_data.R"))
source(file.path(root, "code/prep_trends_event_study_data.R"))

# Produce estimates
source(file.path(root, "code/estimate_aei_did.R"))
source(file.path(root, "code/estimate_trends_event_study.R"))

# Tables and figures
source(file.path(root, "code/make_aei_politics_did.R"))
source(file.path(root, "code/make_aei_change_hist.R"))
source(file.path(root, "code/make_aei_politics_did_june.R"))
source(file.path(root, "code/make_aei_did_table.R"))
source(file.path(root, "code/make_national_claude_series.R"))
source(file.path(root, "code/make_national_trends_series.R"))
source(file.path(root, "code/make_trends_raw_event_means.R"))
source(file.path(root, "code/make_trends_event_study.R"))
