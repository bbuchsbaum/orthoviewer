##' @title Ortho Viewer Event Handling
##' @name ortho_events
##' @description
##' Functions for handling interactive events from the ortho_viewer widget
##' in Shiny applications. The viewer emits several event types that can be
##' accessed as Shiny inputs.
##'
##' @section Available Events:
##' For a viewer with \code{outputId = "viewer"}, the following inputs are available:
##' \describe{
##'   \item{\code{input$viewer_click}}{Fired when user clicks on any slice view}
##'   \item{\code{input$viewer_dblclick}}{Fired on double-click}
##'   \item{\code{input$viewer_rightclick}}{Fired on right-click (context menu)}
##'   \item{\code{input$viewer_hover}}{Fired as mouse moves over slices (throttled)}
##'   \item{\code{input$viewer_crosshair}}{Fired when crosshair position changes}
##' }
##'
##' @section Event Data Structure:
##' Each event contains a list with the following components:
##' \describe{
##'   \item{\code{world}}{Numeric vector of length 3: world coordinates in mm (x, y, z)}
##'   \item{\code{voxel}}{Integer vector of length 3: voxel indices (i, j, k)}
##'   \item{\code{intensity}}{Named list of intensity values at the coordinate for each layer}
##'   \item{\code{view}}{Character: which view was interacted with ("axial", "coronal", or "sagittal")}
##'   \item{\code{type}}{Character: event type ("click", "dblclick", "rightclick", "hover", "leave")}
##'   \item{\code{button}}{Character: mouse button ("left", "right", "middle") - for click events}
##'   \item{\code{shift}}{Logical: was Shift key held}
##'   \item{\code{ctrl}}{Logical: was Ctrl/Cmd key held}
##'   \item{\code{alt}}{Logical: was Alt key held}
##'   \item{\code{timestamp}}{Numeric: JavaScript timestamp (milliseconds since epoch)}
##' }
NULL


##' Get click event data from ortho_viewer
##'
##' Convenience function to extract and validate click event data from a Shiny input.
##'
##' @param input The Shiny input object.
##' @param viewer_id Character string: the outputId of the ortho_viewer widget.
##' @param event_type Character: type of event to retrieve. One of "click",
##'   "dblclick", "rightclick", "hover", or "crosshair".
##' @return A list containing the event data, or NULL if no event has occurred.
##'   The list is enhanced with class "ortho_event" for pretty printing.
##' @export
##' @examples
##' \dontrun{
##' # In a Shiny server function:
##' observeEvent(input$viewer_click, {
##'   click <- ortho_event(input, "viewer", "click")
##'   if (!is.null(click)) {
##'     message(sprintf("Clicked at world [%.1f, %.1f, %.1f]",
##'                     click$world[1], click$world[2], click$world[3]))
##'   }
##' })
##' }
ortho_event <- function(input, viewer_id, event_type = "click") {
  event_type <- match.arg(event_type, c("click", "dblclick", "rightclick", "hover", "crosshair"))
  input_name <- paste0(viewer_id, "_", event_type)

  event <- input[[input_name]]
  if (is.null(event)) return(NULL)

  # Convert JavaScript arrays to R vectors
  if (!is.null(event$world) && is.list(event$world)) {
    event$world <- unlist(event$world)
  }

  if (!is.null(event$voxel) && is.list(event$voxel)) {
    event$voxel <- as.integer(unlist(event$voxel))
  }

  class(event) <- c("ortho_event", "list")
  event
}


##' Get world coordinates from an ortho_viewer event
##'
##' @param event An ortho_event object or the raw input value.
##' @return Numeric vector of length 3 (x, y, z) in world/mm coordinates,
##'   or NULL if not available.
##' @export
ortho_world <- function(event) {
  if (is.null(event)) return(NULL)
  world <- event$world
  if (is.null(world)) return(NULL)
  if (is.list(world)) world <- unlist(world)
  as.numeric(world)
}


