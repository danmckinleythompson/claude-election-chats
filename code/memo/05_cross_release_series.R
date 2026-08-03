# 05_cross_release_series.R -------------------------------------------------
# Attempts a politics-share series across four AEI observation windows by
# hand-curating each release's leaf topics into one concept, rather than
# matching a single AEI cluster (which is what makes the naive series
# uninterpretable: the matched cluster's SCOPE changes between releases).
#
# READ THE VERDICT AT THE BOTTOM BEFORE USING THIS SERIES. The conclusion is
# that it still cannot support a claim about trend, for a reason that only
# becomes visible once the curation is done: the leaf taxonomy roughly
# doubles in granularity in the final release, and a fixed concept spreads
# across more, smaller leaves as granularity rises.
#
# Classification rule, fixed before any total was computed:
#   INCLUDE  conversations about politics, elections, government as a polity,
#            public policy, public administration, and political journalism.
#   EXCLUDE  marketing/advertising "campaigns"; commercial and sector
#            regulatory compliance; AI ethics and AI governance; crypto and
#            financial news; consumer-facing rules (driving, airline, vehicle);
#            general journalism craft with no political object.
# Every judgement call is recorded in `curation` below with a reason.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue)
set.seed(42)
options(scipen = 999)
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

BASE = file.path(root, "original_data/anthropic_economic_index")
outdir = file.path(root, "output/memo"); dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

## --- load every window on a common schema -----------------------------------
old_release = function(path, label, window_mid) {
  read_csv(file.path(BASE, path), show_col_types = FALSE) |>
    filter(facet == "request", variable == "request_pct",
           geography == "country", geo_id == "US") |>
    transmute(release = label, window_mid = as.Date(window_mid),
              level, topic = cluster_name, pct = value)
}
new_release = function(path, label, d, window_mid) {
  read_csv(file.path(BASE, path), show_col_types = FALSE) |>
    filter(category_name == "request", metric_id == "pct",
           geo_id == "USA", date_start == d) |>
    transmute(release = label, window_mid = as.Date(window_mid),
              level = hierarchy_level, topic = node_name, pct = value)
}

all = bind_rows(
  old_release("release_2025_09_15/aei_raw_claude_ai_2025-08-04.csv", "aug2025", "2025-08-07"),
  old_release("release_2026_01_15/aei_raw_claude_ai_2025-11-13.csv", "nov2025", "2025-11-16"),
  old_release("release_2026_03_24/aei_raw_claude_ai_2026-02-05.csv", "feb2026", "2026-02-08"),
  new_release("release_2026_06_26/aei_claude_ai_2026-06-26.csv", "apr2026", "2026-04-01", "2026-04-15"),
  new_release("release_2026_06_26/aei_claude_ai_2026-06-26.csv", "may2026", "2026-05-01", "2026-05-15"))

## --- the curation -----------------------------------------------------------
# Leaf (level 0) topics judged to be about politics/government/public affairs.
curation = tribble(
  ~release,  ~topic,                                                                                     ~keep, ~why,
  "aug2025", "Provide information and analysis about political systems and governance",                   TRUE,  "core politics",
  "aug2025", "Analyze controversial political topics and polarizing social issues",                       TRUE,  "core politics",
  "aug2025", "Analyze geopolitical conflicts, wars, and international security issues",                   TRUE,  "geopolitics",
  "aug2025", "Draft and revise formal government and institutional correspondence",                       TRUE,  "citizen-government correspondence",
  "aug2025", "Help with news article writing, editing, and journalism tasks",                             FALSE, "journalism craft, no political object",
  "aug2025", "Provide information about driving laws, licenses, and vehicle regulations",                 FALSE, "consumer rules",

  "nov2025", "Assist with practical political campaign work and electoral information research",          TRUE,  "core electoral",
  "nov2025", "Research government policies, regulations, programs, and official documents",               TRUE,  "government/policy",
  "nov2025", "Complete political science and political philosophy academic assignments and analyses",     TRUE,  "political academic",
  "nov2025", "Analyze and create political journalism and media criticism content",                       TRUE,  "political journalism",
  "nov2025", "Assist with public administration, governance, and policy academic and professional work",  TRUE,  "public administration",
  "nov2025", "Discuss AI ethics, societal impacts, governance, consciousness, and future implications",   FALSE, "AI governance, not government",
  "nov2025", "Write original journalistic articles and news content with specific formatting requirements",FALSE, "journalism craft",
  "nov2025", "Access, retrieve, summarize, and organize news articles and current information",           FALSE, "general news retrieval",
  "nov2025", "Summarize and format cryptocurrency news and market information",                           FALSE, "crypto/financial news",

  "feb2026", "Analyze and create political journalism and media criticism content",                       TRUE,  "political journalism",
  "feb2026", "Assist with public administration, governance, and policy academic and professional work",  TRUE,  "public administration",
  "feb2026", "Assist with practical political campaign work and electoral information research",          TRUE,  "core electoral",
  "feb2026", "Provide information about government benefits and social service programs",                 TRUE,  "government services",
  "feb2026", "Complete political science and political philosophy academic assignments and analyses",     TRUE,  "political academic",
  "feb2026", "Help with international relations and geopolitics academic work and analysis",              TRUE,  "geopolitics",
  "feb2026", "Identify current political leaders, CEOs, and election winners",                            TRUE,  "electoral facts",
  "feb2026", "Discuss AI ethics, societal impacts, governance, consciousness, and future implications",   FALSE, "AI governance",
  "feb2026", "Write original journalistic articles and news content with specific formatting requirements",FALSE, "journalism craft",
  "feb2026", "Analyze and extract structured data from cryptocurrency social media and news content",     FALSE, "crypto news",
  "feb2026", "Research business regulatory compliance, licensing, taxation, and international trade laws",FALSE, "commercial compliance",
  "feb2026", "Provide technical assistance with medical device development and regulatory compliance",    FALSE, "commercial compliance",
  "feb2026", "Access, retrieve, summarize, and organize news articles and current information",           FALSE, "general news retrieval")

