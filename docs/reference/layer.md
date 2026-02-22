# Add an overlay layer to the viewer

Adds a volume as an overlay layer with its own colormap, threshold,
opacity, and display range settings.

## Usage

``` r
layer(
  builder,
  vol,
  colormap = "hot",
  thresh = c(-2, 2),
  range = NULL,
  opacity = 0.8,
  id = NULL
)
```

## Arguments

- builder:

  An `ortho_builder` object from [`view_ortho()`](view_ortho.md).

- vol:

  The overlay volume - a 3D array or neuroim2 NeuroVol object.

- colormap:

  Character: colormap for this layer (default "hot"). Options include
  "viridis", "plasma", "hot", "cool", "RdBu", etc.

- thresh:

  Numeric vector of length 2: threshold range. Values between thresh1
  and thresh2 are made transparent. Default c(-2, 2) works well for
  z-score maps.

- range:

  Numeric vector of length 2: display window range. If NULL, the
  volume's data range is used.

- opacity:

  Numeric: layer opacity from 0 (transparent) to 1 (opaque). Default
  0.8.

- id:

  Character: unique identifier for this layer. If NULL, an automatic id
  is generated.

## Value

The modified `ortho_builder` object (for chaining).

## Examples

``` r
if (FALSE) { # \dontrun{
view_ortho(brain) |>
  layer(stat_map, colormap = "hot", thresh = c(-3, 3)) |>
  layer(roi_mask, colormap = "cool", opacity = 0.5)
} # }
```
