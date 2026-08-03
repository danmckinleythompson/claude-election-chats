Google Trends weekly search interest, "primary election"
gt_primary_election_batch01.csv - batch11.csv

Weekly search interest (0-100 index) for the term "primary election", 6/29/2025
through 7/26/2026, for all 50 states + DC + the US, from trends.google.com.
Pulled 7/27-7/28/2026 in eleven batches of up to five geographies (Trends'
comparison limit), postal-alphabetical, national series in batch 11.

How these were collected: every scripted route to the Trends data endpoints
returns HTTP 429, and the site's own CSV export completed exactly once
(batch 1). The remaining batches were read off the rendered interest-over-time
chart in a browser: the chart SVG encodes each series as a path whose pixel
coordinates map linearly to index values, which decode to exact integers.
Validation: the decoded batch-1 values match the one genuine CSV export in all
280 complete state-weeks (gt_primary_election_batch01_validation.csv holds the
decoded copy; code/check_google_trends_decode.R re-runs the comparison).
Two conventions inherited from the export: values below 1 are recorded as "<1"
(plotted, and decoded, as 0), and the trailing partial week is dropped in
cleaning.

NB: Trends normalizes each batch to its own within-batch maximum of 100, so
levels are comparable within a batch but not across batches or states. All
analyses use within-state variation (state fixed effects, log outcomes),
which the batch scaling cannot affect.

The svg_decode_batchNN.json files (kept locally, not in git) are the raw
decoder output from which the CSVs were generated.
