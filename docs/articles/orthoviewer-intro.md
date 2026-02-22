# Introduction to orthoviewer

## Overview

orthoviewer provides an interactive 3D brain volume viewer for R. It
displays neuroimaging data in the standard orthogonal views (axial,
coronal, sagittal) with support for multiple overlay layers and
interactive navigation.

## Quick Start

The simplest way to view a brain volume:

``` r
library(orthoviewer)

# View a volume (array or neuroim2 NeuroVol)
view_ortho(brain_volume)

# View with a statistical overlay
view_ortho(brain_volume, overlay = stat_map)
```

That’s it! A browser window opens with the interactive viewer and a
status bar showing the current crosshair position and intensity.

## Loading Data

### From NIfTI files (recommended)

Use neuroim2 to load NIfTI files with proper spatial metadata:

``` r
library(neuroim2)

# Load brain and statistical map
brain <- read_vol("mni152_t1.nii.gz")
stat <- read_vol("zstat1.nii.gz")

# View them
view_ortho(brain, overlay = stat)
```

### From arrays

You can also use plain R arrays (though without spatial metadata):

``` r
# Create a simple test volume
brain <- array(rnorm(64^3), dim = c(64, 64, 64))
view_ortho(brain)
```

## Viewing Options

### Basic options

``` r
view_ortho(
  brain,
  overlay = stat_map,
  bg_colormap = "Greys",
  overlay_colormap = "hot",
  overlay_thresh = c(-3, 3),  # Values between -3 and 3 are transparent
  overlay_opacity = 0.8
)
```

### With control panel

Add `controls = TRUE` to get a sidebar with interactive controls:

``` r
view_ortho(brain, overlay = stat_map, controls = TRUE)
```

The control panel lets you:

- Navigate to specific coordinates
- Toggle overlay visibility
- Adjust opacity with sliders
- Change thresholds in real-time
- Switch colormaps

### Without status bar

``` r
view_ortho(brain, status_bar = FALSE)
```

### Multiple overlays

``` r
view_ortho(
  brain,
  overlay = list(activation = stat_map, roi = mask_vol),
  overlay_colormap = c("hot", "cool"),
  overlay_thresh = list(c(-3, 3), c(0.5, 0.5)),
  overlay_opacity = c(0.8, 0.5),
  controls = TRUE
)
```

### Available colormaps

- **Sequential**: “viridis”, “plasma”, “inferno”, “magma”, “Greys”
- **Diverging**: “RdBu”, “coolwarm”
- **Thermal**: “hot”, “cool”, “jet”

## Advanced: Building Shiny Apps

For full control, you can build custom Shiny apps using the widget
directly.

### Basic Shiny app

``` r
library(shiny)
library(orthoviewer)

ui <- fluidPage(
  ortho_viewerOutput("viewer", height = "600px")
)

server <- function(input, output, session) {
  output$viewer <- renderOrtho_viewer({
    ortho_viewer(brain, bg_colormap = "Greys")
  })

  # Add overlay via proxy
  observe({
    p <- ortho_proxy("viewer", session)
    p$add_layer(stat_map, id = "stats", thresh = c(-2, 2), colormap = "hot")
  })
}

shinyApp(ui, server)
```

### Controlling the viewer programmatically

The [`ortho_proxy()`](../reference/ortho_proxy.md) object lets you
control the viewer from R:

``` r
p <- ortho_proxy("viewer", session)

# Navigate to coordinates (with smooth animation)
p$set_crosshair(c(32, -20, 45), animate = TRUE)

# Adjust overlay appearance
p$set_threshold(c(-3, 3), layer_id = "stats")
p$set_colormap("viridis", layer_id = "stats")
p$set_opacity(0.5, layer_id = "stats")

# Toggle visibility
p$hide_layer("stats")
p$show_layer("stats")

# Reorder layers (first = bottom, last = top)
p$set_layer_order(c("background", "mask", "stats"))

# Remove a layer
p$remove_layer("stats")
```

