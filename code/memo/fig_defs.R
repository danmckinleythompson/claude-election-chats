# fig_defs.R ----------------------------------------------------------------
# One definition per figure, parameterised by a palette, so the academic memo
# and the branded Free Systems post render the SAME chart geometry with
# different styling. Sourced by:
#
#   02_memo_figures.R  -> plain PDFs  -> output/memo/  (used by draft/)
#   05_post_brand.R    -> branded PNGs -> output/post/ (dragged into the post)
#
# Every builder reads only the CSVs written by 01_memo_stats.R (plus the raw
# AEI release for the opening figure), returns a bare chart with no title, and
# hands its title/subtitle back as metadata.
#
# TITLES: these are the POST's titles and they state the finding, in the
# house style of a magazine chart. That is a deliberate reversal of the
# neutral-title rule the memo follows -- the memo drops these entirely and
# uses its LaTeX \caption instead, so the academic draft is unaffected. Each
# title must be defensible from the figure ALONE; where a claim would need a
# second figure to hold up (see fig_did) the title is narrowed to what is
# actually plotted. Subtitles carry the geography and month, because the
# figures mix US-state, US-national and global panels and a reader who meets
# one figure on its own has no other way to tell them apart.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue)

AEI_SOURCE = paste("Source: Anthropic Economic Index, 2026-06-26 release.",
                   "Shares are of classified conversations.")

## --- palettes ---------------------------------------------------------------
# memo_pal is the repo's long-standing academic look. fs_pal is the Free
# Systems brand system (see ~/freesystems/CLAUDE.md): warm off-white ground,
# near-black ink, deep teal primary, warm copper for the contrasting series.
memo_pal = list(
  bar = "#B2182B", accent = "#B2182B", muted = "grey45", flat = "grey72",
  series3 = c(Information = "#B2182B", Action = "#2166AC", Document = "#E08214"),
  bg = "white", ink = "grey25", axis = "grey30", grid = "grey92",
  strip = "grey30", rule = "grey55", base_size = 16, family = "")

fs_pal = list(
  bar = "#2B5B6C", accent = "#2B5B6C", muted = "#8C8C86", flat = "#B9B8AE",
  # Teal and copper are the brand's own pair and carry the story (information
  # vs document); the minor Action series is deliberately neutral. The brand
  # teal sits below the dataviz chroma floor -- it is a muted teal by design --
  # so every series is also directly labelled, which is the documented relief.
  series3 = c(Information = "#2B5B6C", Action = "#8C8C86", Document = "#C4703E"),
  bg = "#FAFAF7", ink = "#3D3D38", axis = "#3D3D38", grid = "#E3E2DA",
  strip = "#6B6B63", rule = "#C9C8BE", base_size = 15, family = "Avenir Next")

fig_theme = function(pal) {
  theme_classic(base_size = pal$base_size, base_family = pal$family) +
    theme(plot.background  = element_rect(fill = pal$bg, color = NA),
          panel.background = element_rect(fill = pal$bg, color = NA),
          text = element_text(color = pal$ink),
          axis.text = element_text(color = pal$axis),
          axis.title = element_text(color = pal$axis),
          axis.line = element_line(color = pal$rule),
          axis.ticks = element_line(color = pal$rule),
          legend.background = element_rect(fill = pal$bg, color = NA),
          legend.key = element_rect(fill = pal$bg, color = NA))
}

# Left-strip panelling, for figures whose groups share an axis but must not be
# summed or ranked against one another.
panel_theme = function(pal) theme(
  strip.placement = "outside", strip.background = element_blank(),
  strip.text.y.left = element_text(face = "italic", angle = 0, size = 11,
                                   color = pal$strip, lineheight = 1.1),
  panel.grid.major.x = element_line(color = pal$grid, linewidth = 0.3),
  axis.line.y = element_blank(), axis.ticks.y = element_blank())

flat_theme = function(pal) theme(
  panel.grid.major.x = element_line(color = pal$grid, linewidth = 0.3),
  axis.line.y = element_blank(), axis.ticks.y = element_blank())

