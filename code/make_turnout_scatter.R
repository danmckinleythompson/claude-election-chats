# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot, ggrepel)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: change in the politics-topic share against primary turnout
# (ballots cast over the adult population) across the eight May-primary states
##

# Turnout is hand-compiled; sources documented line by line in
# original_data/primary_turnout/readme.txt
turnout = read_csv(file.path(root, "original_data/primary_turnout/primary_turnout_2026.csv"),
                   show_col_types = FALSE) |>
  mutate(turnout = 100 * ballots / vap_2024)

changes = read_csv(file.path(root, "modified_data/did_panel.csv"),
                   show_col_types = FALSE) |>
  filter(treat_may) |>
  select(state_po, post, pct) |>
  pivot_wider(names_from = post, values_from = pct) |>
  mutate(change = `TRUE` - `FALSE`) |>
  inner_join(turnout, by = "state_po")
stopifnot(nrow(changes) == 8)

r_all = cor(changes$turnout, changes$change)
r_noid = with(filter(changes, state_po != "ID"), cor(turnout, change))

fig = ggplot(changes, aes(x = turnout, y = change)) +
  geom_hline(yintercept = 0, color = "gray55", linewidth = 0.4) +
  geom_smooth(method = "lm", se = FALSE, color = blog_gray, linewidth = 0.9,
              linetype = "42") +
  geom_point(color = blog_teal, size = 3) +
  geom_text_repel(aes(label = state_po), color = blog_teal, size = 3.6,
                  fontface = "bold", seed = 42) +
  scale_x_continuous(name = "Primary turnout (ballots cast, % of adult population)") +
  scale_y_continuous(name = "Change in politics-topic share, April to May (pp)") +
  labs(title = "Bigger Primaries, Bigger Shifts in Political Conversation?",
       subtitle = paste0("The eight May-primary states in the analysis sample. r = ",
                         sprintf("%.2f", r_all), " (n = 8); ",
                         sprintf("%.2f", r_noid), " excluding Idaho.")) +
  blog_theme() +
  theme(plot.title = element_text(size = 14.5))

blog_save(fig, "turnout_scatter", height = 6, width = 7.5,
          source = "Sources: Anthropic Economic Index; state ballot totals; Census 2024 adult population.")
