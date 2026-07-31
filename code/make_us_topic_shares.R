# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: the ten largest US request topics and the politics topic with
# its immediate neighbours in the ranking
##

us = read_csv(file.path(root, "modified_data/us_topic_shares.csv"),
              show_col_types = FALSE) |>
  filter(month == "may", lvl == 1) |>
  arrange(desc(pct)) |>
  mutate(rank = row_number())

pol_rank = us$rank[us$topic == "Politics and public record"]
top = us |> filter(rank <= 10)
neighborhood = us |> filter(abs(rank - pol_rank) <= 3)
omitted = pol_rank - 3 - 10 - 1

# Rows top to bottom: top ten, a divider row, the politics neighbourhood
rows = bind_rows(top, neighborhood) |>
  mutate(ypos = -c(1:10, 12:(11 + nrow(neighborhood))),
         highlight = topic == "Politics and public record")

fig = ggplot(rows, aes(x = pct, y = ypos, fill = highlight)) +
  geom_col(width = 0.72, orientation = "y") +
  geom_text(aes(label = paste0(formatC(pct, format = "f", digits = 2), "%"),
                color = highlight),
            hjust = -0.15, size = 3.4, fontface = "bold") +
  annotate("text", x = 0.62, y = -11, label = paste(omitted, "topics omitted"),
           size = 3.2, color = "gray45", hjust = 0) +
  scale_fill_manual(values = c(`TRUE` = blog_teal, `FALSE` = blog_gray), guide = "none") +
  scale_color_manual(values = c(`TRUE` = blog_teal, `FALSE` = "gray30"), guide = "none") +
  scale_y_continuous(breaks = rows$ypos, labels = rows$topic) +
  scale_x_continuous(limits = c(0, 7.2), expand = expansion(mult = c(0, 0))) +
  labs(title = "Share of US Claude Conversations, by Request Topic",
       subtitle = paste0("Ten largest request topics, and the politics topic with its immediate neighbours.\nPolitics ranks ",
                         pol_rank, "th of ", nrow(us), ". United States, May 2026."),
       x = NULL, y = NULL) +
  blog_theme() +
  theme(panel.grid.major.y = element_blank(), axis.text.x = element_blank(),
        plot.title = element_text(size = 14))

blog_save(fig, "us_topic_shares", height = 7, width = 8)
