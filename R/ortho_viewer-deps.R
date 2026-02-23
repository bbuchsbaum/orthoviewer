##' htmlwidgets dependencies for the ortho_viewer widget
##'
##' Returns additional \code{htmlDependency} objects that should be
##' included with the widget.  When \code{include_surface} is TRUE,
##' Three.js and surfviewjs are bundled so the surface viewer can
##' initialise immediately.  When FALSE (slice-only mode), those
##' ~600 KB libraries are omitted; they will be lazy-loaded from
##' JavaScript if surface mode is activated later via a proxy command.
##'
##' @param include_surface Logical: include Three.js and surfviewjs?
##'   Defaults to FALSE.
##' @return A list of \code{htmltools::htmlDependency} objects, or NULL.
##' @keywords internal
ortho_viewer_dependencies <- function(include_surface = FALSE) {
  if (!include_surface) return(NULL)

  list(
    htmltools::htmlDependency(
      name    = "three",
      version = "0.132.0",
      src     = c(file = system.file("htmlwidgets/lib/three",
                                     package = "orthoviewer")),
      script  = "three.min.js"
    ),
    htmltools::htmlDependency(
      name    = "surfviewjs",
      version = "2.1.0",
      src     = c(file = system.file("htmlwidgets/lib/surfviewjs",
                                     package = "orthoviewer")),
      script  = "surfview.umd.js"
    )
  )
}
