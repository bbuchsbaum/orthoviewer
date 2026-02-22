##' Create an orthogonal brain viewer
##'
##' This is the main entry point for viewing neuroimaging data. It returns
##' a builder object that can be customized with additional layers and options
##' using a fluent (pipe-friendly) API.
##'
##' @param vol The background volume - a 3D array or neuroim2 NeuroVol object.
##' @param colormap Character: colormap for the background (default "Greys").
##' @param range Numeric vector of length 2: display window range. If NULL,
##'   the volume's data range is used.
##'
##' @return An \code{ortho_builder} object that can be piped to \code{layer()},
##'   \code{status_bar()}, \code{controls()}, and \code{launch()}.
##'
##' @details
##' The builder pattern allows composing viewers declaratively:
##' \preformatted{
##' view_ortho(brain) |>
##'   layer(stat_map, colormap = "hot", thresh = c(-2, 2)) |>
##'   layer(roi_mask, colormap = "cool", opacity = 0.5) |>
##'   controls() |>
##'   launch()
##' }
##'
##' In interactive sessions, the viewer launches automatically when printed.
##' Use \code{launch = FALSE} in \code{launch()} to get the Shiny app object
##' without running it.
##'
##' @export
##' @examples
##' \dontrun{
##' # Simple view
##' view_ortho(brain)
##'
##' # With overlay
##' view_ortho(brain) |>
##'   layer(stat_map, thresh = c(-3, 3))
##'
##' # Full featured
##' view_ortho(brain) |>
##'   layer(activation, colormap = "hot", thresh = c(-2, 2)) |>
##'   layer(roi, colormap = "cool", opacity = 0.5) |>
##'   controls() |>
##'   launch()
##' }
view_ortho <- function(vol,
                       colormap = "Greys",
                       range = NULL) {
  structure(
    list(
      background = list(
        vol = vol,
        colormap = colormap,
        range = range
      ),
      layers = list(),
      handlers = list(),
      status_bar = TRUE,
      controls = FALSE,
      title = "orthoviewer",
      height = "700px",
      debug = FALSE
    ),
    class = "ortho_builder"
  )
}


##' Add an overlay layer to the viewer
##'
##' Adds a volume as an overlay layer with its own colormap, threshold,
##' opacity, and display range settings.
##'
##' @param builder An \code{ortho_builder} object from \code{view_ortho()}.
##' @param vol The overlay volume - a 3D array or neuroim2 NeuroVol object.
##' @param colormap Character: colormap for this layer (default "hot").
##'   Options include "viridis", "plasma", "hot", "cool", "RdBu", etc.
##' @param thresh Numeric vector of length 2: threshold range. Values between
##'   the low and high thresholds are made transparent. Default c(-2, 2) works
##'   well for z-score maps.
##' @param range Numeric vector of length 2: display window range. If NULL,
##'   the volume's data range is used.
##' @param opacity Numeric: layer opacity from 0 (transparent) to 1 (opaque).
##'   Default 0.8.
##' @param id Character: unique identifier for this layer. If NULL, an
##'   automatic id is generated.
##'
##' @return The modified \code{ortho_builder} object (for chaining).
##'
##' @export
##' @examples
##' \dontrun{
##' view_ortho(brain) |>
##'   layer(stat_map, colormap = "hot", thresh = c(-3, 3)) |>
##'   layer(roi_mask, colormap = "cool", opacity = 0.5)
##' }
layer <- function(builder,
                  vol,
                  colormap = "hot",
                  thresh = c(-2, 2),
                  range = NULL,
                  opacity = 0.8,
                  id = NULL) {
  if (!inherits(builder, "ortho_builder")) {
    stop("layer() must be called on an ortho_builder object from view_ortho()",
         call. = FALSE)
  }

  # Generate automatic id if not provided
  if (is.null(id)) {
    id <- paste0("layer_", length(builder$layers) + 1)
  }

  builder$layers <- c(builder$layers, list(list(
    vol = vol,
    colormap = colormap,
    thresh = thresh,
    range = range,
    opacity = opacity,
    id = id
  )))

  builder
}


##' Toggle the status bar
##'
##' The status bar shows the current crosshair position (world and voxel
##' coordinates) and intensity values at that location.
##'
##' @param builder An \code{ortho_builder} object.
##' @param show Logical: whether to show the status bar. Default TRUE.
##'
##' @return The modified \code{ortho_builder} object (for chaining).
##'
##' @export
##' @examples
##' \dontrun{
##' # Enable status bar (default is already TRUE)
##' view_ortho(brain) |> status_bar()
##'
##' # Disable status bar
##' view_ortho(brain) |> status_bar(FALSE)
##' }
status_bar <- function(builder, show = TRUE) {
  if (!inherits(builder, "ortho_builder")) {
    stop("status_bar() must be called on an ortho_builder object",
         call. = FALSE)
  }
  builder$status_bar <- show
  builder
}


