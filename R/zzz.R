.onLoad <- function(libname, pkgname) {
  # Register a Shiny resource path so surface libraries (Three.js,
  # surfviewjs) can be lazy-loaded from JavaScript when surface mode
  # is activated via proxy commands after initial widget creation.
  if (requireNamespace("shiny", quietly = TRUE)) {
    shiny::addResourcePath(
      "orthoviewer-lib",
      system.file("htmlwidgets/lib", package = pkgname)
    )
  }
}
