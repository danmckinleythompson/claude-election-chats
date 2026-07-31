# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, patchwork, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_freesystems_style.R"))

##
# Blog figure: three-panel diff-in-diff spaghetti - each group's states thin
# and light with the group average bold on top, then the averages compared
##

aei = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
               show_col_types = FALSE) |>
  filter(!march_primary) |>
  mutate(x = if_else(post, 2, 1))

means = aei |>
  group_by(treat_may, x) |>
  summarize(mean_pct = mean(politics_broad), .groups = "drop")

xsc = scale_x_continuous(breaks = c(1, 2), labels = c("April 2026", "May 2026"),
                         limits = c(0.85, 2.75))
panel_theme = fs_theme(15) +
  theme(plot.title = element_text(face = "bold", size = 14, hjust = 0))

# One panel: a group's states thin and light, its average bold on top
group_panel = function(treated, light, dark, title, ylab) {
  ggplot() +
    geom_line(data = aei |> filter(treat_may == treated),
              aes(x = x, y = politics_broad, group = state_po),
              color = light, linewidth = 0.9) +
    geom_line(data = means |> filter(treat_may == treated),
              aes(x = x, y = mean_pct), color = dark, linewidth = 2.2) +
    geom_point(data = means |> filter(treat_may == treated),
               aes(x = x, y = mean_pct), color = dark, size = 3.5) +
    annotate("text", x = 2.08,
             y = means |> filter(treat_may == treated, x == 2) |> pull(mean_pct),
             label = "Average", color = dark, size = 4.6, fontface = "bold",
             hjust = 0) +
    labs(title = title, x = NULL, y = ylab) +
    xsc + coord_cartesian(ylim = c(0.30, 0.75)) + panel_theme
}

p1 = group_panel(TRUE, fs_blue_light, fs_blue_dark,
                 "States with May 2026 primaries (8)", NULL)
p2 = group_panel(FALSE, fs_gray_light, fs_gray_dark,
                 "States with June-September primaries (22)",
                 "% of state's Claude conversations about politics")

p3 = ggplot(means, aes(x = x, y = mean_pct, color = treat_may,
                       linetype = treat_may)) +
  geom_line(linewidth = 2.2) +
  geom_point(size = 3.5) +
  scale_color_manual(values = c(`TRUE` = fs_blue_dark, `FALSE` = fs_gray_dark),
                     guide = "none") +
  scale_linetype_manual(values = c(`TRUE` = "solid", `FALSE` = "42"),
                        guide = "none") +
  annotate("text", x = 2.08, y = 0.505, label = "May primary",
           color = fs_blue_dark, size = 4.6, fontface = "bold", hjust = 0) +
  annotate("text", x = 2.08, y = 0.476, label = "Later primary",
           color = fs_gray_dark, size = 4.6, fontface = "bold", hjust = 0) +
  labs(title = "The averages, compared", x = NULL, y = NULL) +
  xsc + coord_cartesian(ylim = c(0.30, 0.75)) + panel_theme

fig = p1 / p2 / p3 +
  plot_annotation(
    title = "Claude conversations shift toward politics when a state votes",
    theme = theme(plot.title = element_text(face = "bold", size = 19, hjust = 0.5),
                  plot.background = element_rect(fill = "white", color = NA)))

fs_save(fig,
        note = "Share of each state's Claude conversations in the AEI \"Politics and public record\" topic. March-primary states excluded; DC (1.0-1.1%) above plotted range.",
        stem = "did_spaghetti", height = 12.5, width = 8.5)
