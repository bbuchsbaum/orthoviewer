# Format world coordinates in anatomical notation

Converts world coordinates to a human-readable string using anatomical
labels (L/R for left/right, A/P for anterior/posterior, S/I for
superior/inferior).

Utility function to format world coordinates with anatomical labels.

## Usage

``` r
format_world_coord(coord)

format_world_coord(coord)
```

## Arguments

- coord:

  Numeric vector of length 3: world coordinates (x, y, z).

- digits:

  Integer: number of decimal places.

## Value

Character string in format "L 23.5 \| P 12.3 \| S 45.0".

Character string with formatted coordinates.

## Examples

``` r
format_world_coord(c(-23.5, 12.3, 45.0))
#> [1] "\nR 23.5 | P 12.3 | S 45.0"
# Returns: "R 23.5 | P 12.3 | S 45.0"
```
