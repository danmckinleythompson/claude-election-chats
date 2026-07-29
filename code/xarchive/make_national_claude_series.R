# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: the national election-topic share of Claude conversations across the
# five AEI windows
##

# NB: the request-topic taxonomy changes across releases, so points are only
# strictly comparable within a taxonomy regime; the figure marks the regimes
national = read_csv(file.path(root, "modified_data/aei_election_topics.csv"),
                    show_col_types = FALSE) |>
  filter(geo_level == "national", concept == "elections_narrow") |>
  mutate(window_mid = date_start + (date_end - date_start) / 2)

fig = ggplot(national, aes(x = window_mid, y = pct)) +
  geom_vline(xintercept = as.Date("2025-11-04"), color = "gray70", linetype = "dashed") +
  geom_vline(xintercept = as.Date("2026-03-03"), color = "gray70", linetype = "dashed") +
  # Connect only the points that share a taxonomy
  geom_line(data = \(d) filter(d, release %in% c("nov2025", "feb2026")), color = "gray20") +
  geom_line(data = \(d) filter(d, release %in% c("apr2026", "may2026")), color = "gray20") +
  geom_point(color = "gray20", size = 3) +
  annotate("text", x = as.Date("2025-11-06"), y = 0.27, hjust = -0.05,
           label = "Nov 2025\nelections", color = "gray40", size = 4.5, lineheight = 0.9) +
  annotate("text", x = as.Date("2026-03-05"), y = 0.27, hjust = -0.05,
           label = "First 2026\nprimaries", color = "gray40", size = 4.5, lineheight = 0.9) +
  annotate("text", x = as.Date("2025-12-25"), y = 0.21,
           label = "2025 taxonomy", color = "gray55", size = 4.5) +
  annotate("text", x = as.Date("2026-05-01"), y = 0.115,
           label = "2026 taxonomy", color = "gray55", size = 4.5) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b %Y",
               limits = as.Date(c("2025-08-01", "2026-06-15"))) +
  coord_cartesian(ylim = c(0, 0.3)) +
  labs(x = NULL, y = "Election-Topic Share of Conversations (%)") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/national_claude_series.pdf"), plot = fig,
       height = 6, width = 10)
