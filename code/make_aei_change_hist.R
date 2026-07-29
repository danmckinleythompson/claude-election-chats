# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: histograms of each state's April-to-May change in the politics-topic
# share, May-primary states against later-primary controls
##

changes = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
                   show_col_types = FALSE) |>
  filter(!march_primary) |>
  select(state_po, treat_may, post, politics_broad) |>
  pivot_wider(names_from = post, values_from = politics_broad) |>
  mutate(change = `TRUE` - `FALSE`,
         group = if_else(treat_may, "May-primary states (8)",
                         "Later-primary states (22)") |>
           factor(levels = c("May-primary states (8)", "Later-primary states (22)")))

group_means = changes |>
  group_by(group) |>
  summarize(mean_change = mean(change), .groups = "drop")

fig = ggplot(changes, aes(x = change)) +
  geom_vline(xintercept = 0, color = "gray70", linetype = "dashed") +
  geom_histogram(binwidth = 0.05, boundary = 0, closed = "left",
                 fill = "gray55", color = "white") +
  geom_vline(data = group_means, aes(xintercept = mean_change),
             color = "gray10", linewidth = 0.8) +
  geom_text(data = group_means,
            aes(x = mean_change, y = 9.7,
                label = sprintf("mean = %+.2f", mean_change)),
            color = "gray10", size = 4.5, hjust = -0.08) +
  facet_wrap(~group, ncol = 1) +
  scale_y_continuous(breaks = seq(0, 10, 2), limits = c(0, 10.4)) +
  labs(x = "Change in Politics-Topic Share, April to May (pp)",
       y = "Number of States") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA),
        strip.background = element_blank(),
        strip.text = element_text(size = 15, hjust = 0))

ggsave(file.path(root, "output/aei_change_hist.pdf"), plot = fig,
       height = 6, width = 10)
