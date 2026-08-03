# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: raw mean search interest by week relative to the primary
##

event_means = read_csv(file.path(root, "modified_data/trends_event_week_means.csv"),
                       show_col_types = FALSE)

fig = ggplot(event_means, aes(x = event_week, y = mean_index)) +
  geom_vline(xintercept = 0, color = "gray70", linetype = "dashed") +
  geom_line(color = "gray20") +
  geom_point(color = "gray20", size = 2.5) +
  scale_x_continuous(breaks = seq(-8, 4, 2)) +
  labs(x = "Weeks Relative to Primary Election",
       y = "Google Search Interest (0-100)") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/trends_raw_event_means.pdf"), plot = fig,
       height = 6, width = 10)
