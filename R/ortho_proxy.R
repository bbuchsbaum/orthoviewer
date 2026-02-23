##' Proxy object for controlling an orthogonal viewer from Shiny
##'
##' The proxy sends lightweight JSON messages from R to the browser,
##' where the JavaScript htmlwidget binding translates them into viewer
##' operations (adding layers, changing window/threshold/colormap, etc.).
##'
##' @param outputId The id of the \code{ortho_viewer} widget in the UI.
##' @param session The Shiny session; defaults to the current reactive domain.
##' @importFrom R6 R6Class
##'
##' @return An \code{OrthoViewerProxy} object with methods for controlling
##'   the viewer. All methods return the proxy invisibly for chaining.
##'
##' @section Proxy Methods:
##' \describe{
##'   \item{\code{add_layer(vol, id, thresh, range, colormap, opacity)}}{
##'     Add a new overlay layer to the viewer.
##'   }
##'   \item{\code{set_window(range, layer_id)}}{
##'     Set the display window (intensity range) for a layer.
##'   }
##'   \item{\code{set_threshold(thresh, layer_id)}}{
##'     Set the threshold range for a layer.
##'   }
##'   \item{\code{set_colormap(colormap, layer_id)}}{
##'     Set the colormap for a layer.
##'   }
##'   \item{\code{set_opacity(alpha, layer_id)}}{
##'     Set the opacity for a layer.
##'   }
##'   \item{\code{set_crosshair(x, y, z, animate, duration)}}{
##'     Set the crosshair position in world coordinates.
##'   }
##'   \item{\code{get_crosshair(request_id)}}{
##'     Request the current crosshair position.
##'   }
##'   \item{\code{show_layer(layer_id)}}{
##'     Make a layer visible.
##'   }
##'   \item{\code{hide_layer(layer_id)}}{
##'     Hide a layer.
##'   }
##'   \item{\code{set_layer_visible(layer_id, visible)}}{
##'     Set layer visibility explicitly.
##'   }
##'   \item{\code{set_layer_order(layer_ids)}}{
##'     Reorder layers in the stack.
##'   }
##'   \item{\code{remove_layer(layer_id)}}{
##'     Remove a layer from the viewer.
##'   }
##'   \item{\code{get_layers(request_id)}}{
##'     Request a list of all layers.
##'   }
##' }
##'
##' @section Crosshair Navigation:
##' The \code{set_crosshair()} method allows programmatic navigation to any
##' world coordinate. Coordinates are in millimeters relative to the volume's
##' origin. The optional \code{animate} parameter enables smooth transitions.
##'
##' The \code{get_crosshair()} method is asynchronous - it sends a request to
##' the browser and the result is returned via a Shiny input. Access the
##' result through \code{input$<outputId>_crosshair_response}.
##'
##' @section Layer Control:
##' Layers are identified by their \code{layer_id} string, which is assigned
##' when adding a layer via \code{add_layer()}. The background layer always
##' has the id \code{"background"}.
##'
##' Layer ordering determines which layers appear on top. Use
##' \code{set_layer_order()} with a character vector of layer IDs, where
##' the first element is at the bottom and the last is on top.
##'
##' @export
##' @examples
##' \dontrun{
##' # In a Shiny server function:
##' server <- function(input, output, session) {
##'   output$viewer <- renderOrtho_viewer({
##'     ortho_viewer(brain_volume, bg_colormap = "Greys")
##'   })
##'
##'   # Add an overlay layer
##'   observe({
##'     p <- ortho_proxy("viewer", session)
##'     p$add_layer(stat_map, id = "activation",
##'                 thresh = c(-3, 3), colormap = "hot")
##'   })
##'
##'   # Navigate to a coordinate when button is clicked
##'   observeEvent(input$go_to_peak, {
##'     p <- ortho_proxy("viewer", session)
##'     p$set_crosshair(c(32, -20, 45), animate = TRUE, duration = 500)
##'   })
##'
##'   # Toggle layer visibility
##'   observeEvent(input$toggle_activation, {
##'     p <- ortho_proxy("viewer", session)
##'     if (input$show_activation) {
##'       p$show_layer("activation")
##'     } else {
##'       p$hide_layer("activation")
##'     }
##'   })
##' }
##' }
ortho_proxy <- function(outputId,
                        session = shiny::getDefaultReactiveDomain()) {
  OrthoViewerProxy$new(outputId, session)
}


