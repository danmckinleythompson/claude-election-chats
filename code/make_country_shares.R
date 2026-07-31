# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: politics-topic share by country, twelve highest and lowest
##

cty = read_csv(file.path(root, "modified_data/country_politics.csv"),
               show_col_types = FALSE)

top_bot = bind_rows(slice_max(cty, pct, n = 12), slice_min(cty, pct, n = 12)) |>
  distinct(country, .keep_all = TRUE) |>
  mutate(grp = factor(if_else(country == "USA", "United States", "Other countries"),
                      levels = c("United States", "Other countries")))

fig = ggplot(top_bot, aes(x = pct, y = fct_reorder(country, pct), fill = grp)) +
  geom_col(width = 0.72) +
  scale_fill_manual(values = c("United States" = blog_teal,
                               "Other countries" = blog_gray), name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.04)),
                     name = "Politics-topic share of conversations (%)") +
  labs(title = "Politics-Topic Share of Conversations, by Country",
       subtitle = "Twelve highest and twelve lowest countries, May 2026.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank())

blog_save(fig, "country_shares", height = 7.5, width = 8)
