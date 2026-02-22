# Toggle the status bar

The status bar shows the current crosshair position (world and voxel
coordinates) and intensity values at that location.

## Usage

``` r
status_bar(builder, show = TRUE)
```

## Arguments

- builder:

  An `ortho_builder` object.

- show:

  Logical: whether to show the status bar. Default TRUE.

## Value

The modified `ortho_builder` object (for chaining).

## Examples

``` r
if (FALSE) { # \dontrun{
# Enable status bar (default is already TRUE)
view_ortho(brain) |> status_bar()

# Disable status bar
view_ortho(brain) |> status_bar(FALSE)
} # }
```
