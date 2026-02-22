# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Project Overview

`orthoviewer` is an R package that provides an interactive orthogonal
brain viewer for neuroimaging data. It wraps a JavaScript viewer
(`neuroimjs`) as an HTMLWidget for use in R Markdown and Shiny
applications.

**This is a multi-repository project spanning three codebases:** -
`orthoviewer` (this repo) - R package with HTMLWidgets and Shiny
bindings - `~/code/jscode/neuroimjs` - JavaScript viewer core
(OrthogonalImageViewer, LayerControlPanel, colormaps) -
`~/code/neuroim2` - R neuroimaging data structures (volumes, spaces,
metadata)

## Build Commands

``` bash
# Install dependencies and build
R CMD INSTALL .

# Check package (includes tests)
R CMD check .

# Generate documentation (roxygen2)
Rscript -e "devtools::document()"

# Run tests
Rscript -e "devtools::test()"

# Load package for interactive development
Rscript -e "devtools::load_all()"
```

## Architecture

### R Package Structure

- `R/ortho_viewer.R` - Widget constructor
  ([`ortho_viewer()`](reference/ortho_viewer.md)), Shiny bindings,
  volume serialization
- `R/ortho_proxy.R` - R6 `OrthoViewerProxy` class for runtime Shiny
  commands
- `inst/htmlwidgets/ortho_viewer.js` - JS binding that creates DOM shell
  and initializes neuroimjs

### Data Flow

1.  **R → JS (initialization)**: `ortho_viewer(bg_volume)` serializes
    volume to `{dim, data, spacing, origin, axes}` and passes to the JS
    widget
2.  **R → JS (runtime)**: Proxy methods (`add_layer`, `set_window`,
    `set_threshold`, etc.) send JSON messages via
    `session$sendCustomMessage("ortho-viewer-command", msg)`
3.  **JS-only interaction**: The `<layer-control-panel>` web component
    directly manipulates the `ImageLayer` without R round-trips

### Key neuroimjs Dependencies

The JS widget expects these globally available from neuroimjs: -
`neuroimjs.NeuroSpace` / `neuroimjs.DenseNeuroVol` - Volume types -
`neuroimjs.VolLayer` / `neuroimjs.VolStack` / `neuroimjs.ImageLayer` -
Layer management - `neuroimjs.OrthogonalImageViewer` - Three-pane viewer
with “left-tall” layout - `neuroimjs.ColorMap.fromPreset()` - Colormap
presets (viridis, greys, etc.)

### Threshold Semantics

The viewer uses inverted threshold logic: values `< low` or `> high` are
**opaque**; values between `low` and `high` are **transparent** (alpha =
0).

### Proxy API Methods

``` r
p <- ortho_proxy("viewer_id", session)
p$add_layer(vol, id = NULL, thresh = c(0, 0), range = NULL, colormap = "viridis", opacity = 1)
p$set_window(range, layer_id = NULL)
p$set_threshold(thresh, layer_id = NULL)
p$set_colormap(colormap, layer_id = NULL)
p$set_opacity(alpha, layer_id = NULL)
```

## Cross-Repository Development

When making changes that span repositories: 1. Changes to JS viewer
behavior → update `~/code/jscode/neuroimjs` 2. Changes to R volume
structures → update `~/code/neuroim2` 3. Changes to R↔︎JS interface →
coordinate across all three repos

The `Architecture.md`, `Progress.md`, and `Plan.md` files track
cross-repo coordination.
