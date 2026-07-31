# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: artifacts produced in political conversations vs all
# conversations (the information/doing gap)
##

art = read_csv(file.path(root, "modified_data/global_context.csv"),
               show_col_types = FALSE) |>
  filter(str_detect(metric_id, "^artifact_"),
         topic %in% c("Politics and public record", "All conversations")) |>
  mutate(artifact = str_remove_all(metric_id, "artifact_|_pct"),
         who = if_else(topic == "All conversations", "all_convos", "politics")) |>
  select(who, artifact, value) |>
  pivot_wider(names_from = who, values_from = value) |>
  filter(politics >= 0.5 | all_convos >= 3) |>
  mutate(label = str_to_sentence(str_replace_all(artifact, "_", " "))) |>
  pivot_longer(c(politics, all_convos), names_to = "grp", values_to = "pct") |>
  mutate(grp = factor(grp, c("all_convos", "politics"),
                      c("All conversations", "Politics topic")))

fig = ggplot(art, aes(x = pct, y = fct_reorder(label, pct, .fun = max))) +
  geom_line(aes(group = label), color = "gray60", linewidth = 0.8) +
  geom_point(aes(color = grp), size = 3.2) +
  scale_color_manual(values = c("All conversations" = blog_gray,
                                "Politics topic" = blog_teal), name = NULL) +
  scale_x_continuous(name = "Share of the topic's conversations producing this artifact (%)") +
  labs(title = "Artifacts Produced: Politics Topic vs. All Conversations",
       subtitle = "Worldwide, May 2026. Artifact = the conversation's main concrete output.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank())

blog_save(fig, "artifacts_dumbbell", height = 6.5, width = 8)
