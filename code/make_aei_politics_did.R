# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: mean Claude politics-topic share in April and May 2026, May-primary
# states against later-primary states; the companion histogram figure
# (make_aei_change_hist.R) shows the underlying state-level changes
##

group_means = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
                       show_col_types = FALSE) |>
  filter(!march_primary) |>
  group_by(treat_may, post) |>
  summarize(mean_pct = mean(politics_broad), .groups = "drop")

# Month on the x-axis as a numeric position
month_x = function(post) if_else(post, 2, 1)

fig = ggplot() +
  geom_line(data = group_means |> filter(treat_may),
            aes(x = month_x(post), y = mean_pct), color = "gray10", linewidth = 1) +
  geom_point(data = group_means |> filter(treat_may),
             aes(x = month_x(post), y = mean_pct), color = "gray10", size = 3) +
  geom_line(data = group_means |> filter(!treat_may),
            aes(x = month_x(post), y = mean_pct), color = "gray55", linewidth = 1,
            linetype = "dashed") +
  geom_point(data = group_means |> filter(!treat_may),
             aes(x = month_x(post), y = mean_pct), color = "gray55", size = 3) +
  annotate("text", x = 2.05, y = 0.505, label = "May-primary states",
           color = "gray10", size = 5, hjust = 0) +
  annotate("text", x = 2.05, y = 0.476, label = "Later-primary states",
           color = "gray55", size = 5, hjust = 0) +
  scale_x_continuous(breaks = c(1, 2), labels = c("April 2026", "May 2026"),
                     limits = c(0.9, 2.45)) +
  coord_cartesian(ylim = c(0.35, 0.55)) +
  labs(x = NULL, y = "Politics-Topic Share of Conversations (%)") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/aei_politics_did.pdf"), plot = fig,
       height = 6, width = 10)
