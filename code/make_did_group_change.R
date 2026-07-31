# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: the two group averages' April-to-May changes, as a compact
# summary strip
##

changes = read_csv(file.path(root, "modified_data/did_panel.csv"),
                   show_col_types = FALSE) |>
  group_by(treat_may, post) |>
  summarize(mean_pct = mean(pct), .groups = "drop") |>
  pivot_wider(names_from = post, values_from = mean_pct) |>
  mutate(change = `TRUE` - `FALSE`,
         label = if_else(treat_may, "May-primary states (8)", "Later-primary states (22)"))

fig = ggplot(changes, aes(x = change, y = fct_reorder(label, change))) +
  geom_col(aes(fill = treat_may), width = 0.6) +
  geom_text(aes(label = if_else(abs(change) < 0.005, "no change",
                                sprintf("%+.2f pp", change)),
                hjust = if_else(abs(change) < 0.005, -0.15, -0.2),
                color = treat_may),
            size = 3.6, fontface = "bold") +
  scale_fill_manual(values = c(`TRUE` = blog_teal, `FALSE` = blog_gray), guide = "none") +
  scale_color_manual(values = c(`TRUE` = blog_teal, `FALSE` = "gray45"), guide = "none") +
  scale_x_continuous(limits = c(0, 0.155), expand = expansion(mult = c(0, 0)),
                     breaks = seq(0, 0.15, 0.05),
                     labels = c("0", "+0.05", "+0.10", "+0.15"),
                     name = "Change in the group's unweighted average, April to May (pp)") +
  labs(title = NULL, y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank())

blog_save(fig, "did_group_change", height = 2.6, width = 8)
