# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: political and news topic shares at the two taxonomy levels
##

POLITICAL = c("Politics and public record", "Geopolitics and strategy",
              "Government filings", "News aggregation", "News writing",
              "Politics", "Geopolitics", "Elections", "Public records lookup")

shares = read_csv(file.path(root, "modified_data/us_topic_shares.csv"),
                  show_col_types = FALSE) |>
  filter(month == "may", topic %in% POLITICAL) |>
  # Keep each topic at its home level so aggregates never mix with leaves
  filter((lvl == 1 & topic %in% POLITICAL[1:3]) | (lvl == 0 & topic %in% POLITICAL[4:9])) |>
  mutate(panel = factor(if_else(lvl == 1, "Broad categories\n(level 1)",
                                "Specific topics\n(level 0)"),
                        levels = c("Broad categories\n(level 1)",
                                   "Specific topics\n(level 0)")))

fig = ggplot(shares, aes(x = pct, y = tidytext::reorder_within(topic, pct, panel))) +
  geom_col(width = 0.7, fill = blog_teal) +
  geom_text(aes(label = paste0(formatC(pct, format = "f", digits = 2), "%")),
            hjust = -0.15, size = 3.4, color = "gray25", fontface = "bold") +
  tidytext::scale_y_reordered() +
  facet_grid(rows = vars(panel), scales = "free_y", space = "free_y", switch = "y") +
  scale_x_continuous(limits = c(0, 0.58), expand = expansion(mult = c(0, 0)),
                     name = "Share of all US conversations (%)") +
  labs(title = "Political and News Topic Shares, by Taxonomy Level",
       subtitle = "United States, May 2026. The two panels are different levels of the topic taxonomy\nand overlap, so they do not sum.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank(),
        strip.placement = "outside", strip.background = element_blank(),
        strip.text.y.left = element_text(angle = 0, size = 9.5, color = "gray40"))

blog_save(fig, "taxonomy_levels", height = 6, width = 8)
