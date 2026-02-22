# Toggle the control panel

The control panel is a sidebar with interactive controls for adjusting
overlay threshold, opacity, colormap, and navigation.

## Usage

``` r
controls(builder, show = TRUE)
```

## Arguments

- builder:

  An `ortho_builder` object.

- show:

  Logical: whether to show the control panel. Default TRUE.

## Value

The modified `ortho_builder` object (for chaining).

## Examples

``` r
if (FALSE) { # \dontrun{
# Enable control panel
view_ortho(brain) |>
  layer(stat_map) |>
  controls()
} # }
```