##' Toggle the control panel
##'
##' The control panel is a sidebar with interactive controls for adjusting
##' overlay threshold, opacity, colormap, and navigation.
##'
##' @param builder An \code{ortho_builder} object.
##' @param show Logical: whether to show the control panel. Default TRUE.
##'
##' @return The modified \code{ortho_builder} object (for chaining).
##'
##' @export
##' @examples
##' \dontrun{
##' # Enable control panel
##' view_ortho(brain) |>
##'   layer(stat_map) |>
##'   controls()
##' }
controls <- function(builder, show = TRUE) {
  if (!inherits(builder, "ortho_builder")) {
    stop("controls() must be called on an ortho_builder object",
         call. = FALSE)
  }
  builder$controls <- show
  builder
}


##' Set viewer title
##'
##' @param builder An \code{ortho_builder} object.
##' @param title Character: the window/page title.
##'
##' @return The modified \code{ortho_builder} object (for chaining).
##'
##' @export
set_title <- function(builder, title) {
  if (!inherits(builder, "ortho_builder")) {
    stop("set_title() must be called on an ortho_builder object",
         call. = FALSE)
  }
  builder$title <- title
  builder
}


##' Enable debug mode
##'
##' When enabled, verbose logging is printed to the browser console.
##'
##' @param builder An \code{ortho_builder} object.
##' @param enable Logical: whether to enable debug mode. Default TRUE.
##'
##' @return The modified \code{ortho_builder} object (for chaining).
##'
##' @export
debug_mode <- function(builder, enable = TRUE) {
  if (!inherits(builder, "ortho_builder")) {
    stop("debug_mode() must be called on an ortho_builder object",
         call. = FALSE)
  }
  builder$debug <- enable
  builder
}


##' Register a click event handler
##'
##' Registers a function to be called whenever the user clicks on the viewer.
##' This is a convenience for standalone viewers built with the fluent API.
##' For embedded widgets in custom Shiny apps, use \code{\link{ortho_clicks}}
##' or \code{\link{ortho_on_click}} instead.
##'
##' @param builder An \code{ortho_builder} object.
##' @param handler A function that takes a single argument - an ortho_event
##'   object containing \code{world} (coordinates in mm), \code{voxel}
##'   (indices), \code{intensity} (values at location), \code{view}
##'   (which slice was clicked), and modifier key state.
##'
##' @return The modified \code{ortho_builder} object (for chaining).
##'
##' @details
##' The handler function receives a normalized ortho_event object. Use the
##' accessor functions to extract data:
##' \itemize{
##'   \item \code{ortho_world(click)} - world coordinates (mm)
##'   \item \code{ortho_voxel(click)} - voxel indices
##'   \item \code{ortho_intensity(click)} - intensity values
##'   \item \code{ortho_modifier(click, "shift")} - modifier key state
##' }
##'
##' @export
##' @examples
##' \dontrun{
##' view_ortho(brain) |>
##'   layer(stat_map, thresh = c(-3, 3)) |>
##'   on_click(function(click) {
##'     world <- ortho_world(click)
##'     message("Clicked at: ", paste(round(world, 1), collapse = ", "))
##'   }) |>
##'   launch()
##' }
on_click <- function(builder, handler) {
  if (!inherits(builder, "ortho_builder")) {
    stop("on_click() must be called on an ortho_builder object",
         call. = FALSE)
  }
  if (!is.function(handler)) {
    stop("handler must be a function", call. = FALSE)
  }
  builder$handlers$click <- handler
  builder
}


##' Register a double-click event handler
##'
##' @inheritParams on_click
##' @return The modified \code{ortho_builder} object (for chaining).
##' @export
##' @seealso \code{\link{on_click}} for details on event handlers
on_dblclick <- function(builder, handler) {
  if (!inherits(builder, "ortho_builder")) {
    stop("on_dblclick() must be called on an ortho_builder object",
         call. = FALSE)
  }
  if (!is.function(handler)) {
    stop("handler must be a function", call. = FALSE)
  }
  builder$handlers$dblclick <- handler
  builder
}


##' Register a hover event handler
##'
##' @inheritParams on_click
##' @return The modified \code{ortho_builder} object (for chaining).
##' @export
##' @seealso \code{\link{on_click}} for details on event handlers
on_hover <- function(builder, handler) {
  if (!inherits(builder, "ortho_builder")) {
    stop("on_hover() must be called on an ortho_builder object",
         call. = FALSE)
  }
  if (!is.function(handler)) {
    stop("handler must be a function", call. = FALSE)
  }
  builder$handlers$hover <- handler
  builder
}