### Handling click events

React to user interactions:

``` r
server <- function(input, output, session) {
  output$viewer <- renderOrtho_viewer({
    ortho_viewer(brain, bg_colormap = "Greys")
  })

  # React to clicks
  observeEvent(input$viewer_click, {
    click <- ortho_event(input, "viewer", "click")

    # Get coordinates
    world <- ortho_world(click)  # in mm
    voxel <- ortho_voxel(click)  # indices

    # Get intensity at clicked location
    intensity <- ortho_intensity(click)

    # Check which view was clicked
    view <- click$view  # "axial", "coronal", or "sagittal"

    # Check modifier keys
    if (ortho_modifier(click, "shift")) {
      message("Shift-click detected!")
    }
  })
}
```

### Available events

For a viewer with `outputId = "viewer"`:

| Input                     | Description                |
|---------------------------|----------------------------|
| `input$viewer_click`      | Single click               |
| `input$viewer_dblclick`   | Double click               |
| `input$viewer_rightclick` | Right click                |
| `input$viewer_hover`      | Mouse movement (throttled) |
| `input$viewer_crosshair`  | Crosshair position changes |

## Example Apps

orthoviewer includes built-in examples:

``` r
# Basic viewer demo
orthoviewer_example_app()

# Click event handling demo
orthoviewer_click_example()

# Navigation and layer controls demo
orthoviewer_navigation_example()
```

## Tips

1.  **Use layer IDs**: Always name your layers when adding them so you
    can reference them later.

2.  **Threshold appropriately**: For statistical maps, hide
    non-significant voxels with thresholds (e.g., `c(-2, 2)` for
    z-scores).

3.  **Reduce opacity**: When overlaying multiple maps, lower opacity
    helps see through layers.

4.  **Use animation sparingly**: Smooth transitions are nice for
    user-initiated navigation but can be distracting if triggered
    frequently.

## Session Info

``` r
sessionInfo()
#> R version 4.5.1 (2025-06-13)
#> Platform: aarch64-apple-darwin20
#> Running under: macOS Sonoma 14.3
#> 
#> Matrix products: default
#> BLAS:   /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libRblas.0.dylib 
#> LAPACK: /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libRlapack.dylib;  LAPACK version 3.12.1
#> 
#> locale:
#> [1] en_CA.UTF-8/en_CA.UTF-8/en_CA.UTF-8/C/en_CA.UTF-8/en_CA.UTF-8
#> 
#> time zone: America/Toronto
#> tzcode source: internal
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> loaded via a namespace (and not attached):
#>  [1] vctrs_0.6.5        cli_3.6.5          knitr_1.50         rlang_1.1.6       
#>  [5] xfun_0.54          generics_0.1.4     S7_0.2.1           textshaping_1.0.4 
#>  [9] jsonlite_2.0.0     glue_1.8.0         htmltools_0.5.8.1  albersdown_1.0.0  
#> [13] ragg_1.5.0         sass_0.4.10        scales_1.4.0       rmarkdown_2.30    
#> [17] grid_4.5.1         tibble_3.3.0       evaluate_1.0.5     jquerylib_0.1.4   
#> [21] fastmap_1.2.0      yaml_2.3.11        lifecycle_1.0.4    compiler_4.5.1    
#> [25] dplyr_1.1.4        RColorBrewer_1.1-3 fs_1.6.6           pkgconfig_2.0.3   
#> [29] htmlwidgets_1.6.4  farver_2.1.2       systemfonts_1.3.1  digest_0.6.39     
#> [33] R6_2.6.1           tidyselect_1.2.1   pillar_1.11.1      magrittr_2.0.4    
#> [37] bslib_0.9.0        tools_4.5.1        gtable_0.3.6       pkgdown_2.2.0     
#> [41] ggplot2_4.0.1      cachem_1.1.0       desc_1.4.3
```
