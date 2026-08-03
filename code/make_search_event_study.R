# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest, broom)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: monthly event study of search interest for the May-primary states,
# holding out March 2026 - the last month before treated states' election
# activity begins - so the leads test parallel trends and the April and May
# coefficients show anticipation and the primary-month peak
##

panel = read_csv(file.path(root, "modified_data/search_did_data.csv"),
                 show_col_types = FALSE) |>
  filter(aei_sample) |>
  mutate(month_f = factor(format(month, "%Y-%m")))

m_es = feols(log1p(mean_index) ~ i(month_f, treat_may, ref = "2026-03") | state_po + month_f,
             data = panel, cluster = ~state_po)

es = tidy(m_es, conf.int = TRUE) |>
  mutate(month = as.Date(paste0(str_extract(term, "\\d{4}-\\d{2}"), "-01"))) |>
  bind_rows(tibble(month = as.Date("2026-03-01"), estimate = 0, conf.low = 0, conf.high = 0))

fig = ggplot(es, aes(x = month, y = estimate)) +
  annotate("rect", xmin = as.Date("2026-04-01"), xmax = as.Date("2026-05-31"),
           ymin = -Inf, ymax = Inf, fill = "gray92") +
  annotate("text", x = as.Date("2026-04-30"), y = -0.45, label = "AEI\nwindow",
           color = "gray45", size = 4.5, lineheight = 0.9) +
  geom_hline(yintercept = 0, color = "gray70") +
  geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0, color = "gray20") +
  geom_point(color = "gray20", size = 2.5) +
  scale_x_date(date_breaks = "2 months", date_labels = "%b %Y") +
  labs(x = NULL, y = "May-Primary x Month Effect on Log Search Interest") +
  theme_classic(base_size = 16) +
  theme(plot.background = element_rect(fill = "white", color = NA))

ggsave(file.path(root, "output/search_event_study.pdf"), plot = fig,
       height = 6, width = 10)

##
# Print the identification numbers the memo cites: parallel leads, then the
# April anticipation rise and the larger May increase
##

pre = grep("2025-|2026-01|2026-02", names(coef(m_es)), value = TRUE)
cat("\nJoint test, Jul 2025-Feb 2026 leads = 0 (parallel pre-trends):\n")
print(wald(m_es, keep = pre))
cat("\nApril (anticipation) and May (primary month) relative to March:\n")
print(round(coeftable(m_es)[c("month_f::2026-04:treat_may", "month_f::2026-05:treat_may"), 1:2], 3))
