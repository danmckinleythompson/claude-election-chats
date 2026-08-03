# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Check the SVG-decoded Google Trends values against the one batch downloaded
# through the site's own CSV export
##

# Both files cover the same five states; the downloaded file has "<1" strings
# where the chart (and so the decode) shows 0
read_batch = function(file) {
  read_csv(file.path(root, "original_data/google_trends", file),
           skip = 2, col_types = cols(.default = col_character())) |>
    pivot_longer(-Week, names_to = "geo_name", values_to = "raw") |>
    mutate(index = if_else(raw == "<1", 0, suppressWarnings(as.numeric(raw)))) |>
    filter(as.Date(Week) < as.Date("2026-07-26"))
}

downloaded = read_batch("gt_primary_election_batch01.csv")
decoded = read_batch("gt_primary_election_batch01_validation.csv")

comparison = downloaded |>
  inner_join(decoded, by = c("Week", "geo_name"), suffix = c("_dl", "_svg"))
stopifnot(nrow(comparison) == 56 * 5)
stopifnot(all(comparison$index_dl == comparison$index_svg))

cat("Decode check passed:", nrow(comparison), "state-weeks identical\n")
