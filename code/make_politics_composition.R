# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: composition of political conversations - use case and
# collaboration pattern (each panel is a separate classification)
##

spec = tribble(
  ~panel,                  ~label,                                    ~metric,
  "Use case",              "Personal",                                "use_case_personal_pct",
  "Use case",              "Work",                                    "use_case_work_pct",
  "Use case",              "Coursework",                              "use_case_coursework_pct",
  "Collaboration pattern", "Learning (Seeking understanding)",        "collaboration_learning_pct",
  "Collaboration pattern", "Directive (Minimal human interaction)",   "collaboration_directive_pct",
  "Collaboration pattern", "Task iteration (Human refines AI work)",  "collaboration_task_iteration_pct",
  "Collaboration pattern", "Feedback loop (Iterative dialogue with feedback)", "collaboration_feedback_loop_pct",
  "Collaboration pattern", "Validation (Human checking own work)",    "collaboration_validation_pct",
  "Collaboration pattern", "None (No pattern assigned)",              "collaboration_none_pct"
)

comp = read_csv(file.path(root, "modified_data/global_context.csv"),
                show_col_types = FALSE) |>
  filter(topic == "Politics and public record") |>
  inner_join(spec, by = c("metric_id" = "metric")) |>
  mutate(panel = factor(panel, c("Use case", "Collaboration pattern")))

fig = ggplot(comp, aes(x = value, y = tidytext::reorder_within(label, value, panel))) +
  geom_col(width = 0.7, fill = blog_teal) +
  geom_text(aes(label = formatC(value, format = "f", digits = 1)),
            hjust = -0.15, size = 3.3, color = "gray25", fontface = "bold") +
  tidytext::scale_y_reordered() +
  facet_grid(rows = vars(panel), scales = "free_y", space = "free_y", switch = "y") +
  scale_x_continuous(limits = c(0, 88), expand = expansion(mult = c(0, 0)),
                     name = "Share of political conversations (%)") +
  labs(title = "Composition of Political Conversations",
       subtitle = "Worldwide, May 2026. Each panel is a separate classification of the same\nconversations and sums to 100.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank(),
        strip.placement = "outside", strip.background = element_blank(),
        strip.text.y.left = element_text(angle = 0, size = 9.5, color = "gray40"))

blog_save(fig, "politics_composition", height = 6.5, width = 8.5)
