# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: conversation outputs by political topic - information vs
# action vs document output kinds (grouping due to AH)
##

INFO_KIND   = c("explanation_or_answer", "analysis_or_summary")
ACTION_KIND = c("email_or_message", "plan_or_strategy", "marketing_or_social_content")
DOC_KIND    = c("document_or_report", "resume_or_job_application", "data_or_spreadsheet")
PROFILE = c("Politics", "Politics and public record", "Public records lookup",
            "Elections", "Government filings")

prof = read_csv(file.path(root, "modified_data/global_context.csv"),
                show_col_types = FALSE) |>
  filter(str_detect(metric_id, "^artifact_"), topic %in% PROFILE) |>
  mutate(artifact = str_remove_all(metric_id, "artifact_|_pct")) |>
  group_by(topic) |>
  summarize(Information = sum(value[artifact %in% INFO_KIND]),
            Action = sum(value[artifact %in% ACTION_KIND]),
            Document = sum(value[artifact %in% DOC_KIND]), .groups = "drop") |>
  pivot_longer(-topic, names_to = "kind", values_to = "pct") |>
  mutate(topic = fct_reorder(topic, pct, .fun = max),
         kind = factor(kind, c("Information", "Action", "Document")))

fig = ggplot(prof, aes(x = pct, y = topic, fill = fct_rev(kind))) +
  geom_col(width = 0.72, position = position_dodge(0.78)) +
  geom_text(aes(label = formatC(pct, format = "f", digits = 1)),
            position = position_dodge(0.78), hjust = -0.15, size = 2.9,
            color = "gray25") +
  scale_fill_manual(values = c(Information = blog_teal, Action = blog_gray,
                               Document = blog_orange),
                    breaks = c("Information", "Action", "Document"), name = NULL) +
  scale_x_continuous(limits = c(0, 84), expand = expansion(mult = c(0, 0)),
                     name = "Share of the topic's conversations producing this output (%)") +
  labs(title = "Conversation Outputs, by Political Topic",
       subtitle = "Worldwide, May 2026. Each output kind groups several artifact types,\nso the three do not sum to 100.",
       y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank())

blog_save(fig, "topic_outputs", height = 7, width = 8)