##' @rdname ortho_proxy
##' @name OrthoViewerProxy
##' @title OrthoViewerProxy R6 Class
##' @description
##' An R6 class that provides methods for controlling an ortho_viewer widget
##' from Shiny server code. Created via \code{\link{ortho_proxy}()}.
OrthoViewerProxy <- R6::R6Class(
  "OrthoViewerProxy",
  public = list(
    #' @field id The output ID of the viewer widget.
    id = NULL,

    #' @field session The Shiny session object.
    session = NULL,

    #' @description Create a new OrthoViewerProxy object.
    #' @param id The output ID of the ortho_viewer widget.
    #' @param session The Shiny session object.
    initialize = function(id,
                          session = shiny::getDefaultReactiveDomain()) {
      self$id <- id
      self$session <- session
    },

    #' @description Add a new overlay layer to the viewer.
    #' @param vol Volume data - can be a 3D array or a neuroim2 NeuroVol object.
    #' @param id Character string: unique identifier for this layer. If NULL,
    #'   a timestamp-based ID is generated.
    #' @param thresh Numeric vector of length 2: threshold range c(low, high).
    #'   Voxels with values between low and high are made transparent.
    #'   Use c(0, 0) for no thresholding.
    #' @param range Numeric vector of length 2: display range c(min, max) for
    #'   colormap scaling. If NULL, the volume's data range is used.
    #' @param colormap Character string: name of the colormap to use.
    #'   Options include "viridis", "hot", "cool", "Greys", "RdBu", etc.
    #' @param opacity Numeric: layer opacity from 0 (transparent) to 1 (opaque).
    #' @return The proxy object invisibly (for method chaining).
    add_layer = function(vol,
                         id       = NULL,
                         thresh   = c(0, 0),
                         range    = NULL,
                         colormap = "viridis",
                         opacity  = 1) {
      msg <- list(
        id        = self$id,
        type      = "add-layer",
        volume    = serialize_volume_for_js(vol),
        threshold = as.numeric(thresh),
        range     = if (!is.null(range)) as.numeric(range) else NULL,
        colormap  = colormap,
        opacity   = opacity,
        layer_id  = id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set the display window (intensity range) for a layer.
    #' @param range Numeric vector of length 2: c(min, max) intensity values
    #'   that map to the colormap endpoints.
    #' @param layer_id Character string: the layer to modify. If NULL,
    #'   modifies the most recently added layer.
    #' @return The proxy object invisibly (for method chaining).
    set_window = function(range,
                          layer_id = NULL) {
      msg <- list(
        id       = self$id,
        type     = "set-window",
        range    = as.numeric(range),
        layer_id = layer_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set the threshold range for a layer.
    #' @param thresh Numeric vector of length 2: c(low, high). Voxels with
    #'   values between low and high are made transparent.
    #' @param layer_id Character string: the layer to modify. If NULL,
    #'   modifies the most recently added layer.
    #' @return The proxy object invisibly (for method chaining).
    set_threshold = function(thresh,
                             layer_id = NULL) {
      msg <- list(
        id        = self$id,
        type      = "set-threshold",
        threshold = as.numeric(thresh),
        layer_id  = layer_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set the colormap for a layer.
    #' @param colormap Character string: name of the colormap.
    #' @param layer_id Character string: the layer to modify. If NULL,
    #'   modifies the most recently added layer.
    #' @return The proxy object invisibly (for method chaining).
    set_colormap = function(colormap,
                            layer_id = NULL) {
      msg <- list(
        id       = self$id,
        type     = "set-colormap",
        colormap = colormap,
        layer_id = layer_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set the opacity for a layer.
    #' @param alpha Numeric: opacity value from 0 (transparent) to 1 (opaque).
    #' @param layer_id Character string: the layer to modify. If NULL,
    #'   modifies the most recently added layer.
    #' @return The proxy object invisibly (for method chaining).
    set_opacity = function(alpha,
                           layer_id = NULL) {
      msg <- list(
        id       = self$id,
        type     = "set-opacity",
        opacity  = alpha,
        layer_id = layer_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set the crosshair position (navigate to coordinates).
    #' @param x Numeric: X coordinate in world/mm space. Can also be a numeric
    #'   vector of length 3 containing c(x, y, z).
    #' @param y Numeric: Y coordinate (ignored if x is a length-3 vector).
    #' @param z Numeric: Z coordinate (ignored if x is a length-3 vector).
    #' @param animate Logical: if TRUE, smoothly animate the transition.
    #' @param duration Integer: animation duration in milliseconds (default 500).
    #' @return The proxy object invisibly (for method chaining).
    set_crosshair = function(x, y = NULL, z = NULL,
                             animate = FALSE,
                             duration = 500) {
      # Accept either (x, y, z) or a single vector
      if (is.null(y) && is.null(z) && length(x) == 3) {
        coord <- as.numeric(x)
      } else {
        coord <- as.numeric(c(x, y, z))
      }

      msg <- list(
        id       = self$id,
        type     = "set-crosshair",
        coord    = coord,
        animate  = animate,
        duration = as.integer(duration)
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Request the current crosshair position.
    #'
    #' This is an asynchronous operation. The result will be sent to
    #' \code{input$<outputId>_crosshair_response} as a list containing:
    #' \itemize{
    #'   \item \code{world}: numeric vector c(x, y, z) in mm
    #'   \item \code{voxel}: integer vector c(i, j, k) voxel indices
    #'   \item \code{request_id}: the request_id if provided
    #'   \item \code{timestamp}: JavaScript timestamp
    #' }
    #' @param request_id Optional identifier to match request with response.
    #' @return The proxy object invisibly (for method chaining).
    get_crosshair = function(request_id = NULL) {
      msg <- list(
        id         = self$id,
        type       = "get-crosshair",
        request_id = request_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Make a layer visible.
    #' @param layer_id Character string: the layer ID to show.
    #' @return The proxy object invisibly (for method chaining).
    show_layer = function(layer_id) {
      msg <- list(
        id       = self$id,
        type     = "set-layer-visible",
        layer_id = layer_id,
        visible  = TRUE
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Hide a layer (make invisible).
    #' @param layer_id Character string: the layer ID to hide.
    #' @return The proxy object invisibly (for method chaining).
    hide_layer = function(layer_id) {
      msg <- list(
        id       = self$id,
        type     = "set-layer-visible",
        layer_id = layer_id,
        visible  = FALSE
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set layer visibility.
    #' @param layer_id Character string: the layer ID.
    #' @param visible Logical: TRUE to show, FALSE to hide.
    #' @return The proxy object invisibly (for method chaining).
    set_layer_visible = function(layer_id, visible) {
      msg <- list(
        id       = self$id,
        type     = "set-layer-visible",
        layer_id = layer_id,
        visible  = visible
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Reorder layers in the stack.
    #' @param layer_ids Character vector of layer IDs in the desired order.
    #'   The first element will be at the bottom (rendered first), and the

    #'   last element will be on top (rendered last). The background layer
    #'   ID is typically "background".
    #' @return The proxy object invisibly (for method chaining).
    set_layer_order = function(layer_ids) {
      msg <- list(
        id        = self$id,
        type      = "set-layer-order",
        layer_ids = as.list(layer_ids)
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Remove a layer from the viewer.
    #' @param layer_id Character string: the layer ID to remove.
    #' @return The proxy object invisibly (for method chaining).
    remove_layer = function(layer_id) {
      msg <- list(
        id       = self$id,
        type     = "remove-layer",
        layer_id = layer_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Request a list of all layers.
    #'
    #' This is an asynchronous operation. The result will be sent to
    #' \code{input$<outputId>_layers_response} as a list containing:
    #' \itemize{
    #'   \item \code{layers}: list of layer info (id, visible, opacity, index)
    #'   \item \code{request_id}: the request_id if provided
    #'   \item \code{timestamp}: JavaScript timestamp
    #' }
    #' @param request_id Optional identifier to match request with response.
    #' @return The proxy object invisibly (for method chaining).
    get_layers = function(request_id = NULL) {
      msg <- list(
        id         = self$id,
        type       = "get-layers",
        request_id = request_id
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Switch view mode between slices and surface.
    #' @param mode Character: \code{"slices"} or \code{"surface"}.
    #' @return The proxy object invisibly (for method chaining).
    set_mode = function(mode = c("slices", "surface")) {
      mode <- match.arg(mode)
      msg <- list(
        id   = self$id,
        type = "set-mode",
        mode = mode
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set pre-mapped surface data for the surface viewer.
    #'
    #' The surface object should be a \code{neurosurf} surface
    #' (\code{SurfaceGeometry}, \code{NeuroSurface}, or
    #' \code{ColorMappedNeuroSurface}). This also switches to surface mode.
    #' @param surf A surface object from \code{neurosurf}.
    #' @param colormap Character: colormap name.
    #' @param range Optional numeric vector of length 2 for intensity range.
    #' @param threshold Numeric vector of length 2 for transparency threshold.
    #' @param opacity Numeric: surface opacity (0-1).
    #' @return The proxy object invisibly (for method chaining).
    set_surface = function(surf,
                           colormap = "viridis",
                           range = NULL,
                           threshold = c(0, 0),
                           opacity = 1) {
      surface_data <- serialize_surface_for_js(
        surf,
        colormap = colormap,
        range = range,
        threshold = threshold,
        opacity = opacity
      )
      msg <- list(
        id           = self$id,
        type         = "set-surface",
        surface_data = surface_data
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Set volume for GPU-based surface projection.
    #'
    #' Pass a surface geometry and volume; the JS side uses
    #' \code{VolumeProjectedSurface} for on-GPU mapping.
    #' @param surf A \code{SurfaceGeometry} from \code{neurosurf}.
    #' @param vol A 3D volume for projection.
    #' @param colormap Character: colormap name.
    #' @param range Optional numeric vector of length 2 for intensity range.
    #' @param threshold Numeric vector of length 2 for transparency threshold.
    #' @param opacity Numeric: surface opacity (0-1).
    #' @return The proxy object invisibly (for method chaining).
    set_surface_volume = function(surf,
                                  vol,
                                  colormap = "viridis",
                                  range = NULL,
                                  threshold = c(0, 0),
                                  opacity = 1) {
      surface_data <- serialize_surface_for_js(
        surf,
        vol = vol,
        colormap = colormap,
        range = range,
        threshold = threshold,
        opacity = opacity
      )
      msg <- list(
        id           = self$id,
        type         = "set-surface-volume",
        surface_data = surface_data
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Change the surface colormap.
    #' @param colormap Character: colormap name (e.g., \code{"hot"}, \code{"viridis"}).
    #' @return The proxy object invisibly (for method chaining).
    set_surface_colormap = function(colormap) {
      msg <- list(
        id       = self$id,
        type     = "set-surface-colormap",
        colormap = colormap
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Change the surface threshold.
    #' @param threshold Numeric vector of length 2.
    #' @return The proxy object invisibly (for method chaining).
    set_surface_threshold = function(threshold) {
      msg <- list(
        id        = self$id,
        type      = "set-surface-threshold",
        threshold = as.numeric(threshold)
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    },

    #' @description Change the surface opacity.
    #' @param opacity Numeric: opacity value from 0 to 1.
    #' @return The proxy object invisibly (for method chaining).
    set_surface_opacity = function(opacity) {
      msg <- list(
        id      = self$id,
        type    = "set-surface-opacity",
        opacity = opacity
      )
      self$session$sendCustomMessage("ortho-viewer-command", msg)
      invisible(self)
    }
  )
)