## --- F0. Where politics sits among all topics -------------------------------
fig_context = function(pal, outdir, root) {
  N_TOP = 10; OUTCOME = "Politics and public record"
  aei = read_csv(file.path(root,
    "original_data/anthropic_economic_index/release_2026_06_26/aei_claude_ai_2026-06-26.csv"),
    show_col_types = FALSE)

  # Minor topics are the level at which the outcome is defined, so the ranking
  # is like-for-like: we never compare an aggregate against a leaf.
  minor = aei |>
    filter(category_name == "request", metric_id == "pct", geo_id == "USA",
           date_start == "2026-05-01", hierarchy_level == 1) |>
    transmute(topic = node_name, pct = value) |> arrange(desc(pct)) |>
    mutate(rank = row_number())
  pol = minor |> filter(topic == OUTCOME)
  stopifnot(nrow(pol) == 1)
  n_topics = nrow(minor)

  # Two blocks: the head of the distribution, and the neighbourhood politics
  # actually sits in. Showing only larger topics would imply politics is the
  # floor; it is not, and the topics beside it are the informative comparison.
  neigh_lo = pol$rank - 2; neigh_hi = pol$rank + 5
  n_gap_upper = neigh_lo - N_TOP - 1
  n_gap_lower = n_topics - neigh_hi
  stopifnot(n_gap_upper > 0, n_gap_lower > 0, neigh_lo > N_TOP)

  # Sentence-case the labels: AEI's own capitalisation is inconsistent across
  # topics and looks careless side by side. Acronyms must survive the
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
            tidy_label("Politics and public record") == "Politics & public record")

  # Numeric y positions throughout: annotate() does not map factor levels
  # through a discrete scale, which silently misplaces the break row.
  rows = bind_rows(
      minor |> slice_head(n = N_TOP),
      tibble(topic = "__GAP1__", pct = NA_real_, rank = NA_real_),
      minor |> filter(rank >= neigh_lo, rank <= neigh_hi),
      tibble(topic = "__GAP2__", pct = NA_real_, rank = NA_real_)) |>
    mutate(is_gap = str_starts(topic, "__GAP"),
           label = if_else(is_gap, "", tidy_label(topic)),
           is_pol = topic == OUTCOME, y = rev(row_number()))
  bars = rows |> filter(!is_gap)
  gap_y = set_names(rows$y[rows$is_gap], rows$topic[rows$is_gap])
  xmax = max(minor$pct[1:N_TOP])

  gap_label = function(nm, n) list(
    annotate("segment", x = 0, xend = xmax * 1.02, y = gap_y[[nm]], yend = gap_y[[nm]],
             linetype = "dotted", colour = pal$rule, linewidth = 0.6),
    annotate("label", x = xmax * 0.02, y = gap_y[[nm]], hjust = 0, size = 4.1,
             colour = pal$strip, fontface = "italic", fill = pal$bg,
             linewidth = 0, label.padding = unit(0.15, "lines"),
             family = pal$family, label = glue("{n} topics omitted")))

  p = ggplot(bars, aes(x = pct, y = y, fill = is_pol)) +
    # both aesthetics are continuous, so the orientation must be stated
    geom_col(width = 0.68, orientation = "y") +
    geom_text(aes(label = sprintf("%.2f%%", pct), colour = is_pol),
              hjust = -0.18, size = 4.3, fontface = "bold", family = pal$family) +
    gap_label("__GAP1__", n_gap_upper) +
    gap_label("__GAP2__", n_gap_lower) +
    scale_y_continuous(breaks = bars$y, labels = bars$label,
                       expand = expansion(add = 0.7)) +
    scale_fill_manual(values = c(`TRUE` = pal$accent, `FALSE` = pal$flat), guide = "none") +
    scale_colour_manual(values = c(`TRUE` = pal$accent, `FALSE` = pal$axis), guide = "none") +
    scale_x_continuous(expand = expansion(mult = c(0, 0.14))) +
    labs(x = "Share of all conversations (%)", y = NULL) +
    fig_theme(pal) + flat_theme(pal) +
    theme(axis.text.y = element_text(size = 12.5, color = pal$ink))

  list(plot = p, w = 10.5, h = 8.4,
       title = "Politics Is a Rounding Error in How People Use Claude",
       subtitle = glue("Ten largest request topics, and the politics topic with its ",
                       "immediate neighbours. Politics ranks {pol$rank}th of ",
                       "{n_topics}. United States, May 2026."))
}