##' Register a crosshair change event handler
##'
##' @inheritParams on_click
##' @return The modified \code{ortho_builder} object (for chaining).
##' @export
##' @seealso \code{\link{on_click}} for details on event handlers
on_crosshair <- function(builder, handler) {
  if (!inherits(builder, "ortho_builder")) {
    stop("on_crosshair() must be called on an ortho_builder object",
         call. = FALSE)
  }
  if (!is.function(handler)) {
    stop("handler must be a function", call. = FALSE)
  }
  builder$handlers$crosshair <- handler
  builder
}


##' Launch the viewer
##'
##' Builds and runs the Shiny app from the builder specification.
##'
##' @param builder An \code{ortho_builder} object.
##' @param run Logical: if TRUE (default), launches the app immediately.
##'   If FALSE, returns the Shiny app object without launching.
##'
##' @return If \code{run = TRUE}, returns the app invisibly after it closes.
##'   If \code{run = FALSE}, returns the Shiny app object.
##'
##' @export
##' @examples
##' \dontrun{
##' # Launch immediately
##' view_ortho(brain) |> launch()
##'
##' # Get app object without launching
##' app <- view_ortho(brain) |> launch(run = FALSE)
##' }
launch <- function(builder, run = TRUE) {
  if (!inherits(builder, "ortho_builder")) {
    stop("launch() must be called on an ortho_builder object",
         call. = FALSE)
  }

  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required.", call. = FALSE)
  }

  # Extract builder components
  bg <- builder$background
  layers <- builder$layers
  handlers <- builder$handlers
  show_status <- builder$status_bar
  show_controls <- builder$controls
  title <- builder$title
  height <- builder$height
  debug <- builder$debug

  n_layers <- length(layers)

  # Available colormaps for control panel
  colormaps <- c("viridis", "plasma", "inferno", "magma", "hot", "cool",
                 "Greys", "RdBu", "coolwarm", "jet")

  # Build UI
  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$title(title),
      shiny::tags$style(shiny::HTML("
        html, body { height: 100%; margin: 0; padding: 0; }
        .container-fluid { height: 100%; padding: 0; }
        .main-container { display: flex; flex-direction: column; height: 100vh; }
        .main-row { display: flex; flex: 1; min-height: 0; }
        .viewer-col { flex: 1; min-width: 0; height: 100%; }
        .controls-col {
          width: 280px;
          padding: 15px;
          background: #f8f9fa;
          border-left: 1px solid #dee2e6;
          overflow-y: auto;
        }
        .control-group {
          margin-bottom: 15px;
          padding: 10px;
          background: white;
          border-radius: 4px;
          border: 1px solid #e9ecef;
        }
        .control-group h5 {
          margin: 0 0 10px 0;
          font-size: 13px;
          color: #495057;
          border-bottom: 1px solid #e9ecef;
          padding-bottom: 5px;
        }
        .status-bar {
          background: #343a40;
          color: #f8f9fa;
          padding: 8px 15px;
          font-family: monospace;
          font-size: 13px;
          border-top: 1px solid #495057;
        }
        .status-bar .coord { color: #69b3ff; }
        .status-bar .intensity { color: #98d977; }
        .status-bar .separator { color: #6c757d; margin: 0 15px; }
      "))
    ),
    shiny::div(class = "main-container",
      shiny::div(class = "main-row",
        shiny::div(class = "viewer-col",
          ortho_viewerOutput("viewer",
            height = if (show_status) "calc(100% - 40px)" else "100%")
        ),
        if (show_controls && n_layers > 0) {
          shiny::div(class = "controls-col",
            shiny::div(class = "control-group",
              shiny::h5("Navigation"),
              shiny::numericInput("coord_x", "X (mm)", value = 0, step = 5, width = "100%"),
              shiny::numericInput("coord_y", "Y (mm)", value = 0, step = 5, width = "100%"),
              shiny::numericInput("coord_z", "Z (mm)", value = 0, step = 5, width = "100%"),
              shiny::actionButton("go_coords", "Go", class = "btn-sm btn-primary", width = "100%")
            ),
            lapply(seq_along(layers), function(i) {
              lyr <- layers[[i]]
              shiny::div(class = "control-group",
                shiny::h5(lyr$id),
                shiny::checkboxInput(paste0("visible_", i), "Visible", value = TRUE),
                shiny::sliderInput(paste0("opacity_", i), "Opacity",
                  min = 0, max = 1, value = lyr$opacity, step = 0.1, width = "100%"),
                shiny::sliderInput(paste0("thresh_", i), "Threshold",
                  min = -10, max = 10, value = lyr$thresh, step = 0.5, width = "100%"),
                shiny::selectInput(paste0("cmap_", i), "Colormap",
                  choices = colormaps, selected = lyr$colormap, width = "100%")
              )
            })
          )
        }
      ),
      if (show_status) {
        shiny::div(class = "status-bar",
          shiny::span(class = "coord", shiny::textOutput("status_coords", inline = TRUE)),
          shiny::span(class = "separator", "|"),
          shiny::span(class = "intensity", shiny::textOutput("status_intensity", inline = TRUE))
        )
      }
    )
  )

  server <- function(input, output, session) {
    output$viewer <- renderOrtho_viewer({
      ortho_viewer(bg$vol,
                   bg_colormap = bg$colormap,
                   bg_range = bg$range,
                   debug = debug)
    })

    # Add overlay layers after viewer is ready
    if (n_layers > 0) {
      shiny::observe({
        p <- ortho_proxy("viewer", session)
        for (i in seq_along(layers)) {
          lyr <- layers[[i]]
          p$add_layer(
            lyr$vol,
            id = lyr$id,
            thresh = lyr$thresh,
            range = lyr$range,
            colormap = lyr$colormap,
            opacity = lyr$opacity
          )
        }
      })

      # Wire up controls for each layer (if controls enabled)
      if (show_controls) {
        lapply(seq_along(layers), function(i) {
          lyr <- layers[[i]]

          # Visibility
          shiny::observeEvent(input[[paste0("visible_", i)]], {
            p <- ortho_proxy("viewer", session)
            p$set_layer_visible(lyr$id, input[[paste0("visible_", i)]])
          }, ignoreInit = TRUE)

          # Opacity
          shiny::observeEvent(input[[paste0("opacity_", i)]], {
            p <- ortho_proxy("viewer", session)
            p$set_opacity(input[[paste0("opacity_", i)]], layer_id = lyr$id)
          }, ignoreInit = TRUE)

          # Threshold
          shiny::observeEvent(input[[paste0("thresh_", i)]], {
            p <- ortho_proxy("viewer", session)
            p$set_threshold(input[[paste0("thresh_", i)]], layer_id = lyr$id)
          }, ignoreInit = TRUE)

          # Colormap
          shiny::observeEvent(input[[paste0("cmap_", i)]], {
            p <- ortho_proxy("viewer", session)
            p$set_colormap(input[[paste0("cmap_", i)]], layer_id = lyr$id)
          }, ignoreInit = TRUE)
        })

        # Navigation
        shiny::observeEvent(input$go_coords, {
          p <- ortho_proxy("viewer", session)
          p$set_crosshair(input$coord_x, input$coord_y, input$coord_z, animate = TRUE)
        })
      }
    }

    # Status bar updates
    if (show_status) {
      output$status_coords <- shiny::renderText({
        crosshair <- input$viewer_crosshair
        if (is.null(crosshair) || is.null(crosshair$world)) {
          "Position: -- , -- , --"
        } else {
          w <- crosshair$world
          sprintf("Position: %.1f, %.1f, %.1f mm", w[1], w[2], w[3])
        }
      })

      output$status_intensity <- shiny::renderText({
        crosshair <- input$viewer_crosshair
        if (is.null(crosshair) || is.null(crosshair$intensity)) {
          "Intensity: --"
        } else {
          # Get first non-null intensity value
          vals <- unlist(crosshair$intensity)
          if (length(vals) > 0 && !all(is.na(vals))) {
            sprintf("Intensity: %.2f", vals[1])
          } else {
            "Intensity: --"
          }
        }
      })
    }

    # Wire up user-registered event handlers
    if (!is.null(handlers$click)) {
      ortho_on_click("viewer", handlers$click, session)
    }

    if (!is.null(handlers$dblclick)) {
      ortho_on_dblclick("viewer", handlers$dblclick, session)
    }

    if (!is.null(handlers$hover)) {
      ortho_on_hover("viewer", handlers$hover, session)
    }

    if (!is.null(handlers$crosshair)) {
      # For crosshair, use ortho_crosshairs reactive
      crosshairs <- ortho_crosshairs("viewer", session)
      shiny::observeEvent(crosshairs(), {
        event <- crosshairs()
        if (!is.null(event)) {
          handlers$crosshair(event)
        }
      })
    }
  }

  app <- shiny::shinyApp(ui, server)

  if (run && interactive()) {
    shiny::runApp(app)
    invisible(app)
  } else {
    app
  }
}


##' @export
print.ortho_builder <- function(x, ...) {
 if (interactive()) {
    launch(x)
  } else {
    cat("ortho_builder object:\n")
    cat("  Background:", if (is.array(x$background$vol)) "array" else class(x$background$vol)[1], "\n")
    cat("  Colormap:", x$background$colormap, "\n")
    cat("  Layers:", length(x$layers), "\n")
    cat("  Status bar:", x$status_bar, "\n")
    cat("  Controls:", x$controls, "\n")
    cat("\nCall launch() or print in interactive mode to view.\n")
  }
  invisible(x)
}


