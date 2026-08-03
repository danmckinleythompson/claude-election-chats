# Set up the packages, options, and working directory path
pacman::p_load(tidyverse)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: Apr-May change in the Claude politics-topic share, splitting out the
# early-June-primary states (Jun 2-9: CA, NJ, NV, SC), whose mail-voting and
# final campaign weeks fall in May, from the true later-primary controls
##

aei = read_csv(file.path(root, "modified_data/aei_did_data.csv"),
               show_col_types = FALSE) |>
  filter(!march_primary) |>
  mutate(group = case_when(
    treat_may ~ "may",
    primary_date <= as.Date("2026-06-09") ~ "early_june",
    TRUE ~ "later"
  ))

group_means = aei |>
  group_by(group, post) |>
  summarize(mean_pct = mean(politics_broad), .groups = "drop")

# Month on the x-axis as a numeric position
month_x = function(post) if_else(post, 2, 1)

plot_group = function(g) group_means |> filter(group == g)

fig = ggplot() +
  geom_line(data = aei,
            aes(x = month_x(post), y = politics_broad, group = state_po),
            color = "gray88", linewidth = 0.4) +
  geom_line(data = plot_group("may"),
            aes(x = month_x(post), y = mean_pct), color = "gray10", linewidth = 1) +
  geom_point(data = plot_group("may"),
             aes(x = month_x(post), y = mean_pct), color = "gray10", size = 3) +
  geom_line(data = plot_group("early_june"),
            aes(x = month_x(post), y = mean_pct), color = "gray40", linewidth = 1,
            linetype = "dotdash") +
  geom_point(data = plot_group("early_june"),
             aes(x = month_x(post), y = mean_pct), color = "gray40", size = 3, shape = 15) +
  geom_line(data = plot_group("later"),
            aes(x = month_x(post), y = mean_pct), color = "gray60", linewidth = 1,
            linetype = "dashed") +
  geom_point(data = plot_group("later"),
             aes(x = month_x(post), y = mean_pct), color = "gray60", size = 3) +
  annotate("text", x = 2.06, y = 0.515, label = "May primary (8)",
           color = "gray10", size = 5, hjust = 0) +
  annotate("text", x = 2.06, y = 0.478, label = "Primary after Jun 9 (18)",
           color = "gray60", size = 5, hjust = 0) +
  annotate("text", x = 2.06, y = 0.408, label = "Jun 2-9 primary (4)",
           color = "gray40", size = 5, hjust = 0) +
  scale_x_continuous(breaks = c(1, 2), labels = c("April 2026", "May 2026"),
                     limits = c(0.9, 2.55)) +
  coord_cartesian(ylim = c(0.25, 0.75)) +
  labs(x = NULL, y = "Politics-Topic Share of Conversations (%)") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/aei_politics_did_june.pdf"), plot = fig,
       height = 6, width = 10)

# Print the group means so the console shows the numbers
group_means |> pivot_wider(names_from = post, values_from = mean_pct) |> print()
