# 02_memo_figures.R ---------------------------------------------------------
# Figures for draft/politics_memo. Reads the CSVs written by 01_memo_stats.R
# so the figures and the in-text numbers can never drift apart.
# Style follows the repo convention: theme_classic(base_size = 16), white bg.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue)
set.seed(42)
options(scipen = 999)
# Resolve the project root: run from the repo root and it just works;
# otherwise fall back to the repo-wide convention.
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

outdir = file.path(root, "output/memo")
memo_theme = theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

## --- Figure 1: cross-country politics share (descriptive) ------------------
cty = read_csv(file.path(outdir, "country_politics_shares.csv"), show_col_types = FALSE)
top_bot = bind_rows(slice_max(cty, pct, n = 12), slice_min(cty, pct, n = 12)) |>
  distinct(geo_id, .keep_all = TRUE) |>
  mutate(grp = if_else(geo_id == "USA", "United States", "Other countries"))

fig1 = ggplot(top_bot, aes(x = pct, y = fct_reorder(geo_id, pct), fill = grp)) +
  geom_col(width = 0.72) +
  scale_fill_manual(values = c("United States" = "#B2182B", "Other countries" = "grey65")) +
  labs(x = "Politics-Topic Share of Conversations (%), May 2026", y = NULL, fill = NULL) +
  memo_theme + theme(legend.position = "bottom")
ggsave(file.path(outdir, "fig_country_shares.pdf"), fig1, width = 7.5, height = 7.5)

## --- Figure 2: political topic decomposition (descriptive) -----------------
# Faceted by taxonomy level so aggregates are never read against leaves.
td = read_csv(file.path(outdir, "topic_decomposition.csv"), show_col_types = FALSE) |>
  filter(!is.na(apr), !is.na(may)) |>
  mutate(level = factor(lvl, c(1, 0),
           c("Minor topics (level 1, aggregates)", "Detailed topics (level 0, leaves)"))) |>
  pivot_longer(c(apr, may), names_to = "month", values_to = "pct") |>
  mutate(month = factor(month, c("apr", "may"), c("April 2026", "May 2026")))

fig2 = ggplot(td, aes(x = pct, y = reorder_within <- fct_reorder(topic, pct), color = month)) +
  geom_line(aes(group = topic), color = "grey70", linewidth = 0.9) +
  geom_point(size = 3.4) +
  facet_grid(rows = vars(level), scales = "free_y", space = "free_y", switch = "y") +
  scale_color_manual(values = c("April 2026" = "grey45", "May 2026" = "#B2182B")) +
  labs(x = "US National Share of Conversations (%)", y = NULL, color = NULL) +
  memo_theme +
  theme(legend.position = "bottom", strip.placement = "outside",
        strip.background = element_blank(), strip.text.y.left = element_text(face = "italic",
                                                                             angle = 90, size = 11))
ggsave(file.path(outdir, "fig_topic_decomposition.pdf"), fig2, width = 8.5, height = 5.8)

## --- Figure 3: permutation / empirical null distribution (the main check) --
nd = read_csv(file.path(outdir, "null_distribution.csv"), show_col_types = FALSE)
pol_t = nd$t[nd$topic == "Politics and public record"]
rank_pol = sum(nd$t >= pol_t)

fig3 = ggplot(nd, aes(x = t)) +
  geom_histogram(binwidth = 0.25, fill = "grey72", color = "white", linewidth = 0.3) +
  geom_vline(xintercept = pol_t, color = "#B2182B", linewidth = 1.1) +
  annotate("label", x = pol_t, y = Inf, vjust = 1.4, size = 4.6,
           color = "#B2182B", fill = "white",
           label = glue("Politics and public record\nt = {sprintf('%.2f', pol_t)} ",
                        "(rank {rank_pol} of {nrow(nd)})")) +
  labs(x = expression(paste(italic(t), "-statistic on Primary ", symbol("\264"), " May")),
       y = glue("Number of Topics (of {nrow(nd)})")) +
  memo_theme
ggsave(file.path(outdir, "fig_null_distribution.pdf"), fig3, width = 8.5, height = 5.2)

## --- Figure 4: artifacts produced, politics vs all conversations -----------
# The information/doing gap: what concrete output did the conversation yield?
art = read_csv(file.path(outdir, "artifacts.csv"), show_col_types = FALSE) |>
  filter(politics >= 0.5 | all_convos >= 3) |>
  mutate(label = str_to_sentence(str_replace_all(artifact, "_", " "))) |>
  pivot_longer(c(politics, all_convos), names_to = "grp", values_to = "pct") |>
  mutate(grp = factor(grp, c("all_convos", "politics"),
                      c("All conversations", "Politics topic")))

fig4 = ggplot(art, aes(x = pct, y = fct_reorder(label, pct), color = grp)) +
  geom_line(aes(group = label), color = "grey70", linewidth = 0.9) +
  geom_point(size = 3.2) +
  scale_color_manual(values = c("All conversations" = "grey45", "Politics topic" = "#B2182B")) +
  labs(x = "Share of Conversations Producing This Artifact (%), May 2026",
       y = NULL, color = NULL) +
  memo_theme + theme(legend.position = "bottom")
ggsave(file.path(outdir, "fig_artifacts.pdf"), fig4, width = 8.5, height = 6)

message("[02] wrote 4 figures to ", outdir)
cat("fig3: politics t =", round(pol_t, 3), "rank", rank_pol, "of", nrow(nd), "\n")
