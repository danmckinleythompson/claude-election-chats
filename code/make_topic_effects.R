# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: the estimated effect of a May primary on the politics topic
# (two specifications) and on pre-specified comparison topics
##

eff = read_csv(file.path(root, "modified_data/topic_effects.csv"),
               show_col_types = FALSE) |>
  filter(!(group == "comparison" & topic == "Politics and public record")) |>
  mutate(lo = est - 1.96 * se, hi = est + 1.96 * se,
         row_label = if_else(group == "politics", spec, topic)) |>
  arrange(group == "comparison", desc(est)) |>
  mutate(ypos = -row_number() - if_else(group == "comparison", 1, 0))

fig = ggplot(eff, aes(x = est, y = ypos, color = group == "politics")) +
  geom_vline(xintercept = 0, color = "gray55", linewidth = 0.4) +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0, linewidth = 0.8) +
  geom_point(size = 2.8) +
  scale_color_manual(values = c(`TRUE` = blog_teal, `FALSE` = "#8F897B"),
                     guide = "none") +
  scale_y_continuous(breaks = eff$ypos, labels = eff$row_label,
                     expand = expansion(add = 0.8)) +
  annotate("text", x = -0.105, y = -1.5, label = "Politics and\npublic record",
           size = 3.3, color = blog_teal, fontface = "bold", hjust = 0, lineheight = 1.1) +
  annotate("text", x = -0.105, y = -4.5, label = "Other topics,\nsame design",
           size = 3.3, color = "#8F897B", hjust = 0, lineheight = 1.1) +
  scale_x_continuous(limits = c(-0.11, 0.21),
                     name = "Effect of a May primary on topic share (pp), with 95% CI") +
  labs(title = "Estimated Effect of a May Primary, by Topic and Specification",
       subtitle = "Difference-in-differences across US states, April to May 2026.\nState and month fixed effects; SEs clustered by state.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank(),
        plot.title = element_text(size = 14))

blog_save(fig, "topic_effects", height = 5.5, width = 8)
