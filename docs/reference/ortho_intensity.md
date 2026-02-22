# Get intensity values from an ortho_viewer event

Get intensity values from an ortho_viewer event

## Usage

``` r
ortho_intensity(event, layer_id = NULL)
```

## Arguments

- event:

  An ortho_event object or the raw input value.

- layer_id:

  Optional character: specific layer ID to retrieve. If NULL, returns
  all layer intensities as a named numeric vector.

## Value

If `layer_id` is specified, returns a single numeric value (or NA if not
found). Otherwise returns a named numeric vector of all layer
intensities.