##' Get voxel indices from an ortho_viewer event
##'
##' @param event An ortho_event object or the raw input value.
##' @return Integer vector of length 3 (i, j, k) as voxel indices,
##'   or NULL if not available.
##' @export
ortho_voxel <- function(event) {
  if (is.null(event)) return(NULL)
  voxel <- event$voxel
  if (is.null(voxel)) return(NULL)
  if (is.list(voxel)) voxel <- unlist(voxel)
  as.integer(voxel)
}


##' Get intensity values from an ortho_viewer event
##'
##' @param event An ortho_event object or the raw input value.
##' @param layer_id Optional character: specific layer ID to retrieve.
##'   If NULL, returns all layer intensities as a named numeric vector.
##' @return If \code{layer_id} is specified, returns a single numeric value
##'   (or NA if not found). Otherwise returns a named numeric vector of all
##'   layer intensities.
##' @export
ortho_intensity <- function(event, layer_id = NULL) {
  if (is.null(event)) return(NULL)
  intensity <- event$intensity
  if (is.null(intensity) || length(intensity) == 0) {
    if (!is.null(layer_id)) return(NA_real_)
    return(numeric(0))
  }

  # Convert to named numeric vector
  vals <- vapply(intensity, function(x) {
    if (is.null(x) || length(x) == 0) NA_real_ else as.numeric(x)
  }, numeric(1))

  if (!is.null(layer_id)) {
    if (layer_id %in% names(vals)) {
      return(vals[[layer_id]])
    } else {
      return(NA_real_)
    }
  }

  vals
}


##' Check if a modifier key was held during an event
##'
##' @param event An ortho_event object or the raw input value.
##' @param key Character: which modifier key to check. One of "shift", "ctrl", or "alt".
##' @return Logical indicating whether the key was held, or FALSE if event is NULL.
##' @export
ortho_modifier <- function(event, key = "shift") {
  if (is.null(event)) return(FALSE)
  key <- match.arg(key, c("shift", "ctrl", "alt"))
  isTRUE(event[[key]])
}


##' Print method for ortho_event objects
##'
##' @param x An ortho_event object.
##' @param ... Additional arguments (ignored).
##' @export
print.ortho_event <- function(x, ...) {
  cat("Ortho Viewer Event\n")
  cat("------------------\n")
  cat("Type:", x$type %||% "unknown", "\n")
  cat("View:", x$view %||% "unknown", "\n")

  world <- ortho_world(x)
  if (!is.null(world)) {
    cat(sprintf("World: [%.2f, %.2f, %.2f] mm\n", world[1], world[2], world[3]))
  }


  voxel <- ortho_voxel(x)
  if (!is.null(voxel)) {
    cat(sprintf("Voxel: [%d, %d, %d]\n", voxel[1], voxel[2], voxel[3]))
  }

  intensity <- ortho_intensity(x)
  if (length(intensity) > 0) {
    cat("Intensity:\n")
    for (nm in names(intensity)) {
      cat(sprintf("  %s: %.4f\n", nm, intensity[nm]))
    }
  }

  mods <- c()
  if (ortho_modifier(x, "shift")) mods <- c(mods, "Shift")
  if (ortho_modifier(x, "ctrl")) mods <- c(mods, "Ctrl")
  if (ortho_modifier(x, "alt")) mods <- c(mods, "Alt")
  if (length(mods) > 0) {
    cat("Modifiers:", paste(mods, collapse = " + "), "\n")
  }

  invisible(x)
}


##' Format world coordinates in anatomical notation
##'
##' Converts world coordinates to a human-readable string using anatomical
##' labels (L/R for left/right, A/P for anterior/posterior, S/I for superior/inferior).
##'
##' @param coord Numeric vector of length 3: world coordinates (x, y, z).
##' @param digits Integer: number of decimal places.
##' @return Character string in format "L 23.5 | P 12.3 | S 45.0".
##' @export
##' @examples
##' format_world_coord(c(-23.5, 12.3, 45.0))
##' # Returns: "R 23.5 | P 12.3 | S 45.0"
format_world_coord <- function(coord, digits = 1) {
  if (is.null(coord) || length(coord) < 3) return("L -- | P -- | S --")

  x <- coord[1]
  y <- coord[2]
  z <- coord[3]

  lr <- if (x >= 0) paste0("L ", format(abs(x), nsmall = digits)) else paste0("R ", format(abs(x), nsmall = digits))
  pa <- if (y >= 0) paste0("P ", format(abs(y), nsmall = digits)) else paste0("A ", format(abs(y), nsmall = digits))
  si <- if (z >= 0) paste0("S ", format(abs(z), nsmall = digits)) else paste0("I ", format(abs(z), nsmall = digits))

  paste(lr, pa, si, sep = " | ")
}