# The 2026-06 releases use short labels; curate them the same way.
keep_2026 = c("Politics", "Geopolitics", "Elections", "Law and governance",
              "Public records lookup", "Political science", "Political strategy",
              "Energy geopolitics", "Government structure", "Trade policy",
              "Legislative drafting", "Health policy")
drop_2026 = c("News aggregation", "News writing", "Financial news analysis",
              "Regulatory compliance", "Airline policy", "Insurance regulation",
              "Sector regulation", "Crypto regulation", "Vehicle regulations",
              "Regulatory documents")
curation = bind_rows(curation,
  expand_grid(release = c("apr2026", "may2026"), topic = keep_2026) |>
    mutate(keep = TRUE, why = "core politics/government"),
  expand_grid(release = c("apr2026", "may2026"), topic = drop_2026) |>
    mutate(keep = FALSE, why = "news craft, commercial or consumer regulation"))

## --- build the series -------------------------------------------------------
leaves = all |> filter(level == 0)
series = curation |> filter(keep) |>
  left_join(leaves, by = c("release", "topic")) |>
  group_by(release) |>
  summarise(politics_pct = sum(pct, na.rm = TRUE),
            n_topics_kept = sum(!is.na(pct)), .groups = "drop")

granularity = leaves |> count(release, name = "n_leaves")
window_mid = all |> distinct(release, window_mid)
series = series |> left_join(granularity, by = "release") |>
  left_join(window_mid, by = "release") |> arrange(window_mid)

missing = curation |> filter(keep) |> anti_join(leaves, by = c("release", "topic"))
if (nrow(missing)) { cat("\n!! curated topics not found in data:\n"); print(missing) }

cat("\n=== curated politics share by window ===\n"); print(series)
cat("\n=== granularity check: leaves per release ===\n")
print(leaves |> count(release) |> arrange(release))
write_csv(series, file.path(outdir, "cross_release_series.csv"))
write_csv(curation, file.path(outdir, "cross_release_curation.csv"))

## --- figure -----------------------------------------------------------------
# Points are connected ONLY within a granularity regime. Connecting across the
# break would draw a decline that is an artefact of the taxonomy, not behaviour.
series = series |> mutate(regime = if_else(n_leaves < 700, "early", "late"))

fig = ggplot(series, aes(x = window_mid, y = politics_pct)) +
  annotate("rect", xmin = as.Date("2026-03-10"), xmax = as.Date("2026-06-10"),
           ymin = -Inf, ymax = Inf, fill = "grey93") +
  geom_vline(xintercept = as.Date("2025-11-04"), colour = "grey70", linetype = "dashed") +
  geom_vline(xintercept = as.Date("2026-03-03"), colour = "grey70", linetype = "dashed") +
  geom_line(aes(group = regime), colour = "grey25", linewidth = 0.9) +
  geom_point(colour = "#B2182B", size = 3.4) +
  geom_text(aes(label = sprintf("%.2f", politics_pct)), vjust = -1.1, size = 4.2,
            colour = "grey20") +
  annotate("text", x = as.Date("2025-11-06"), y = 0.36, hjust = 0, size = 4,
           colour = "grey40", label = "Nov 2025\nelections", lineheight = 0.9) +
  annotate("text", x = as.Date("2026-03-05"), y = 0.36, hjust = 0, size = 4,
           colour = "grey40", label = "First 2026\nprimaries", lineheight = 0.9) +
  annotate("text", x = as.Date("2026-04-25"), y = 1.02, hjust = 0.5, size = 4,
           colour = "grey35", fontface = "italic",
           label = "taxonomy resolves\n~1.5x more topics") +
  scale_y_continuous(limits = c(0.3, 1.2)) +
  labs(title = "Curated Politics Share of US Claude Conversations, Four AEI Windows",
       subtitle = paste("Leaf topics hand-classified to a fixed concept in each release.",
                        "Points are connected only within a granularity regime;",
                        "levels are not comparable across the break.", sep = "\n"),
       x = NULL, y = "Share of US conversations (%)") +
  theme_classic(base_size = 15) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        plot.title = element_text(face = "bold", size = 15),
        plot.subtitle = element_text(colour = "grey35", size = 11, lineheight = 1.15))

ggsave(file.path(root, "output/post/fig_cross_release_series.pdf"), fig,
       width = 10, height = 6.2)
system2("pdftoppm", c("-png", "-r", "200", "-singlefile",
                      shQuote(file.path(root, "output/post/fig_cross_release_series.pdf")),
                      shQuote(file.path(root, "output/post/fig_cross_release_series"))))

## --- verdict ----------------------------------------------------------------
g_early = series$n_leaves[series$release != "may2026" & series$release != "apr2026"]
cat("\n---------------------------------------------------------------\n")
cat("VERDICT\n")
cat("Leaf granularity: ", paste(series$release, series$n_leaves, sep = "="), "\n")
cat("The 2026-06 release resolves roughly", round(mean(series$n_leaves[series$release %in%
      c("apr2026","may2026")]) / mean(g_early), 2), "x as many leaves as the earlier ones.\n")
cat("A fixed concept spreads across more, smaller leaves as granularity rises,\n")
cat("so the final two windows are NOT comparable in level to the first three,\n")
cat("even after curation. Compare only within a granularity regime.\n")
