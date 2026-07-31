# Sourced helper, not runnable: palette, theme, and framing for the blog
# figures, matched to the style of the draft post's charts

blog_bg     = "#FBF6EC"
blog_border = "#E4D9BF"
blog_teal   = "#22697A"
blog_gray   = "#C7C1B2"
blog_orange = "#C67D3B"
blog_dark   = "#222222"
blog_grid   = "#E8E2D2"

blog_theme = function(base_size = 13) {
  theme_minimal(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(color = blog_grid, linewidth = 0.4),
          axis.text = element_text(size = base_size - 2, color = "gray25"),
          axis.title = element_text(size = base_size - 1.5, color = "gray25"),
          plot.title = element_text(face = "bold", size = base_size + 3, hjust = 0,
                                    color = blog_dark),
          plot.subtitle = element_text(size = base_size - 2.5, hjust = 0, color = "gray40",
                                       lineheight = 1.15),
          legend.position = "bottom",
          legend.text = element_text(size = base_size - 2.5, color = "gray25"),
          plot.background = element_rect(fill = blog_bg, color = NA),
          panel.background = element_rect(fill = blog_bg, color = NA),
          legend.background = element_rect(fill = blog_bg, color = NA))
}

# Frame a plot in the house chrome: teal accent bar top-left, footer rule,
# "Free Systems" at left, source and site at right; pdf + png twins to output/
blog_save = function(fig, stem, height, width,
                     source = "Source: Anthropic Economic Index, 2026-06-26 release. Shares are of classified conversations.") {
  final = cowplot::ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
    cowplot::draw_plot(fig, x = 0.015, y = 0.075, width = 0.97, height = 0.895) +
    cowplot::draw_line(x = c(0.045, 0.105), y = c(0.978, 0.978),
                       color = blog_teal, linewidth = 2.4) +
    cowplot::draw_line(x = c(0.03, 0.97), y = c(0.062, 0.062),
                       color = blog_border, linewidth = 0.5) +
    cowplot::draw_label("Free Systems", x = 0.045, y = 0.038, hjust = 0,
                        size = 10.5, fontface = "bold", color = blog_dark) +
    cowplot::draw_label(source, x = 0.965, y = 0.044, hjust = 1, size = 8,
                        color = "gray45") +
    cowplot::draw_label("freesystems.substack.com", x = 0.965, y = 0.022, hjust = 1,
                        size = 9, fontface = "bold", color = blog_teal) +
    theme(plot.background = element_rect(fill = blog_bg, color = blog_border,
                                         linewidth = 1))
  ggsave(file.path(root, "output", paste0(stem, ".pdf")), final,
         height = height, width = width, bg = blog_bg)
  ggsave(file.path(root, "output", paste0(stem, ".png")), final,
         height = height, width = width, dpi = 300, bg = blog_bg)
}
