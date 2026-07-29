# Set up the packages, options, and working directory path
pacman::p_load(tidyverse, fixest, broom)
set.seed(42)
options(scipen = 999)
root = "~/Dropbox/AIElectionResearch"

##
# Figure: monthly event-study of search interest for the May-primary states,
# referenced to April so the leads test the Apr/May design's identification
##

panel = read_csv(file.path(root, "modified_data/search_did_data.csv"),
                 show_col_types = FALSE) |>
  filter(aei_sample) |>
  mutate(month_f = factor(format(month, "%Y-%m")))

m_es = feols(log1p(mean_index) ~ i(month_f, treat_may, ref = "2026-04") | state_po + month_f,
             data = panel, cluster = ~state_po)

es = tidy(m_es, conf.int = TRUE) |>
  mutate(month = as.Date(paste0(str_extract(term, "\\d{4}-\\d{2}"), "-01"))) |>
  bind_rows(tibble(month = as.Date("2026-04-01"), estimate = 0, conf.low = 0, conf.high = 0))

fig = ggplot(es, aes(x = month, y = estimate)) +
  geom_vline(xintercept = as.Date("2026-05-01"), color = "gray70", linetype = "dashed") +
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
# Identification checks printed for the record: with April as the reference,
# uniformly negative leads say April is already elevated (anticipation); the
# cleaner parallel-trends test re-references to March, the last clean pre-month
##

m_mar = feols(log1p(mean_index) ~ i(month_f, treat_may, ref = "2026-03") | state_po + month_f,
              data = panel, cluster = ~state_po)
pre = grep("2025-|2026-01|2026-02", names(coef(m_mar)), value = TRUE)
cat("\nApril and May relative to March (anticipation and total effect):\n")
print(round(coeftable(m_mar)[c("month_f::2026-04:treat_may", "month_f::2026-05:treat_may"), 1:2], 3))
cat("\nJoint test, Jul 2025-Feb 2026 leads = 0 (parallel pre-trends):\n")
print(wald(m_mar, keep = pre))
