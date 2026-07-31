# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: dot-and-arrow plot of each state's April-to-May change in the
# politics-topic share. Dot = April, arrow tip = May; states sorted by April
# share with the group averages at the bottom
##

states = read_csv(file.path(root, "modified_data/did_panel.csv"),
                  show_col_types = FALSE) |>
  select(state_po, treat_may, post, pct) |>
  pivot_wider(names_from = post, values_from = pct) |>
  rename(apr = `FALSE`, may = `TRUE`)

averages = states |>
  group_by(treat_may) |>
  summarize(apr = mean(apr), may = mean(may), .groups = "drop") |>
  mutate(label = if_else(treat_may, "Avg. May-primary state", "Avg. later-primary state"))

rows = bind_rows(
  averages |> arrange(treat_may) |> mutate(avg = TRUE),
  states |> arrange(apr) |> mutate(label = state_po, avg = FALSE)
) |>
  mutate(ypos = if_else(avg, row_number(), row_number() + 1))  # gap above averages

fig = ggplot(rows, aes(y = ypos, color = treat_may)) +
  geom_segment(aes(x = apr, xend = may, yend = ypos, linewidth = avg),
               arrow = arrow(length = unit(0.16, "cm"), type = "closed")) +
  geom_point(aes(x = apr, size = avg)) +
  scale_color_manual(values = c(`TRUE` = blog_teal, `FALSE` = blog_gray),
                     guide = "none") +
  scale_linewidth_manual(values = c(`FALSE` = 0.8, `TRUE` = 1.5), guide = "none") +
  scale_size_manual(values = c(`FALSE` = 2, `TRUE` = 3), guide = "none") +
  scale_y_continuous(breaks = rows$ypos, labels = rows$label,
                     expand = expansion(add = 0.7)) +
  annotate("segment", x = 0.28, xend = 1.12, y = 3.5, yend = 3.5,
           color = blog_border, linewidth = 0.5) +
  annotate("text", x = 0.82, y = 27, label = "Dot = April share\nArrow tip = May share",
           color = "gray30", size = 3.6, hjust = 0, lineheight = 1.1) +
  annotate("text", x = 0.82, y = 22.5, label = "Teal states held\nMay 2026 primaries",
           color = blog_teal, size = 3.6, fontface = "bold", hjust = 0, lineheight = 1.1) +
  scale_x_continuous(limits = c(0.28, 1.12),
                     name = "% of state's Claude conversations about politics") +
  labs(title = "Change in Politics-Topic Share, by State",
       subtitle = "April to May 2026. States ordered by April share. March-primary states (TX, NC, IL)\nexcluded, as are states below the AEI privacy threshold in either month.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(size = 8.5))

blog_save(fig, "politics_arrows", height = 9.5, width = 8)
