# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: monthly mean log search interest for "primary election", May-primary
# states against later-primary states, same 30 states as the Claude analysis
##

monthly_means = read_csv(file.path(root, "modified_data/search_did_data.csv"),
                         show_col_types = FALSE) |>
  filter(aei_sample) |>
  group_by(treat_may, month) |>
  summarize(mean_log = mean(log1p(mean_index)), .groups = "drop")

labels = monthly_means |>
  filter(month == max(month)) |>
  mutate(label = if_else(treat_may, "May-primary states", "Later-primary states"))

fig = ggplot(monthly_means, aes(x = month, y = mean_log)) +
  annotate("rect", xmin = as.Date("2026-04-01"), xmax = as.Date("2026-05-31"),
           ymin = -Inf, ymax = Inf, fill = "gray92") +
  annotate("text", x = as.Date("2026-04-30"), y = 0.12, label = "AEI\nwindow",
           color = "gray45", size = 4.5, lineheight = 0.9) +
  geom_line(data = \(d) filter(d, treat_may), color = "gray10", linewidth = 1) +
  geom_point(data = \(d) filter(d, treat_may), color = "gray10", size = 2.5) +
  geom_line(data = \(d) filter(d, !treat_may), color = "gray55", linewidth = 1,
            linetype = "dashed") +
  geom_point(data = \(d) filter(d, !treat_may), color = "gray55", size = 2.5) +
  geom_text(data = labels,
            aes(x = month + 8, y = mean_log, label = label, color = treat_may),
            hjust = 0, size = 5, show.legend = FALSE) +
  scale_color_manual(values = c(`TRUE` = "gray10", `FALSE` = "gray55")) +
  scale_x_date(breaks = seq(as.Date("2025-07-01"), as.Date("2026-05-01"), by = "2 months"),
               date_labels = "%b %Y",
               limits = c(as.Date("2025-07-01"), as.Date("2026-08-25"))) +
  labs(x = NULL, y = "Mean Log Search Interest, \"Primary Election\"") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/search_did_plot.pdf"), plot = fig,
       height = 6, width = 10)
