# Master script: runs the full pipeline in order
# Project: the figures for the Free Systems post "Quantifying the Information
# Layer" - how people use Claude for politics, and the effect of holding a
# primary, from the Anthropic Economic Index June 2026 release.
root = "~/Dropbox/AIElectionResearch"

# Set up the data (the cleaning script downloads the ~210MB AEI release from
# Hugging Face on first run)
source(file.path(root, "code/clean_aei_topics.R"))
source(file.path(root, "code/prep_did_data.R"))

# Produce estimates
source(file.path(root, "code/estimate_topic_dids.R"))

# Figures, in the order they appear in the post (shared styling in
# _blog_style.R; each writes pdf + png twins to output/)
source(file.path(root, "code/make_us_topic_shares.R"))
source(file.path(root, "code/make_taxonomy_levels.R"))
source(file.path(root, "code/make_country_shares.R"))
source(file.path(root, "code/make_artifacts_dumbbell.R"))
source(file.path(root, "code/make_topic_outputs.R"))
source(file.path(root, "code/make_politics_composition.R"))
source(file.path(root, "code/make_politics_arrows.R"))
source(file.path(root, "code/make_did_group_change.R"))
source(file.path(root, "code/make_did_spaghetti.R"))
source(file.path(root, "code/make_topic_effects.R"))
source(file.path(root, "code/make_tstat_distribution.R"))
