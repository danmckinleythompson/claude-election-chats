# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, patchwork, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: politics-topic share before and after a state's primary -
# each group's states thin and light, group average bold, then the averages
##

aei = read_csv(file.path(root, "modified_data/did_panel.csv"),
               show_col_types = FALSE) |>
  mutate(x = if_else(post, 2, 1))

means = aei |>
  group_by(treat_may, x) |>
  summarize(mean_pct = mean(pct), .groups = "drop")

xsc = scale_x_continuous(breaks = c(1, 2), labels = c("April 2026", "May 2026"),
                         limits = c(0.85, 2.75))
panel_theme = blog_theme(13) +
  theme(plot.title = element_text(face = "bold", size = 11.5, hjust = 0.5,
                                  color = "gray20"))

# Light shades for the individual state lines within each group
light_of = c(`TRUE` = "#A8C6CD", `FALSE` = "#DAD5C7")
dark_of  = c(`TRUE` = blog_teal, `FALSE` = "#6B675C")

# One panel: a group's states thin and light, its average bold on top
group_panel = function(treated, title) {
  ggplot() +
    geom_line(data = aei |> filter(treat_may == treated),
              aes(x = x, y = pct, group = state_po),
              color = light_of[[as.character(treated)]], linewidth = 0.8) +
    geom_line(data = means |> filter(treat_may == treated),
              aes(x = x, y = mean_pct), color = dark_of[[as.character(treated)]],
              linewidth = 2) +
    geom_point(data = means |> filter(treat_may == treated),
               aes(x = x, y = mean_pct), color = dark_of[[as.character(treated)]],
               size = 3) +
    annotate("text", x = 2.08,
             y = means |> filter(treat_may == treated, x == 2) |> pull(mean_pct),
             label = "Average", color = dark_of[[as.character(treated)]],
             size = 3.8, fontface = "bold", hjust = 0) +
    labs(title = title, x = NULL, y = NULL) +
    xsc + coord_cartesian(ylim = c(0.30, 0.75)) + panel_theme
}

p1 = group_panel(TRUE, "States with May 2026 primaries (8)")
p2 = group_panel(FALSE, "States with June-September primaries (22)") +
  labs(y = "% of state's Claude conversations about politics")

p3 = ggplot(means, aes(x = x, y = mean_pct, color = treat_may, linetype = treat_may)) +
  geom_line(linewidth = 2) +
  geom_point(size = 3) +
  scale_color_manual(values = dark_of, guide = "none") +
  scale_linetype_manual(values = c(`TRUE` = "solid", `FALSE` = "42"), guide = "none") +
  annotate("text", x = 2.08, y = 0.505, label = "May primary",
           color = blog_teal, size = 3.8, fontface = "bold", hjust = 0) +
  annotate("text", x = 2.08, y = 0.476, label = "Later primary",
           color = "#6B675C", size = 3.8, fontface = "bold", hjust = 0) +
  labs(title = "The averages, compared", x = NULL, y = NULL) +
  xsc + coord_cartesian(ylim = c(0.30, 0.75)) + panel_theme

fig = p1 / p2 / p3 +
  plot_annotation(
    title = "Politics-Topic Share Before and After a State's Primary",
    subtitle = "Each thin line is one state; the bold line is the unweighted group average.\nMarch-primary states excluded; DC (1.0-1.1%) is above the plotted range.",
    theme = theme(plot.title = element_text(face = "bold", size = 16, hjust = 0,
                                            color = blog_dark),
                  plot.subtitle = element_text(size = 10.5, hjust = 0, color = "gray40",
                                               lineheight = 1.15),
                  plot.background = element_rect(fill = blog_bg, color = NA)))

blog_save(fig, "did_spaghetti", height = 11.5, width = 7.5)
