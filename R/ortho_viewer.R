##' Orthogonal neuroimaging viewer (htmlwidget shell)
##'
##' This is a thin R wrapper around the JavaScript orthogonal viewer
##' implemented in \code{~/code/jscode/neuroimjs}. It is intended to be
##' driven primarily from Shiny via a proxy object; the HTML widget
##' handles layout and JS wiring.
##'
##' @param bg_volume A 3D volume object (e.g., from \code{neuroim2}) or a
##'   numeric array. For now this is treated as a raw array; integration
##'   helpers with \code{neuroim2} will be added separately.
##' @param bg_colormap Name of the colormap to use for the background
##'   volume (e.g., \code{"Greys"}).
##' @param bg_range Optional numeric vector of length 2 specifying the
##'   intensity range for display windowing. If NULL (default), the
##'   volume's data range is used.
##' @param width,height Widget dimensions passed to \code{htmlwidgets}.
##' @param elementId Optional element id.
##' @param show_sidebar Logical: if TRUE (default), the widget renders its
##'   own layer-control sidebar. Set to FALSE when embedding inside a host
##'   application that provides its own sidebar (e.g., the orthoviewer app).
##' @param debug Logical: if TRUE, enable verbose console logging in the
##'   JavaScript viewer for debugging. Default FALSE.
##' @return An \code{htmlwidget} object that can be used in R Markdown
##'   documents or Shiny applications.
##' @export
ortho_viewer <- function(bg_volume,
                         bg_colormap = "Greys",
                         bg_range = NULL,
                         width = "100%",
                         height = 600,
                         elementId = NULL,
                         show_sidebar = TRUE,
                         debug = FALSE) {

  if (!requireNamespace("htmlwidgets", quietly = TRUE)) {
    stop("The 'htmlwidgets' package is required to use ortho_viewer().",
         call. = FALSE)
  }

  bg_spec <- serialize_volume_for_js(bg_volume)

  x <- list(
    bg_volume    = bg_spec,
    bg_colormap  = bg_colormap,
    bg_range     = if (!is.null(bg_range)) as.numeric(bg_range) else NULL,
    show_sidebar = isTRUE(show_sidebar),
    debug        = debug,
    commands     = list()
  )
  deps <- ortho_viewer_dependencies()

  htmlwidgets::createWidget(
    name      = "ortho_viewer",
    x         = x,
    width     = width,
    height    = height,
    package   = "orthoviewer",
    elementId = elementId,
    dependencies = deps
  )
}

##' Shiny output for \code{ortho_viewer}
##'
##' @param outputId Shiny output id.
##' @param width,height Output dimensions.
##' @export
ortho_viewerOutput <- function(outputId,
                               width = "100%",
                               height = "600px") {
  htmlwidgets::shinyWidgetOutput(
    outputId, "ortho_viewer", width, height, package = "orthoviewer"
  )
}

##' Shiny render function for \code{ortho_viewer}
##'
##' @param expr An expression that returns an \code{ortho_viewer} widget.
##' @param env,quoted Standard \code{htmlwidgets} arguments.
##' @export
renderOrtho_viewer <- function(expr,
                               env = parent.frame(),
                               quoted = FALSE) {
  if (!quoted) expr <- substitute(expr)
  htmlwidgets::shinyRenderWidget(
    expr, ortho_viewerOutput, env, quoted = TRUE
  )
}

##' Serialize a 3D volume for use in neuroimjs
##'
##' This function converts an R array or a \code{neuroim2} volume into a
##' plain list that can be JSON-encoded and consumed by the JavaScript
##' viewer. For now the implementation is intentionally minimal and
##' assumes a 3D numeric array. Integration with \code{neuroim2}
##' objects will be added once the JS side is fully wired.
##'
##' @param vol A 3D numeric array or a compatible object. If the object
##'   comes from \code{neuroim2} (e.g., a \code{DenseNeuroVol}), spatial
##'   metadata (spacing, origin, axes) will be extracted when possible.
##' @return A list with \code{dim}, \code{data}, and placeholders for
##'   spatial metadata.
##' @keywords internal
serialize_volume_for_js <- function(vol) {
  if (is.null(vol)) {
    stop("bg_volume must not be NULL", call. = FALSE)
  }

  ## Handle neuroim2 volumes when the package is available. We detect
  ## them via S4 class membership and use generics from neuroim2 to
  ## extract spatial metadata. If anything fails, we fall back to the
  ## plain array path below.
  if (inherits(vol, "NeuroVol") || inherits(vol, "NeuroObj")) {
    ## Lazy import to avoid a hard dependency at function definition
    if (requireNamespace("neuroim2", quietly = TRUE)) {
      sp <- try(neuroim2::space(vol), silent = TRUE)
      sp_spacing <- try(neuroim2::spacing(sp), silent = TRUE)
      sp_origin <- try(neuroim2::origin(sp), silent = TRUE)
      sp_axes <- try(neuroim2::axes(sp), silent = TRUE)

      arr <- try(as.array(vol), silent = TRUE)

      if (!inherits(arr, "try-error") && length(dim(arr)) >= 3L) {
        ## Derive simple axis labels from the AxisSet when possible.
        axes3 <- c("i", "j", "k")
        if (!inherits(sp_axes, "try-error")) {
          if (methods::is(sp_axes, "AxisSet3D")) {
            get_axis_name <- function(axis_obj) {
              val <- try(axis_obj@axis, silent = TRUE)
              if (!inherits(val, "try-error") && length(val) == 1L) {
                as.character(val)
              } else {
                NA_character_
              }
            }
            raw_axes <- c(
              get_axis_name(sp_axes@i),
              get_axis_name(sp_axes@j),
              get_axis_name(sp_axes@k)
            )
            ## Replace any missing entries with defaults to keep length 3.
            axes3 <- ifelse(is.na(raw_axes) | raw_axes == "", axes3, raw_axes)
          }
        }

        return(list(
          dim     = dim(arr),
          data    = as.numeric(arr),
          spacing = if (!inherits(sp_spacing, "try-error")) sp_spacing[seq_len(min(3L, length(sp_spacing)))] else c(1, 1, 1),
          origin  = if (!inherits(sp_origin, "try-error")) sp_origin[seq_len(min(3L, length(sp_origin)))] else c(0, 0, 0),
          axes    = axes3
        ))
      }
    }
  }

  arr <- if (is.array(vol)) vol else as.array(vol)

  if (length(dim(arr)) != 3L) {
    stop("serialize_volume_for_js currently expects a 3D array.", call. = FALSE)
  }

  list(
    dim     = dim(arr),
    data    = as.numeric(arr),
    spacing = c(1, 1, 1),
    origin  = c(0, 0, 0),
    axes    = c("i", "j", "k")
  )
}
