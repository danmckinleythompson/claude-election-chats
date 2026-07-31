# 04_fig_politics_in_context.R ----------------------------------------------
# Opening figure for the post: where politics sits among the topics people
# actually bring to Claude. Replaces the T1 table, whose state-coverage
# columns are a privacy-threshold caveat for the memo rather than the post.
#
# Design intent: the reader must be calibrated on magnitude BEFORE meeting a
# "22 percent increase", so the comparison is against the top of the topic
# distribution, with the omitted middle shown honestly rather than hidden.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue)
set.seed(42)
options(scipen = 999)
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

post_dir = file.path(root, "output/post")
dir.create(post_dir, recursive = TRUE, showWarnings = FALSE)

N_TOP    = 10
OUTCOME  = "Politics and public record"
ACCENT   = "#B2182B"
GREY     = "grey72"

aei = read_csv(file.path(root,
  "original_data/anthropic_economic_index/release_2026_06_26/aei_claude_ai_2026-06-26.csv"),
  show_col_types = FALSE)

# Minor topics are the level at which the outcome is defined, so the ranking
# is like-for-like: we never compare an aggregate against a leaf.
minor = aei |>
  filter(category_name == "request", metric_id == "pct", geo_id == "USA",
         date_start == "2026-05-01", hierarchy_level == 1) |>
  transmute(topic = node_name, pct = value) |>
  arrange(desc(pct)) |>
  mutate(rank = row_number())

pol = minor |> filter(topic == OUTCOME)
stopifnot(nrow(pol) == 1)
n_topics = nrow(minor)

# Two blocks: the head of the distribution, and the neighbourhood politics
# actually sits in. Showing only larger topics would imply politics is the
# floor; it is not, and the topics beside it are the informative comparison.
NEIGH_ABOVE = 2
NEIGH_BELOW = 5
neigh_lo = pol$rank - NEIGH_ABOVE
neigh_hi = pol$rank + NEIGH_BELOW
n_gap_upper = neigh_lo - N_TOP - 1          # between the head and the neighbourhood
n_gap_lower = n_topics - neigh_hi           # the tail below
stopifnot(n_gap_upper > 0, n_gap_lower > 0, neigh_lo > N_TOP)

# Sentence-case the labels: AEI's own capitalisation is inconsistent across
# topics and looks careless when set side by side. Acronyms must survive the
# lowercasing, or "API debugging" becomes "Api debugging".
ACRONYMS = c("API", "AI", "UI", "UX", "ML", "SQL", "HR", "IT", "SEO", "US", "PDF")
tidy_label = function(x) {
  x = str_replace_all(x, " and ", " & ")
  x = paste0(str_to_upper(str_sub(x, 1, 1)), str_to_lower(str_sub(x, 2)))
  for (a in ACRONYMS)
    x = str_replace_all(x, regex(paste0("\\b", a, "\\b"), ignore_case = TRUE), a)
  x
}
stopifnot(tidy_label("API debugging") == "API debugging",
          tidy_label("AI agent design") == "AI agent design",
          tidy_label("Politics and public record") == "Politics & public record")

# Numeric y positions throughout: annotate() does not map factor levels through
# a discrete scale, which silently misplaces the break row.
rows = bind_rows(
    minor |> slice_head(n = N_TOP),
    tibble(topic = "__GAP1__", pct = NA_real_, rank = NA_real_),
    minor |> filter(rank >= neigh_lo, rank <= neigh_hi),
    tibble(topic = "__GAP2__", pct = NA_real_, rank = NA_real_)) |>
  mutate(is_gap = str_starts(topic, "__GAP"),
         label = if_else(is_gap, "", tidy_label(topic)),
         is_pol = topic == OUTCOME,
         y = rev(row_number()))          # row 1 at the top

bars  = rows |> filter(!is_gap)
gap_y = set_names(rows$y[rows$is_gap], rows$topic[rows$is_gap])
xmax  = max(minor$pct[1:N_TOP])

gap_label = function(nm, n) list(
  annotate("segment", x = 0, xend = xmax * 1.02, y = gap_y[[nm]], yend = gap_y[[nm]],
           linetype = "dotted", colour = "grey65", linewidth = 0.6),
  annotate("label", x = xmax * 0.02, y = gap_y[[nm]], hjust = 0, size = 4.1,
           colour = "grey40", fontface = "italic", fill = "white",
           label.padding = unit(0.15, "lines"),
           label = glue("{n} topics omitted")))

fig = ggplot(bars, aes(x = pct, y = y, fill = is_pol)) +
  # both aesthetics are continuous, so the orientation must be stated
  geom_col(width = 0.68, orientation = "y") +
  geom_text(aes(label = sprintf("%.2f%%", pct), colour = is_pol),
            hjust = -0.18, size = 4.3, fontface = "bold") +
  # Both omitted stretches stated rather than silently dropped.
  gap_label("__GAP1__", n_gap_upper) +
  gap_label("__GAP2__", n_gap_lower) +
  scale_y_continuous(breaks = bars$y, labels = bars$label,
                     expand = expansion(add = 0.7)) +
  scale_fill_manual(values = c(`TRUE` = ACCENT, `FALSE` = GREY), guide = "none") +
  scale_colour_manual(values = c(`TRUE` = ACCENT, `FALSE` = "grey35"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.14))) +
  # Title describes what is plotted; it does not state the conclusion. The
  # subtitle carries only neutral orienting facts.
  labs(
    title = "Share of US Claude Conversations by Topic, May 2026",
    subtitle = glue("Ten largest request topics, and the politics topic ",
                    "with its immediate neighbours. Politics ranks {pol$rank}th of {n_topics}."),
    x = "Share of all conversations (%)", y = NULL) +
  theme_classic(base_size = 15) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        plot.title = element_text(face = "bold", size = 16, margin = margin(b = 4)),
        plot.subtitle = element_text(colour = "grey35", size = 12,
                                     margin = margin(b = 14)),
        axis.text.y = element_text(size = 12.5, colour = "grey15"),
        axis.line.y = element_blank(), axis.ticks.y = element_blank(),
        plot.margin = margin(14, 20, 12, 12))

ggsave(file.path(post_dir, "fig_politics_in_context.pdf"), fig, width = 10.5, height = 8.4)
# The PNG is rendered by 03_post_images.R, which owns the post's numbering.

message(glue("[04] politics ranks {pol$rank} of {n_topics} at {pol$pct}%; ",
             "top topic {minor$topic[1]} at {minor$pct[1]}% ",
             "({round(minor$pct[1]/pol$pct, 1)}x)"))
