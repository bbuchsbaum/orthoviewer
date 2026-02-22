# NA

## OrthoViewer Progress

This document tracks the current status of the orthogonal viewer work
across: - `orthoviewer` (R package, current repo) -
`~/code/jscode/neuroimjs` (JS viewer) - `~/code/neuroim2` (R data
structures)

Use the checkboxes to mark tasks as completed.

------------------------------------------------------------------------

### 1. Core Wiring (`orthoviewer`)

Implement volume serialization helper(s) for passing R volumes to JS.

Add [`ortho_viewer()`](reference/ortho_viewer.md) widget constructor:

Accept background volume and colormap.

Embed serialized volume and options in widget payload.

Implement Shiny bindings:

[`ortho_viewerOutput()`](reference/ortho_viewerOutput.md) helper.

[`renderOrtho_viewer()`](reference/renderOrtho_viewer.md) helper.

Create JS htmlwidget binding at `inst/htmlwidgets/ortho_viewer.js`:

Build DOM shell (`.ortho-shell`, `.ortho-sidebar`,
`.ortho-viewer-container`).

Initialize `OrthogonalImageViewer` with background `ImageLayer`.

Wire `<layer-control-panel>` to the `ImageLayer`.

Implement Shiny message handler:

Register `ortho-viewer-command` handler.

Route commands to internal `applyCommand()` function.

------------------------------------------------------------------------

### 2. Proxy API (`orthoviewer`)

Implement `OrthoViewerProxy` R6 class:

Store output id and session.

`add_layer()` to add overlay volumes.

`set_window()` to adjust window range.

`set_threshold()` to adjust threshold range.

`set_colormap()` to change colormap.

`set_opacity()` to change layer opacity.

Implement [`ortho_proxy()`](reference/ortho_proxy.md) helper to
construct the proxy.

Test proxy with a simple Shiny app to confirm messages reach JS (see
[`orthoviewer_example_app()`](reference/orthoviewer_example_app.md)).

------------------------------------------------------------------------

### 3. JS Viewer Integration (**`~/code/jscode/neuroimjs`**)

> The following tasks involve updates to the external JS library at
> `~/code/jscode/neuroimjs`.

Confirm `OrthogonalImageViewer` supports `"left-tall"` layout:

Axial pane tall on left.

Coronal (top-right) and sagittal (bottom-right).

Ensure public API is suitable for htmlwidgets:

`OrthogonalImageViewer.create({ container, imageLayer, options })`.

`ImageLayer` and `VolStack` API for adding/updating layers.

Integrate `<layer-control-panel>`:

Expose `imageLayer` property.

Ensure panel discovers available layers and colormaps.

Ensure panel updates call existing `volLayer` / `imageLayer` methods.

Verify threshold semantics in `ColorMap.buildLookupTable()`:

Values `< low` or `> high` → opaque.

`low < value < high` → transparent.

------------------------------------------------------------------------

### 4. Theming and UX

Apply shell styling in `orthoviewer`:

CSS for `.ortho-widget-root`, `.ortho-shell`, `.ortho-sidebar`,
`.ortho-viewer-container`.

Ensure layout matches desired three‑pane design.

**\[neuroimjs\] Update `LayerControlPanelLit.ts` in
`~/code/jscode/neuroimjs`:**

Replace `static styles = css\`…\`\` with Albers‑inspired styles:

Warm paper gradient background.

System UI font stack and small uppercase labels.

Scoped Shoelace tokens for inputs (border, focus, primary color).

Optionally add `.threshold-caption` explaining threshold semantics.

Add optional viewer chrome:

Pane labels (e.g., axial/coronal/sagittal) as subtle overlays.

Slight frames around panes consistent with the sidebar aesthetic.

------------------------------------------------------------------------

### 5. `neuroim2` Integration (**`~/code/neuroim2`**)

> The following tasks involve updates to the external R library at
> `~/code/neuroim2`.

Implement or expose a helper to serialize `neuroim2` volumes for JS:

Return `list(dim, data, spacing, origin, axes)`.

Ensure that spatial metadata (`spacing`, `origin`, `axes`) align with
`neuroimjs` expectations.

Add small tests or examples showing `neuroim2` → `orthoviewer` →
`neuroimjs` flow.

------------------------------------------------------------------------

### 6. Examples, Docs, and Validation (`orthoviewer`)

Add a minimal Shiny example app:

Use a synthetic or example anatomy volume as background.

Add an overlay stat map via `p$add_layer()`.

Demonstrate window, threshold, colormap, and opacity adjustments.

Write a vignette:

Describe the orthogonal viewer and sidebar controls.

Explain threshold/window semantics clearly.

Show end‑to‑end usage with `neuroim2`.

Manual validation:

Confirm alignment and orientation across all three views.

Check interaction responsiveness with typical data sizes.

Verify visual styling meets the intended minimal Albers aesthetic.
