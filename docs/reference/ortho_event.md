# Get click event data from ortho_viewer

Convenience function to extract and validate click event data from a
Shiny input.

## Usage

``` r
ortho_event(input, viewer_id, event_type = "click")
```

## Arguments

- input:

  The Shiny input object.

- viewer_id:

  Character string: the outputId of the ortho_viewer widget.

- event_type:

  Character: type of event to retrieve. One of "click", "dblclick",
  "rightclick", "hover", or "crosshair".

## Value

A list containing the event data, or NULL if no event has occurred. The
list is enhanced with class "ortho_event" for pretty printing.

## Examples

``` r
if (FALSE) { # \dontrun{
# In a Shiny server function:
observeEvent(input$viewer_click, {
  click <- ortho_event(input, "viewer", "click")
  if (!is.null(click)) {
    message(sprintf("Clicked at world [%.1f, %.1f, %.1f]",
                    click$world[1], click$world[2], click$world[3]))
  }
})
} # }
```
