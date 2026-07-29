# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: national weekly Google search interest in "primary election", with
# the AEI observation windows shaded so the two data sources line up
##

us_trends = read_csv(file.path(root, "modified_data/google_trends_weekly.csv"),
                     show_col_types = FALSE) |>
  filter(state_po == "US")

# The five AEI windows (see clean_aei_election_topics.R)
aei_windows = tibble(
  start = as.Date(c("2025-08-04", "2025-11-13", "2026-02-05", "2026-04-01", "2026-05-01")),
  end   = as.Date(c("2025-08-11", "2025-11-20", "2026-02-12", "2026-05-01", "2026-06-01"))
)

fig = ggplot() +
  geom_rect(data = aei_windows,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
            fill = "gray92") +
  geom_line(data = us_trends, aes(x = week_start, y = index), color = "gray20") +
  annotate("text", x = as.Date("2026-03-01"), y = 97,
           label = "First 2026\nprimaries", color = "gray20", size = 4.5,
           hjust = 1.05, lineheight = 0.9) +
  annotate("text", x = as.Date("2025-11-04"), y = 60,
           label = "Nov 2025\nelections", color = "gray20", size = 4.5,
           hjust = -0.1, lineheight = 0.9) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
  labs(x = NULL, y = "Google Search Interest (0-100)") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/national_trends_series.pdf"), plot = fig,
       height = 6, width = 10)
