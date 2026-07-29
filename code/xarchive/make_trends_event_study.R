# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: event-study coefficients for search interest around the primary
##

estimates = read_csv(file.path(root, "modified_data/trends_event_study_estimates.csv"),
                     show_col_types = FALSE) |>
  # Add the reference week at zero for both estimators
  bind_rows(tibble(estimator = c("twfe", "sunab"), event_week = -1L,
                   estimate = 0, conf.low = 0, conf.high = 0)) |>
  filter(event_week >= -8, event_week <= 4) |>
  # Offset the two estimators slightly so both are readable
  mutate(x = event_week + if_else(estimator == "twfe", -0.1, 0.1))

fig = ggplot(estimates, aes(x = x, y = estimate)) +
  geom_vline(xintercept = 0, color = "gray70", linetype = "dashed") +
  geom_hline(yintercept = 0, color = "gray70") +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high),
                width = 0, color = "gray20",
                data = \(d) filter(d, estimator == "twfe")) +
  geom_point(color = "gray20", size = 2.5,
             data = \(d) filter(d, estimator == "twfe")) +
  geom_point(color = "gray55", size = 2.5, shape = 2,
             data = \(d) filter(d, estimator == "sunab")) +
  annotate("text", x = -6.5, y = 1.05, label = "Two-way fixed effects",
           color = "gray20", size = 5, hjust = 0) +
  annotate("text", x = -6.5, y = 0.92, label = "Sun-Abraham",
           color = "gray55", size = 5, hjust = 0) +
  scale_x_continuous(breaks = seq(-8, 4, 2)) +
  labs(x = "Weeks Relative to Primary Election",
       y = "Effect on Log Search Interest") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/trends_event_study.pdf"), plot = fig,
       height = 6, width = 10)
