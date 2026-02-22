# NA

## Architecture Overview

This document describes how the orthogonal viewer is split across three
codebases:

- `orthoviewer` (this repo, R package)
- `~/code/jscode/neuroimjs` (JavaScript viewer and controls)
- `~/code/neuroim2` (R neuroim data structures)

The design goal is: - A JavaScript-native, responsive orthogonal viewer
(three panes + sidebar). - A minimal, expressive R API to drive it from
R and Shiny. - A shared understanding of volumes and layers between R
and JS.

------------------------------------------------------------------------

### Components and Responsibilities

#### 1. `orthoviewer` (R package, current repo)

**Purpose** - Provide the R/HTMLWidgets/Shiny interface to the JS
orthogonal viewer. - Serialize R volume objects (from `neuroim2`) into a
format consumable by `neuroimjs`. - Expose a simple, chainable R API for
adding layers and adjusting visual parameters.

**Key pieces** - **Widget constructor** -
`ortho_viewer(bg_volume, bg_colormap = "greys", ...)` - Accepts a 3D
background volume (likely from `neuroim2`). - Serializes it into a
JSON‑friendly spec: - `dim`, `data`, `spacing`, `origin`, `axes`. -
Passes this to the JS htmlwidget binding. - **Shiny bindings** -
`ortho_viewerOutput(id, width, height)` -
`renderOrtho_viewer(expr, ...)` - Standard htmlwidgets output/render
functions. - **Proxy API** - `ortho_proxy(outputId, session)` → R6
`OrthoViewerProxy` with methods: -
`add_layer(vol, id = NULL, thresh, range, colormap, opacity)` -
`set_window(range, layer_id = NULL)` -
`set_threshold(thresh, layer_id = NULL)` -
`set_colormap(colormap, layer_id = NULL)` -
`set_opacity(alpha, layer_id = NULL)` - Each method packages its
arguments as a JSON message and calls: -
`session$sendCustomMessage("ortho-viewer-command", msg)`. - **Volume
serialization helpers** - Functions to convert `neuroim2` volumes or
arrays into a JS‑friendly payload: - Dimensions and voxel values. -
Optional spacing, origin, orientation axes.

**Files (expected)** - `R/ortho_viewer.R` – widget constructor and Shiny
bindings. - `R/ortho_proxy.R` – R6 proxy class and helper. -
`inst/htmlwidgets/ortho_viewer.js` – JS binding and DOM integration. -
`inst/htmlwidgets/ortho_viewer.css` – optional shell styling.

------------------------------------------------------------------------

#### 2. `~/code/jscode/neuroimjs` (JavaScript core viewer)

> NOTE: Changes in this section occur in the external JS library and
> should be recorded as updates to **`~/code/jscode/neuroimjs`**.

**Purpose** - Implement the actual rendering and interaction: - 3‑pane
orthogonal image viewer. - Layer management and blending. -
Thresholding, windowing, and colormaps. - Sidebar control panel
(`<layer-control-panel>`).

**Key classes / components** - **Core volume types** - `NeuroSpace`,
`DenseNeuroVol` (and related types). - Define dimensionality, voxel
data, spacing, origin, and axes. - **Layering** - `VolLayer` – wraps a
single volume with visual properties: - Range/window (`[min, max]`),
threshold (`[low, high]`), opacity, colormap. - `VolStack` – collection
of `VolLayer`s. - `ImageLayer` – façade over `VolStack` for viewer
consumption, including: - `addLayer()`, `getLayerIds()`,
`updateLayer()`, etc. - **Viewer** - `OrthogonalImageViewer` - Renders
axial, coronal, and sagittal slices in a grid. - Supports a
`"left-tall"` layout: - Axial on the left spanning vertical. - Coronal
(top-right) and sagittal (bottom-right). - Takes
`{ container, imageLayer, options }` during `create()`. - **Colormaps &
thresholds** - `ColorMap` with `buildLookupTable()`: - Uses threshold
interval semantics: - Values `< low` or `> high` → opaque. -
`low < value < high` → transparent (alpha = 0). - Supports multiple
presets (viridis, magma, inferno, cividis, greys, etc.). - **Control
panel** - `LayerControlPanelLit.ts` → `<layer-control-panel>`
(LitElement): - Active layer selection. - Colormap dropdown. - Window
range control (range slider). - Threshold low/high controls. -
Alpha/opacity slider. - Hooks into `imageLayer` and `volLayer` API (no R
involvement).