# Null coalescing operator (internal)
`%||%` <- function(a, b) if (is.null(a)) b else a


# ---------------------------------------------------------------------------
# Reactive Event Streams
# ---------------------------------------------------------------------------

##' Create a reactive event stream for viewer clicks
##'
##' Returns a reactive expression that emits normalized ortho_event objects
##' whenever the user clicks on the viewer. This is the recommended way to
##' handle click events as it hides the Shiny input naming conventions and
##' provides a composable reactive primitive.
##'
##' @param viewer_id Character: the outputId of the ortho_viewer widget.
##' @param session The Shiny session object. If NULL, uses the current
##'   reactive domain.
##' @return A reactive expression that returns an ortho_event object when
##'
##' @details
##' The returned reactive can be used with \code{observeEvent()},
##' \code{observe()}, or composed with other reactives. Each time it fires,
##' calling it returns the normalized event object with world coordinates,
##' voxel indices, intensity values, and modifier key state.
##'
##' @export
##' @examples
##' \dontrun{
##' server <- function(input, output, session) {
##'   output$viewer <- renderOrtho_viewer({ ortho_viewer(brain) })
##'
##'   # Create reactive click stream
##'   clicks <- ortho_clicks("viewer", session)
##'
##'   # React to clicks
##'   observeEvent(clicks(), {
##'     click <- clicks()
##'     world <- ortho_world(click)
##'     message("Clicked at: ", paste(round(world, 1), collapse = ", "))
##'   })
##' }
##' }
ortho_clicks <- function(viewer_id, session = NULL) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }

  if (is.null(session)) {
    stop("ortho_clicks() must be called within a reactive context or with an explicit session")
  }

  input <- session$input
  input_name <- paste0(viewer_id, "_click")

  shiny::reactive({
    event <- input[[input_name]]
    if (is.null(event)) return(NULL)
    normalize_event(event)
  })
}


##' Create a reactive event stream for viewer double-clicks
##'
##' @inheritParams ortho_clicks
##' @return A reactive expression that returns an ortho_event object on double-click.
##' @export
##' @seealso \code{\link{ortho_clicks}} for usage examples
ortho_dblclicks <- function(viewer_id, session = NULL) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }
  if (is.null(session)) {
    stop("ortho_dblclicks() must be called within a reactive context or with an explicit session")
  }

  input <- session$input
  input_name <- paste0(viewer_id, "_dblclick")

  shiny::reactive({
    event <- input[[input_name]]
    if (is.null(event)) return(NULL)
    normalize_event(event)
  })
}


##' Create a reactive event stream for viewer hover events
##'
##' @inheritParams ortho_clicks
##' @return A reactive expression that returns an ortho_event object on hover.
##'   Note: hover events are throttled on the JavaScript side.
##' @export
##' @seealso \code{\link{ortho_clicks}} for usage examples
ortho_hovers <- function(viewer_id, session = NULL) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }

  if (is.null(session)) {
    stop("ortho_hovers() must be called within a reactive context or with an explicit session")
  }

  input <- session$input
  input_name <- paste0(viewer_id, "_hover")

  shiny::reactive({
    event <- input[[input_name]]
    if (is.null(event)) return(NULL)
    normalize_event(event)
  })
}