## --- F1. Political topic breakdown ------------------------------------------
fig_topic_breakdown = function(pal, outdir, root) {
  td = read_csv(file.path(outdir, "topic_decomposition.csv"), show_col_types = FALSE) |>
    filter(!is.na(may)) |>
    mutate(level = factor(lvl, c(1, 0),
             c("Broad categories\n(level 1)", "Specific topics\n(level 0)")))

  p = ggplot(td, aes(x = may, y = fct_reorder(topic, may))) +
    geom_col(fill = pal$bar, width = 0.7) +
    geom_text(aes(label = sprintf("%.2f%%", may)), hjust = -0.2, size = 4.4,
              color = pal$ink, family = pal$family) +
    facet_grid(rows = vars(level), scales = "free_y", space = "free_y", switch = "y") +
    scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
    labs(x = "Share of all US conversations (%)", y = NULL) +
    fig_theme(pal) + panel_theme(pal)

  list(plot = p, w = 9.5, h = 5.8,
       title = "What Kinds of Politics People Bring to Claude",
       subtitle = paste("United States, May 2026. The two panels are different levels",
                        "of the topic taxonomy and overlap, so they do not sum."))
}

## --- F2. Cross-country politics share ---------------------------------------
fig_country_shares = function(pal, outdir, root) {
  cty = read_csv(file.path(outdir, "country_politics_shares.csv"), show_col_types = FALSE)
  top_bot = bind_rows(slice_max(cty, pct, n = 12), slice_min(cty, pct, n = 12)) |>
    distinct(geo_id, .keep_all = TRUE) |>
    mutate(grp = if_else(geo_id == "USA", "United States", "Other countries"))

  p = ggplot(top_bot, aes(x = pct, y = fct_reorder(geo_id, pct), fill = grp)) +
    geom_col(width = 0.72) +
    scale_fill_manual(values = c("United States" = pal$accent,
                                 "Other countries" = pal$flat)) +
    labs(x = "Politics-topic share of conversations (%)", y = NULL, fill = NULL) +
    fig_theme(pal) + flat_theme(pal) + theme(legend.position = "bottom")

  list(plot = p, w = 7.5, h = 7.5,
       title = "The United States Is the Most Political Market",
       subtitle = "Twelve highest and twelve lowest countries, May 2026.")
}

## --- F3. Artifacts, politics vs all conversations ---------------------------
fig_artifacts = function(pal, outdir, root) {
  art = read_csv(file.path(outdir, "artifacts.csv"), show_col_types = FALSE) |>
    filter(politics >= 0.5 | all_convos >= 3) |>
    mutate(label = str_to_sentence(str_replace_all(artifact, "_", " "))) |>
    pivot_longer(c(politics, all_convos), names_to = "grp", values_to = "pct") |>
    mutate(grp = factor(grp, c("all_convos", "politics"),
                        c("All conversations", "Politics topic")))

  p = ggplot(art, aes(x = pct, y = fct_reorder(label, pct), color = grp)) +
    geom_line(aes(group = label), color = pal$flat, linewidth = 0.9) +
    geom_point(size = 3.2) +
    scale_color_manual(values = c("All conversations" = pal$muted,
                                  "Politics topic" = pal$accent)) +
    labs(x = "Share of conversations producing this artifact (%)",
         y = NULL, color = NULL) +
    fig_theme(pal) + flat_theme(pal) + theme(legend.position = "bottom")

  list(plot = p, w = 8.5, h = 6,
       title = "Political Conversations Produce Explanations, Not Output",
       subtitle = "Worldwide, May 2026. Artifact = the conversation's main concrete output.")
}

