# Sourced helper, not runnable: palette, theme, and footer assembly for
# figures in the Free Systems blog style (colors read off Andy's posted charts)

fs_blue_dark  = "#2E74C0"
fs_blue_light = "#A9C7E7"
fs_gray_dark  = "#4A4A4A"
fs_gray_light = "#CCCCCC"

fs_theme = function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(color = "gray90", linewidth = 0.4),
          axis.text = element_text(size = base_size - 2.5, color = "gray20"),
          axis.title = element_text(size = base_size - 2, color = "gray20"),
          plot.title = element_text(face = "bold", size = base_size + 4, hjust = 0.5),
          plot.subtitle = element_text(size = base_size - 1.5, hjust = 0.5, color = "gray30"),
          plot.background = element_rect(fill = "white", color = NA))
}

# Wrap a finished plot with the house footer (gray methods note, then the
# site and data credits) and write pdf + png twins to output/
fs_save = function(fig, note, stem, height, width) {
  final = cowplot::ggdraw() +
    cowplot::draw_plot(fig, x = 0, y = 0.065, width = 1, height = 0.935) +
    cowplot::draw_label(str_wrap(note, 105), x = 0.5, y = 0.048, size = 10,
                        color = "gray40") +
    cowplot::draw_label("freesystems.substack.com", x = 0.28, y = 0.014,
                        size = 11.5, fontface = "bold", color = "gray15") +
    cowplot::draw_label("Data: Anthropic Economic Index", x = 0.75, y = 0.014,
                        size = 11.5, fontface = "bold", color = "gray15") +
    theme(plot.background = element_rect(fill = "white", color = NA))
  ggsave(file.path(root, "output", paste0(stem, ".pdf")), final,
         height = height, width = width)
  ggsave(file.path(root, "output", paste0(stem, ".png")), final,
         height = height, width = width, dpi = 300)
}