##' Create a reactive event stream for crosshair changes
##'
##' @inheritParams ortho_clicks
##' @return A reactive expression that returns an ortho_event object when
##'   the crosshair position changes.
##' @export
##' @seealso \code{\link{ortho_clicks}} for usage examples
ortho_crosshairs <- function(viewer_id, session = NULL) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }
  if (is.null(session)) {
    stop("ortho_crosshairs() must be called within a reactive context or with an explicit session")
  }

  input <- session$input
  input_name <- paste0(viewer_id, "_crosshair")

  shiny::reactive({
    event <- input[[input_name]]
    if (is.null(event)) return(NULL)
    normalize_event(event)
  })
}


##' Normalize a raw event from JavaScript into an ortho_event object
##'
##' @param event Raw event list from JavaScript.
##' @return An ortho_event object with normalized fields.
##' @keywords internal
normalize_event <- function(event) {
  if (is.null(event)) return(NULL)


  # Convert JavaScript arrays to R vectors
  if (!is.null(event$world) && is.list(event$world)) {
    event$world <- unlist(event$world)
  }

  if (!is.null(event$voxel) && is.list(event$voxel)) {
    event$voxel <- as.integer(unlist(event$voxel))
  }

  # Store original for power users

  event$raw <- event

  class(event) <- c("ortho_event", "list")
  event
}


# ---------------------------------------------------------------------------
# Convenience Wrappers
# ---------------------------------------------------------------------------

##' React to viewer click events
##'
##' A convenience wrapper around \code{observeEvent} that handles the Shiny
##' input naming and event normalization automatically. For more control,
##' use \code{\link{ortho_clicks}} directly.
##'
##' @param viewer_id Character: the outputId of the ortho_viewer widget.
##' @param handler A function that takes a single argument (the ortho_event
##'   object) and performs some action.
##' @param session The Shiny session object. If NULL, uses the current
##'   reactive domain.
##' @param ... Additional arguments passed to \code{observeEvent} (e.g.,
##'   \code{ignoreInit}, \code{once}, \code{priority}).
##' @return An observer reference (invisibly), as returned by \code{observeEvent}.
##'
##' @export
##' @examples
##' \dontrun{
##' server <- function(input, output, session) {
##'   output$viewer <- renderOrtho_viewer({ ortho_viewer(brain) })
##'
##'   # Simple click handler
##'   ortho_on_click("viewer", function(click) {
##'     world <- ortho_world(click)
##'     showNotification(paste("Clicked:", round(world[1], 1), round(world[2], 1), round(world[3], 1)))
##'   }, session)
##' }
##' }
ortho_on_click <- function(viewer_id, handler, session = NULL, ...) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }
  if (is.null(session)) {
    stop("ortho_on_click() must be called within a reactive context or with an explicit session")
  }

  clicks <- ortho_clicks(viewer_id, session)

  shiny::observeEvent(clicks(), {
    click <- clicks()
    if (!is.null(click)) {
      handler(click)
    }
  }, ...)
}


##' React to viewer double-click events
##'
##' @inheritParams ortho_on_click
##' @return An observer reference (invisibly).
##' @export
##' @seealso \code{\link{ortho_on_click}} for usage examples
ortho_on_dblclick <- function(viewer_id, handler, session = NULL, ...) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }
  if (is.null(session)) {
    stop("ortho_on_dblclick() must be called within a reactive context or with an explicit session")
  }

  dblclicks <- ortho_dblclicks(viewer_id, session)

  shiny::observeEvent(dblclicks(), {
    click <- dblclicks()
    if (!is.null(click)) {
      handler(click)
    }
  }, ...)
}


##' React to viewer hover events
##'
##' @inheritParams ortho_on_click
##' @return An observer reference (invisibly).
##' @export
##' @seealso \code{\link{ortho_on_click}} for usage examples
ortho_on_hover <- function(viewer_id, handler, session = NULL, ...) {
  if (is.null(session)) {
    session <- shiny::getDefaultReactiveDomain()
  }
  if (is.null(session)) {
    stop("ortho_on_hover() must be called within a reactive context or with an explicit session")
  }

  hovers <- ortho_hovers(viewer_id, session)

  shiny::observeEvent(hovers(), {
    hover <- hovers()
    if (!is.null(hover)) {
      handler(hover)
    }
  }, ...)
}