## --- F4. Information vs action, topic by topic ------------------------------
fig_info_action = function(pal, outdir, root) {
  prof = read_csv(file.path(outdir, "info_action_profile.csv"), show_col_types = FALSE) |>
    pivot_longer(c(info, action, doc), names_to = "kind", values_to = "pct") |>
    # Levels are reversed because dodged discrete groups stack bottom-up; the
    # legend is reversed again below so it reads Information, Action, Document.
    mutate(kind = factor(kind, c("doc", "action", "info"),
                         c("Document", "Action", "Information")),
           topic = fct_reorder(topic, if_else(kind == "Information", pct, 0), .fun = max))

  p = ggplot(prof, aes(x = pct, y = topic, fill = kind)) +
    geom_col(position = position_dodge(width = 0.78), width = 0.7) +
    geom_text(aes(label = sprintf("%.1f", pct)), position = position_dodge(width = 0.78),
              hjust = -0.18, size = 3.6, color = pal$ink, family = pal$family) +
    scale_fill_manual(values = pal$series3) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.13))) +
    guides(fill = guide_legend(reverse = TRUE)) +
    labs(x = "Share of the topic's conversations producing this output (%)",
         y = NULL, fill = NULL) +
    fig_theme(pal) + flat_theme(pal) + theme(legend.position = "bottom")

  list(plot = p, w = 10, h = 5.6,
       title = "Seeking Information About Politics, Not Doing Politics",
       subtitle = paste("Worldwide, May 2026. Government filings is the one",
                        "administrative topic, and behaves nothing like the rest."))
}

## --- F5. How political conversations are conducted --------------------------
fig_composition = function(pal, outdir, root) {
  cmp = read_csv(file.path(outdir, "composition.csv"), show_col_types = FALSE) |>
    mutate(panel = factor(grp, c("A", "B", "C"),
             c("Use case", "Collaboration\nbucket", "Collaboration\npattern")),
           # ASCII only: the pdf device has no em-dash, and lower-casing the
           # definitions would turn "AI outputs" into "ai outputs".
           lab = if_else(is.na(defn) | defn == "", label,
                         paste0(label, " (", defn, ")")))

  p = ggplot(cmp, aes(x = may, y = fct_reorder(lab, may))) +
    geom_col(fill = pal$bar, width = 0.7) +
    geom_text(aes(label = sprintf("%.1f", may)), hjust = -0.2, size = 4,
              color = pal$ink, family = pal$family) +
    facet_grid(rows = vars(panel), scales = "free_y", space = "free_y", switch = "y") +
    scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(x = "Share of political conversations (%)", y = NULL) +
    fig_theme(pal) + panel_theme(pal)

  list(plot = p, w = 11, h = 6.2,
       title = "How People Conduct Political Conversations",
       subtitle = paste("Worldwide, May 2026. Each panel is a separate",
                        "classification of the same conversations and sums to 100."))
}

## --- F6. DiD estimates, main spec and comparison topics ---------------------
fig_did = function(pal, outdir, root) {
  # One axis, in percentage points, so every interval is directly comparable.
  # The log specification is deliberately absent: it is not in pp and cannot
  # share this axis.
  specs = read_csv(file.path(outdir, "did_specs.csv"), show_col_types = FALSE) |>
    filter(units == "pp") |>
    transmute(label = spec, est, se, grp = "Politics and\npublic record")
  comp = read_csv(file.path(outdir, "specificity.csv"), show_col_types = FALSE) |>
    filter(topic != "Politics and public record") |>
    transmute(label = topic, est, se, grp = "Other topics,\nsame design")

  did = bind_rows(specs, comp) |>
    mutate(lo = est - 1.96 * se, hi = est + 1.96 * se,
           grp = factor(grp, c("Politics and\npublic record", "Other topics,\nsame design")),
           label = fct_reorder(label, est))

  p = ggplot(did, aes(x = est, y = label, color = grp)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = pal$rule, linewidth = 0.6) +
    geom_linerange(aes(xmin = lo, xmax = hi), linewidth = 1) +
    geom_point(size = 3.4) +
    facet_grid(rows = vars(grp), scales = "free_y", space = "free_y", switch = "y") +
    scale_color_manual(values = setNames(c(pal$accent, pal$muted),
                                         levels(did$grp)), guide = "none") +
    scale_x_continuous(expand = expansion(mult = 0.07)) +
    labs(x = "Effect of a May primary on topic share (pp), with 95% CI", y = NULL) +
    fig_theme(pal) + panel_theme(pal)

  # NB not "only politics responds": F7 shows two unrelated topics with larger
  # t-statistics. The claim this figure can carry is about the topics shown.
  list(plot = p, w = 11, h = 5,
       title = "Politics Moves; Its Neighbouring Topics Do Not",
       subtitle = paste("Difference-in-differences across US states, April to May 2026.",
                        "State and month fixed effects; SEs clustered by state."))
}

