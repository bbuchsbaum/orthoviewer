# Proxy object for controlling an orthogonal viewer from Shiny

The proxy sends lightweight JSON messages from R to the browser, where
the JavaScript htmlwidget binding translates them into viewer operations
(adding layers, changing window/threshold/colormap, etc.).

An R6 class that provides methods for controlling an ortho_viewer widget
from Shiny server code. Created via `ortho_proxy()`.

## Usage

``` r
ortho_proxy(outputId, session = shiny::getDefaultReactiveDomain())
```

## Arguments

- outputId:

  The id of the `ortho_viewer` widget in the UI.

- session:

  The Shiny session; defaults to the current reactive domain.

## Value

An `OrthoViewerProxy` object with methods for controlling the viewer.
All methods return the proxy invisibly for chaining.

## Proxy Methods

- `add_layer(vol, id, thresh, range, colormap, opacity)`:

  Add a new overlay layer to the viewer.

- `set_window(range, layer_id)`:

  Set the display window (intensity range) for a layer.

- `set_threshold(thresh, layer_id)`:

  Set the threshold range for a layer.

- `set_colormap(colormap, layer_id)`:

  Set the colormap for a layer.

- `set_opacity(alpha, layer_id)`:

  Set the opacity for a layer.

- `set_crosshair(x, y, z, animate, duration)`:

  Set the crosshair position in world coordinates.

- `get_crosshair(request_id)`:

  Request the current crosshair position.

- `show_layer(layer_id)`:

  Make a layer visible.

- `hide_layer(layer_id)`:

  Hide a layer.

- `set_layer_visible(layer_id, visible)`:

  Set layer visibility explicitly.

- `set_layer_order(layer_ids)`:

  Reorder layers in the stack.

- `remove_layer(layer_id)`:

  Remove a layer from the viewer.

- `get_layers(request_id)`:

  Request a list of all layers.

## Crosshair Navigation

The `set_crosshair()` method allows programmatic navigation to any world
coordinate. Coordinates are in millimeters relative to the volume's
origin. The optional `animate` parameter enables smooth transitions.

The `get_crosshair()` method is asynchronous - it sends a request to the
browser and the result is returned via a Shiny input. Access the result
through `input$<outputId>_crosshair_response`.

## Layer Control

Layers are identified by their `layer_id` string, which is assigned when
adding a layer via `add_layer()`. The background layer always has the id
`"background"`.

Layer ordering determines which layers appear on top. Use
`set_layer_order()` with a character vector of layer IDs, where the
first element is at the bottom and the last is on top.

## Public fields

- `id`:

  The output ID of the viewer widget.

- `session`:

  The Shiny session object.

## Methods

### Public methods

