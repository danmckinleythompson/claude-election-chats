# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_freesystems_style.R"))

##
# Blog figure: dot-and-arrow plot of each state's April-to-May change in the
# politics-topic share. Dot = April, arrow tip = May; states sorted by April
# share with the group averages at the bottom
##

states = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
                  show_col_types = FALSE) |>
  filter(!march_primary) |>
  select(state_po, treat_may, post, politics_broad) |>
  pivot_wider(names_from = post, values_from = politics_broad) |>
  rename(apr = `FALSE`, may = `TRUE`)

averages = states |>
  group_by(treat_may) |>
  summarize(apr = mean(apr), may = mean(may), .groups = "drop") |>
  mutate(label = if_else(treat_may, "Avg. May-primary state", "Avg. later-primary state"))

# Rows: states sorted by April share (highest at top), a gap, then the two
# group averages at the very bottom; avg rows draw heavier
rows = bind_rows(
  averages |> arrange(treat_may) |> mutate(avg = TRUE),
  states |> arrange(apr) |> mutate(label = state_po, avg = FALSE)
) |>
  mutate(ypos = if_else(avg, row_number(), row_number() + 1))  # gap above averages

fig = ggplot(rows, aes(y = ypos, color = treat_may)) +
  geom_segment(aes(x = apr, xend = may, yend = ypos, linewidth = avg),
               arrow = arrow(length = unit(0.17, "cm"), type = "closed")) +
  geom_point(aes(x = apr, size = avg)) +
  scale_color_manual(values = c(`TRUE` = fs_blue_dark, `FALSE` = fs_blue_light),
                     guide = "none") +
  scale_linewidth_manual(values = c(`FALSE` = 0.8, `TRUE` = 1.4), guide = "none") +
  scale_size_manual(values = c(`FALSE` = 2.2, `TRUE` = 3.2), guide = "none") +
  scale_y_continuous(breaks = rows$ypos, labels = rows$label, expand = expansion(add = 0.7)) +
  annotate("segment", x = 0.28, xend = 1.12, y = 3.5, yend = 3.5,
           color = "gray75", linewidth = 0.4) +
  annotate("text", x = 0.80, y = 27,
           label = "Dot = April share\nArrow tip = May share",
           color = "gray25", size = 4.4, hjust = 0, lineheight = 1.05) +
  annotate("text", x = 0.80, y = 22.5,
           label = "Dark blue states held\nMay 2026 primaries",
           color = fs_blue_dark, size = 4.4, fontface = "bold", hjust = 0,
           lineheight = 1.05) +
  scale_x_continuous(limits = c(0.28, 1.12),
                     name = "% of state's Claude conversations about politics") +
  labs(title = "Political conversations rose where primaries were held",
       subtitle = "Each state's politics-topic share of Claude conversations, April to May 2026",
       y = NULL) +
  fs_theme(14) +
  theme(panel.grid.major.y = element_blank(),
        axis.text.y = element_text(size = 10.5, color = "gray20"),
        plot.title = element_text(size = 18))

fs_save(fig,
        note = "States ordered by April share. March-primary states (TX, NC, IL) excluded; states below the AEI privacy threshold in either month not shown. Group averages are unweighted.",
        stem = "politics_arrows", height = 11, width = 8.5)
