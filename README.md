# orthoviewer

Interactive orthogonal brain viewer for neuroimaging data in R.

orthoviewer displays neuroimaging volumes in the standard three-plane view (axial, coronal, sagittal) with support for multiple overlay layers, interactive navigation, and real-time threshold/colormap adjustments.

## Installation

### Prerequisites

orthoviewer depends on [neuroim2](https://github.com/bbuchsbaum/neuroim2) for neuroimaging data structures. Install it first:

```r
# install.packages("remotes")
remotes::install_github("bbuchsbaum/neuroim2")
```

### Install orthoviewer

```r
remotes::install_github("bbuchsbaum/orthoviewer")
```

## Quick Start

```r
library(orthoviewer)
library(neuroim2)

# Folder-based launcher (scan + metadata + load UI)
orthoviewer()

# Load a brain volume
brain <- read_vol("mni152_t1.nii.gz")

# View it
view_ortho(brain)
```

A browser window opens with the interactive viewer.

## Adding Overlays

```r
# Load statistical map
stat_map <- read_vol("zstat1.nii.gz")

# View with overlay (values between -2 and 2 are transparent)
view_ortho(brain) |>
  layer(stat_map, colormap = "hot", thresh = c(-2, 2)) |>
  controls()  # Add sidebar controls
```

## Features

- Three-plane orthogonal viewer with synchronized crosshairs
- Multiple overlay layers with independent colormaps and thresholds
- Interactive controls for opacity, thresholds, and colormap selection
- Click/hover event handling for custom Shiny applications
- Fluent pipe-friendly API
- Works with neuroim2 volumes or plain R arrays

## Example Apps

```r
# Basic viewer demo
orthoviewer_example_app()

# Click event handling demo
orthoviewer_click_example()
```

## Documentation

See the package vignette for detailed usage:

```r
vignette("orthoviewer-intro", package = "orthoviewer")
```

## License

MIT