- [`OrthoViewerProxy$new()`](#method-OrthoViewerProxy-new)

- [`OrthoViewerProxy$add_layer()`](#method-OrthoViewerProxy-add_layer)

- [`OrthoViewerProxy$set_window()`](#method-OrthoViewerProxy-set_window)

- [`OrthoViewerProxy$set_threshold()`](#method-OrthoViewerProxy-set_threshold)

- [`OrthoViewerProxy$set_colormap()`](#method-OrthoViewerProxy-set_colormap)

- [`OrthoViewerProxy$set_opacity()`](#method-OrthoViewerProxy-set_opacity)

- [`OrthoViewerProxy$set_crosshair()`](#method-OrthoViewerProxy-set_crosshair)

- [`OrthoViewerProxy$get_crosshair()`](#method-OrthoViewerProxy-get_crosshair)

- [`OrthoViewerProxy$show_layer()`](#method-OrthoViewerProxy-show_layer)

- [`OrthoViewerProxy$hide_layer()`](#method-OrthoViewerProxy-hide_layer)

- [`OrthoViewerProxy$set_layer_visible()`](#method-OrthoViewerProxy-set_layer_visible)

- [`OrthoViewerProxy$set_layer_order()`](#method-OrthoViewerProxy-set_layer_order)

- [`OrthoViewerProxy$remove_layer()`](#method-OrthoViewerProxy-remove_layer)

- [`OrthoViewerProxy$get_layers()`](#method-OrthoViewerProxy-get_layers)

- [`OrthoViewerProxy$clone()`](#method-OrthoViewerProxy-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new OrthoViewerProxy object.

#### Usage

    OrthoViewerProxy$new(id, session = shiny::getDefaultReactiveDomain())

#### Arguments

- `id`:

  The output ID of the ortho_viewer widget.

- `session`:

  The Shiny session object.

------------------------------------------------------------------------

### Method `add_layer()`

Add a new overlay layer to the viewer.

#### Usage

    OrthoViewerProxy$add_layer(
      vol,
      id = NULL,
      thresh = c(0, 0),
      range = NULL,
      colormap = "viridis",
      opacity = 1
    )

#### Arguments

- `vol`:

  Volume data - can be a 3D array or a neuroim2 NeuroVol object.

- `id`:

  Character string: unique identifier for this layer. If NULL, a
  timestamp-based ID is generated.

- `thresh`:

  Numeric vector of length 2: threshold range c(low, high). Voxels with
  values between low and high are made transparent. Use c(0, 0) for no
  thresholding.

- `range`:

  Numeric vector of length 2: display range c(min, max) for colormap
  scaling. If NULL, the volume's data range is used.

- `colormap`:

  Character string: name of the colormap to use. Options include
  "viridis", "hot", "cool", "Greys", "RdBu", etc.

- `opacity`:

  Numeric: layer opacity from 0 (transparent) to 1 (opaque).

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_window()`

Set the display window (intensity range) for a layer.

#### Usage

    OrthoViewerProxy$set_window(range, layer_id = NULL)

#### Arguments

- `range`:

  Numeric vector of length 2: c(min, max) intensity values that map to
  the colormap endpoints.

- `layer_id`:

  Character string: the layer to modify. If NULL, modifies the most
  recently added layer.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_threshold()`

Set the threshold range for a layer.

#### Usage

    OrthoViewerProxy$set_threshold(thresh, layer_id = NULL)

#### Arguments

- `thresh`:

  Numeric vector of length 2: c(low, high). Voxels with values between
  low and high are made transparent.

- `layer_id`:

  Character string: the layer to modify. If NULL, modifies the most
  recently added layer.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_colormap()`

Set the colormap for a layer.

#### Usage

    OrthoViewerProxy$set_colormap(colormap, layer_id = NULL)

#### Arguments

- `colormap`:

  Character string: name of the colormap.

- `layer_id`:

  Character string: the layer to modify. If NULL, modifies the most
  recently added layer.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_opacity()`

Set the opacity for a layer.

#### Usage

    OrthoViewerProxy$set_opacity(alpha, layer_id = NULL)

#### Arguments

- `alpha`:

  Numeric: opacity value from 0 (transparent) to 1 (opaque).

- `layer_id`:

  Character string: the layer to modify. If NULL, modifies the most
  recently added layer.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_crosshair()`

Set the crosshair position (navigate to coordinates).

#### Usage

    OrthoViewerProxy$set_crosshair(
      x,
      y = NULL,
      z = NULL,
      animate = FALSE,
      duration = 500
    )

#### Arguments

- `x`:

  Numeric: X coordinate in world/mm space. Can also be a numeric vector
  of length 3 containing c(x, y, z).

- `y`:

  Numeric: Y coordinate (ignored if x is a length-3 vector).

- `z`:

  Numeric: Z coordinate (ignored if x is a length-3 vector).

- `animate`:

  Logical: if TRUE, smoothly animate the transition.

- `duration`:

  Integer: animation duration in milliseconds (default 500).

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `get_crosshair()`

Request the current crosshair position.

This is an asynchronous operation. The result will be sent to
`input$<outputId>_crosshair_response` as a list containing:

- `world`: numeric vector c(x, y, z) in mm

- `voxel`: integer vector c(i, j, k) voxel indices

- `request_id`: the request_id if provided

- `timestamp`: JavaScript timestamp

#### Usage

    OrthoViewerProxy$get_crosshair(request_id = NULL)

#### Arguments

- `request_id`:

  Optional identifier to match request with response.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `show_layer()`

Make a layer visible.

#### Usage

    OrthoViewerProxy$show_layer(layer_id)

#### Arguments

- `layer_id`:

  Character string: the layer ID to show.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `hide_layer()`

Hide a layer (make invisible).

#### Usage

    OrthoViewerProxy$hide_layer(layer_id)

#### Arguments

- `layer_id`:

  Character string: the layer ID to hide.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_layer_visible()`

Set layer visibility.

#### Usage

    OrthoViewerProxy$set_layer_visible(layer_id, visible)

#### Arguments

- `layer_id`:

  Character string: the layer ID.

- `visible`:

  Logical: TRUE to show, FALSE to hide.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `set_layer_order()`

Reorder layers in the stack.

#### Usage

    OrthoViewerProxy$set_layer_order(layer_ids)

#### Arguments

- `layer_ids`:

  Character vector of layer IDs in the desired order. The first element
  will be at the bottom (rendered first), and the last element will be
  on top (rendered last). The background layer ID is typically
  "background".

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `remove_layer()`

Remove a layer from the viewer.

#### Usage

    OrthoViewerProxy$remove_layer(layer_id)

#### Arguments

- `layer_id`:

  Character string: the layer ID to remove.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `get_layers()`

Request a list of all layers.

This is an asynchronous operation. The result will be sent to
`input$<outputId>_layers_response` as a list containing:

- `layers`: list of layer info (id, visible, opacity, index)

- `request_id`: the request_id if provided

- `timestamp`: JavaScript timestamp

#### Usage

    OrthoViewerProxy$get_layers(request_id = NULL)

#### Arguments

- `request_id`:

  Optional identifier to match request with response.

#### Returns

The proxy object invisibly (for method chaining).

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    OrthoViewerProxy$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# In a Shiny server function:
server <- function(input, output, session) {
  output$viewer <- renderOrtho_viewer({
    ortho_viewer(brain_volume, bg_colormap = "Greys")
  })

  # Add an overlay layer
  observe({
    p <- ortho_proxy("viewer", session)
    p$add_layer(stat_map, id = "activation",
                thresh = c(-3, 3), colormap = "hot")
  })

  # Navigate to a coordinate when button is clicked
  observeEvent(input$go_to_peak, {
    p <- ortho_proxy("viewer", session)
    p$set_crosshair(c(32, -20, 45), animate = TRUE, duration = 500)
  })

  # Toggle layer visibility
  observeEvent(input$toggle_activation, {
    p <- ortho_proxy("viewer", session)
    if (input$show_activation) {
      p$show_layer("activation")
    } else {
      p$hide_layer("activation")
    }
  })
}
} # }
```
