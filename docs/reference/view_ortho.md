# Create an orthogonal brain viewer

This is the main entry point for viewing neuroimaging data. It returns a
builder object that can be customized with additional layers and options
using a fluent (pipe-friendly) API.

## Usage

``` r
view_ortho(vol, colormap = "Greys", range = NULL)
```

## Arguments

- vol:

  The background volume - a 3D array or neuroim2 NeuroVol object.

- colormap:

  Character: colormap for the background (default "Greys").

- range:

  Numeric vector of length 2: display window range. If NULL, the
  volume's data range is used.

## Value

An `ortho_builder` object that can be piped to [`layer()`](layer.md),
[`status_bar()`](status_bar.md), [`controls()`](controls.md), and
[`launch()`](launch.md).

## Details

The builder pattern allows composing viewers declaratively:

    view_ortho(brain) |>
      layer(stat_map, colormap = "hot", thresh = c(-2, 2)) |>
      layer(roi_mask, colormap = "cool", opacity = 0.5) |>
      controls() |>
      launch()

In interactive sessions, the viewer launches automatically when printed.
Use `launch = FALSE` in [`launch()`](launch.md) to get the Shiny app
object without running it.

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple view
view_ortho(brain)

# With overlay
view_ortho(brain) |>
  layer(stat_map, thresh = c(-3, 3))

# Full featured
view_ortho(brain) |>
  layer(activation, colormap = "hot", thresh = c(-2, 2)) |>
  layer(roi, colormap = "cool", opacity = 0.5) |>
  controls() |>
  launch()
} # }
```
