args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1L) {
  args[[1L]]
} else {
  file.path("tests", "ui", ".tmp", "fixture")
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("The 'devtools' package is required to generate UI fixture pages.")
}

if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
  stop("The 'htmlwidgets' package is required to generate UI fixture pages.")
}

devtools::load_all(".")

set.seed(20260213)
bg <- array(stats::rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))

widget <- ortho_viewer(
  bg_volume = bg,
  bg_colormap = "Greys",
  height = 700
)

htmlwidgets::saveWidget(
  widget = widget,
  file = file.path(out_dir, "index.html"),
  selfcontained = FALSE,
  title = "orthoviewer-ui-fixture"
)
