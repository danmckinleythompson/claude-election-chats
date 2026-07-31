# 05_post_brand.R -----------------------------------------------------------
# Renders every post figure in the Free Systems house style and writes the
# numbered PNGs the post is assembled from. Chart geometry comes from
# fig_defs.R (shared with the memo); this file only supplies the brand palette
# and wraps each chart in the standard header and footer:
#
#   |  <accent rule>
#   |  Title
#   |  Subtitle
#   |  [ chart ]
#   |  ------------------------------------------------
#   |  [logo]              Source: ...  freesystems.substack.com
#
# Brand system: ~/freesystems/CLAUDE.md (off-white #FAFAF7, ink #1A1A18,
# deep teal #2B5B6C, warm copper #C4703E).
#
# FONT CAVEAT: the brand faces (Playfair Display, DM Sans, JetBrains Mono) are
# not installed on this machine -- `systemfonts::system_fonts()` has none of
# them. Avenir Next is the closest installed geometric sans and is used
# throughout. Install the real faces and change fs_pal$family in fig_defs.R to
# get the true brand typography; nothing else needs to change.
# ---------------------------------------------------------------------------
pacman::p_load(tidyverse, glue, cowplot, ragg, png, grid)
set.seed(42)
options(scipen = 999)
root = if (dir.exists("original_data")) normalizePath(".") else "~/Dropbox/AIElectionResearch"

source(file.path(root, "code/memo/fig_defs.R"))
outdir   = file.path(root, "output/memo")
post_dir = file.path(root, "output/post")
dir.create(post_dir, recursive = TRUE, showWarnings = FALSE)

URL      = "freesystems.substack.com"
LOGO     = file.path(root, "code/memo/assets/free_systems_logo.png")
DPI      = 200
HEAD_IN  = 1.05   # inches reserved above the chart for rule + title + subtitle
FOOT_IN  = 0.72   # inches reserved below the chart for the hairline + logo row
PAD_IN   = 0.34   # left/right page margin

stopifnot(file.exists(LOGO))
logo_raster = png::readPNG(LOGO)
LOGO_AR = dim(logo_raster)[2] / dim(logo_raster)[1]   # width / height
logo_grob = grid::rasterGrob(logo_raster, interpolate = TRUE)

# Compose one branded page: the chart on a brand-coloured canvas, with the
# header and footer measured in inches and converted to npc, so the bands stay
# a fixed physical size no matter how tall the chart is.
brand_page = function(spec) {
  W = spec$w + 2 * PAD_IN
  H = spec$h + HEAD_IN + FOOT_IN
  x  = function(inches) inches / W
  y  = function(inches) inches / H

  ggdraw(xlim = c(0, 1), ylim = c(0, 1)) +
    draw_grob(grid::rectGrob(gp = grid::gpar(fill = fs_pal$bg, col = NA))) +
    # the chart itself
    draw_plot(spec$plot, x = x(PAD_IN), y = y(FOOT_IN),
              width = x(spec$w), height = y(spec$h)) +
    # header: a short teal rule, then title and subtitle, all flush left
    draw_line(x = c(x(PAD_IN), x(PAD_IN + 0.62)), y = 1 - y(0.30),
              color = fs_pal$accent, linewidth = 2.4, lineend = "butt") +
    draw_label(spec$title, x = x(PAD_IN), y = 1 - y(0.55), hjust = 0, vjust = 1,
               size = 17, fontface = "bold", fontfamily = fs_pal$family,
               color = "#1A1A18") +
    draw_label(str_wrap(spec$subtitle, 118), x = x(PAD_IN), y = 1 - y(0.86),
               hjust = 0, vjust = 1, size = 10.5, fontfamily = fs_pal$family,
               color = "#6B6B63", lineheight = 1.15) +
    # footer: hairline, logo left, source and link right
    draw_line(x = c(x(PAD_IN), 1 - x(PAD_IN)), y = y(FOOT_IN - 0.10),
              color = fs_pal$rule, linewidth = 0.5) +
    draw_grob(logo_grob, x = x(PAD_IN), y = y(0.16),
              height = y(0.30), width = x(0.30 * LOGO_AR)) +
    draw_label(AEI_SOURCE, x = 1 - x(PAD_IN), y = y(0.40), hjust = 1, vjust = 0.5,
               size = 8.2, fontfamily = fs_pal$family, color = "#8C8C86") +
    draw_label(URL, x = 1 - x(PAD_IN), y = y(0.20), hjust = 1, vjust = 0.5,
               size = 9.2, fontface = "bold", fontfamily = fs_pal$family,
               color = fs_pal$accent)
}

## --- clear stale assets ------------------------------------------------------
# The post used to ship seven tables under a different numbering. Anything not
# in FIGS is left over and would be dragged into the doc beside its replacement.
keep = paste0(FIGS$out, ".png")
stale = setdiff(basename(Sys.glob(file.path(post_dir, "post_*.png"))), keep)
if (length(stale)) {
  file.remove(file.path(post_dir, stale))
  message("[05] removed ", length(stale), " stale asset(s): ", paste(stale, collapse = ", "))
}
# The post folder holds only the finished PNGs; intermediate PDFs and the old
# LaTeX scratch directory belong in output/memo or nowhere.
for (cruft in c(Sys.glob(file.path(post_dir, "*.pdf")), file.path(post_dir, "_tex"))) {
  if (file.exists(cruft)) {
    unlink(cruft, recursive = TRUE)
    message("[05] removed ", basename(cruft), " from output/post")
  }
}

## --- render ------------------------------------------------------------------
for (i in seq_len(nrow(FIGS))) {
  f = FIGS[i, ]
  spec = f$fn[[1]](fs_pal, outdir, root)
  ggsave(file.path(post_dir, paste0(f$out, ".png")), brand_page(spec),
         width = spec$w + 2 * PAD_IN, height = spec$h + HEAD_IN + FOOT_IN,
         dpi = DPI, device = ragg::agg_png, bg = fs_pal$bg)
}

made = file.path(post_dir, paste0(FIGS$out, ".png"))
stopifnot(all(file.exists(made)))
message("[05] rendered ", nrow(FIGS), " branded figures to ", post_dir)
print(tibble(slot = FIGS$slot, file = paste0(FIGS$out, ".png"),
             kb = round(file.size(made) / 1024)))
