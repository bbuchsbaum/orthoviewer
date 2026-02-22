# Orthogonal neuroimaging viewer (htmlwidget shell)

This is a thin R wrapper around the JavaScript orthogonal viewer
implemented in `~/code/jscode/neuroimjs`. It is intended to be driven
primarily from Shiny via a proxy object; the HTML widget handles layout
and JS wiring.

## Usage

``` r
ortho_viewer(
  bg_volume,
  bg_colormap = "Greys",
  bg_range = NULL,
  width = "100%",
  height = 600,
  elementId = NULL,
  debug = FALSE
)
```

## Arguments

- bg_volume:

  A 3D volume object (e.g., from `neuroim2`) or a numeric array. For now
  this is treated as a raw array; integration helpers with `neuroim2`
  will be added separately.

- bg_colormap:

  Name of the colormap to use for the background volume (e.g.,
  `"Greys"`).

- bg_range:

  Optional numeric vector of length 2 specifying the intensity range for
  display windowing. If NULL (default), the volume's data range is used.

- width, height:

  Widget dimensions passed to `htmlwidgets`.

- elementId:

  Optional element id.

- debug:

  Logical: if TRUE, enable verbose console logging in the JavaScript
  viewer for debugging. Default FALSE.

## Value

An `htmlwidget` object that can be used in R Markdown documents or Shiny
applications.