**Htmlwidget integration expectations** - The htmlwidget factory in
`orthoviewer` will: - Create a DOM shell: - Sidebar with
`<layer-control-panel>`. - Viewer container for
`OrthogonalImageViewer`. - Construct volumes and layers from R‑provided
specs: - Background volume → `VolLayer`. - Overlay layers added via
commands (`add-layer`). - Create `ImageLayer`/`VolStack` and
`OrthogonalImageViewer`. - Inject `imageLayer` into
`<layer-control-panel>`: - `panel.imageLayer = imageLayer;` -
`panel.requestUpdate();`

------------------------------------------------------------------------

#### 3. `~/code/neuroim2` (R data structures)

> NOTE: Changes in this section occur in the external R library and
> should be recorded as updates to **`~/code/neuroim2`**.

**Purpose** - Provide R‑side neuroimaging data structures: - Volumes,
spaces, and metadata needed to represent 3D images. - Serve as the
canonical source for volumes passed into `orthoviewer`.

**Responsibilities** - Define S3/S4/R6 types for volumes and images,
including: - Dimensions. - Numeric voxel data. - Spacing and origin. -
Axes/orientation metadata. - Provide conversion helpers used by
`orthoviewer`: - Functions that take `neuroim2` objects and return plain
lists ready for JSON encoding: - e.g., `to_js_volume(x)` → list with
`dim`, `data`, `spacing`, `origin`, `axes`.

**Interaction with `orthoviewer`** - Typical flow: 1. User constructs or
loads a volume in R via `neuroim2`. 2. User calls `ortho_viewer(bg)` or
`p$add_layer(vol, ...)`. 3. `orthoviewer` calls a serialization helper
(possibly defined in `neuroim2` or locally). 4. Serialized volume is
embedded in the widget payload and passed to `neuroimjs`.

------------------------------------------------------------------------

### Data Flow Overview

1.  **R → JS (initialization)**
    - R user calls `ortho_viewer(bg_volume, ...)` in `orthoviewer`.
    - `bg_volume` (likely a `neuroim2` object) is serialized into a
      plain list with:
      - `dim`, `data`, `spacing`, `origin`, `axes`.
    - htmlwidget sends this payload to the browser.
    - JS factory (`ortho_viewer.js`) constructs:
      - `DenseNeuroVol` from `data` and `NeuroSpace`.
      - Background `VolLayer`, `VolStack`, `ImageLayer`.
      - `OrthogonalImageViewer` bound to the DOM.
2.  **R → JS (runtime commands)**
    - In Shiny, R code obtains a proxy:
      - `p <- ortho_proxy("brain_viewer", session)`.
    - R sends commands like:
      - `p$add_layer(stat, thresh = c(-2, 2), colormap = "viridis")`.
      - `p$set_window(c(0, 120))`, `p$set_threshold(c(-3, 3))`.
    - Each command is translated into a message with type:
      - `"add-layer"`, `"set-window"`, `"set-threshold"`,
        `"set-colormap"`, `"set-opacity"`.
    - JS handler receives `ortho-viewer-command` and:
      - Builds new `VolLayer`s as needed.
      - Updates existing layers via `ImageLayer` and `VolLayer` methods.
3.  **JS-only interaction**
    - `<layer-control-panel>` directly manipulates the same
      `imageLayer`:
      - Selecting active layer.
      - Tweaking window and threshold sliders.
      - Changing colormaps and opacity.
    - No round‑trip to R is needed for smooth UI.
4.  **Rendering**
    - `OrthogonalImageViewer` uses `ImageLayer` as the source of truth:
      - Reads current slices, range, threshold, opacity, colormap.
      - Renders axial, coronal, and sagittal views in the specified
        layout.

------------------------------------------------------------------------

### Visual Design Principles

- Flat planes and warm, paper‑like backgrounds.
- Ochre and deep teal as primary accents.
- Small, uppercase labels with generous letter‑spacing.
- Thin separations between panes; minimal visible borders.
- JS control panel and three‑pane viewer feel like one cohesive
  composition.
