# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, cowplot, glue)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"
source(file.path(root, "code/_blog_style.R"))

##
# Blog figure: the same diff-in-differences run on all estimable topic
# series - where does the politics t-statistic fall? (check due to AH)
##

nd = read_csv(file.path(root, "modified_data/null_distribution.csv"),
              show_col_types = FALSE)
pol_t = nd$t[nd$topic == "Politics and public record"]
rank_pol = sum(nd$t >= pol_t)

fig = ggplot(nd, aes(x = t)) +
  geom_histogram(binwidth = 0.25, fill = blog_gray, color = blog_bg, linewidth = 0.4) +
  geom_vline(xintercept = pol_t, color = blog_teal, linewidth = 1.1) +
  annotate("text", x = pol_t + 0.15, y = 26, hjust = 0, size = 3.7,
           color = blog_teal, fontface = "bold", lineheight = 1.1,
           label = glue("Politics and public record\nt = {sprintf('%.2f', pol_t)} (rank {rank_pol} of {nrow(nd)})")) +
  labs(title = "Distribution of t-Statistics Across All Estimable Topics",
       subtitle = glue("The same difference-in-differences run on all {nrow(nd)} topic series.\nUS states, April to May 2026."),
       x = "t-statistic on Primary x May",
       y = glue("Number of topics (of {nrow(nd)})")) +
  blog_theme()

blog_save(fig, "tstat_distribution", height = 5.5, width = 8)
