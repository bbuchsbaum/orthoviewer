# Launch the viewer

Builds and runs the Shiny app from the builder specification.

## Usage

``` r
launch(builder, run = TRUE)
```

## Arguments

- builder:

  An `ortho_builder` object.

- run:

  Logical: if TRUE (default), launches the app immediately. If FALSE,
  returns the Shiny app object without launching.

## Value

If `run = TRUE`, returns the app invisibly after it closes. If
`run = FALSE`, returns the Shiny app object.

## Examples

``` r
if (FALSE) { # \dontrun{
# Launch immediately
view_ortho(brain) |> launch()

# Get app object without launching
app <- view_ortho(brain) |> launch(run = FALSE)
} # }
```