## --- F7. Empirical null across all topics -----------------------------------
fig_null = function(pal, outdir, root) {
  nd = read_csv(file.path(outdir, "null_distribution.csv"), show_col_types = FALSE)
  pol_t = nd$t[nd$topic == "Politics and public record"]
  rank_pol = sum(nd$t >= pol_t)

  # All annotation heights are fractions of the tallest bar, so they track the
  # histogram instead of assuming today's counts.
  BINW = 0.25
  brks = seq(floor(min(nd$t) / BINW) * BINW, ceiling(max(nd$t) / BINW) * BINW, by = BINW)
  top = max(tabulate(cut(nd$t, brks, include.lowest = TRUE), nbins = length(brks) - 1))

  # Name the topics that outrank politics, so the figure carries the whole
  # ranking finding and no companion table is needed. Labels are staggered in
  # height to clear the bars; the rightmost hangs left and the rest hang right,
  # so none is struck through by the politics rule.
  above = nd |> filter(t > pol_t) |> arrange(desc(t)) |>
    mutate(y = top * (1.02 - 0.23 * row_number()),
           hj = if_else(row_number() == 1, 1.05, -0.05))

  p = ggplot(nd, aes(x = t)) +
    geom_histogram(binwidth = 0.25, fill = pal$flat, color = pal$bg, linewidth = 0.3) +
    geom_segment(data = above, aes(x = t, xend = t, y = y - 0.6, yend = 0.8),
                 inherit.aes = FALSE, color = pal$strip, linewidth = 0.4) +
    geom_text(data = above, aes(x = t, y = y, hjust = hj,
                                label = glue("{topic} ({sprintf('%.2f', t)})")),
              inherit.aes = FALSE, size = 3.9, color = pal$strip, family = pal$family) +
    # A segment, not geom_vline: the rule has to stop below the callout, or it
    # strikes through the label it belongs to.
    annotate("segment", x = pol_t, xend = pol_t, y = 0, yend = top * 0.80,
             color = pal$accent, linewidth = 1.1) +
    annotate("label", x = pol_t, y = top * 1.02, vjust = 1, size = 4.6, linewidth = 0,
             color = pal$accent, fill = pal$bg, family = pal$family,
             label = glue("Politics and public record\nt = {sprintf('%.2f', pol_t)} ",
                          "(rank {rank_pol} of {nrow(nd)})")) +
    labs(x = expression(paste(italic(t), "-statistic on Primary ", symbol("\264"), " May")),
         y = glue("Number of topics (of {nrow(nd)})")) +
    fig_theme(pal)

  # Count the topics above politics rather than asserting a number, so the
  # title cannot go stale if a later release reshuffles the ranking.
  n_above = nrow(above)
  list(plot = p, w = 8.5, h = 5.2,
       title = glue("Politics Sits in the Right Tail, With ",
                    "{if (n_above == 2) 'Two' else n_above} Topics Above It"),
       subtitle = glue("The same difference-in-differences run on all {nrow(nd)} ",
                       "estimable topic series. US states, April to May 2026."))
}

## --- registry ----------------------------------------------------------------
# `slot` drives the post's filename numbering; `memo` marks the four figures the
# academic draft includes (those also get a plain PDF in output/memo).
FIGS = tibble::tribble(
  ~slot, ~key,                ~fn,                 ~memo, ~out,
  "F0",  "politics_in_context", fig_context,        FALSE, "post_01_F0_politics_in_context",
  "F1",  "topic_decomposition", fig_topic_breakdown, TRUE, "post_02_F1_topic_breakdown",
  "F2",  "country_shares",      fig_country_shares,  TRUE, "post_03_F2_country_shares",
  "F3",  "artifacts",           fig_artifacts,       TRUE, "post_04_F3_artifacts",
  "F4",  "info_action",         fig_info_action,    FALSE, "post_05_F4_info_vs_action",
  "F5",  "composition",         fig_composition,    FALSE, "post_06_F5_how_conducted",
  "F6",  "did_estimates",       fig_did,            FALSE, "post_07_F6_did_estimates",
  "F7",  "null_distribution",   fig_null,            TRUE, "post_08_F7_null_distribution"
)
