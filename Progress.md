## OrthoViewer Progress

This document tracks the current status of the orthogonal viewer work across:
- `orthoviewer` (R package, current repo)
- `~/code/jscode/neuroimjs` (JS viewer)
- `~/code/neuroim2` (R data structures)

Use the checkboxes to mark tasks as completed.

---

### 1. Core Wiring (`orthoviewer`)

- [x] Implement volume serialization helper(s) for passing R volumes to JS.
- [x] Add `ortho_viewer()` widget constructor:
  - [x] Accept background volume and colormap.
  - [x] Embed serialized volume and options in widget payload.
- [x] Implement Shiny bindings:
  - [x] `ortho_viewerOutput()` helper.
  - [x] `renderOrtho_viewer()` helper.
- [x] Create JS htmlwidget binding at `inst/htmlwidgets/ortho_viewer.js`:
  - [x] Build DOM shell (`.ortho-shell`, `.ortho-sidebar`, `.ortho-viewer-container`).
  - [x] Initialize `OrthogonalImageViewer` with background `ImageLayer`.
  - [x] Wire `<layer-control-panel>` to the `ImageLayer`.
- [x] Implement Shiny message handler:
  - [x] Register `ortho-viewer-command` handler.
  - [x] Route commands to internal `applyCommand()` function.

---

### 2. Proxy API (`orthoviewer`)

- [x] Implement `OrthoViewerProxy` R6 class:
  - [x] Store output id and session.
  - [x] `add_layer()` to add overlay volumes.
  - [x] `set_window()` to adjust window range.
  - [x] `set_threshold()` to adjust threshold range.
  - [x] `set_colormap()` to change colormap.
  - [x] `set_opacity()` to change layer opacity.
- [x] Implement `ortho_proxy()` helper to construct the proxy.
- [x] Test proxy with a simple Shiny app to confirm messages reach JS (see `orthoviewer_example_app()`).

---

### 3. JS Viewer Integration (**`~/code/jscode/neuroimjs`**)

> The following tasks involve updates to the external JS library at `~/code/jscode/neuroimjs`.

- [x] Confirm `OrthogonalImageViewer` supports `"left-tall"` layout:
  - [x] Axial pane tall on left.
  - [x] Coronal (top-right) and sagittal (bottom-right).
- [x] Ensure public API is suitable for htmlwidgets:
  - [x] `OrthogonalImageViewer.create({ container, imageLayer, options })`.
  - [x] `ImageLayer` and `VolStack` API for adding/updating layers.
- [x] Integrate `<layer-control-panel>`:
  - [x] Expose `imageLayer` property.
  - [x] Ensure panel discovers available layers and colormaps.
  - [x] Ensure panel updates call existing `volLayer` / `imageLayer` methods.
- [x] Verify threshold semantics in `ColorMap.buildLookupTable()`:
  - [x] Values `< low` or `> high` → opaque.
  - [x] `low < value < high` → transparent.

---

### 4. Theming and UX

- [x] Apply shell styling in `orthoviewer`:
  - [x] CSS for `.ortho-widget-root`, `.ortho-shell`, `.ortho-sidebar`, `.ortho-viewer-container`.
  - [ ] Ensure layout matches desired three‑pane design.
- [x] **[neuroimjs] Update `LayerControlPanelLit.ts` in `~/code/jscode/neuroimjs`:**
  - [x] Replace `static styles = css\`...\`` with Albers‑inspired styles:
    - [x] Warm paper gradient background.
    - [x] System UI font stack and small uppercase labels.
    - [x] Scoped Shoelace tokens for inputs (border, focus, primary color).
  - [x] Optionally add `.threshold-caption` explaining threshold semantics.
- [ ] Add optional viewer chrome:
  - [ ] Pane labels (e.g., axial/coronal/sagittal) as subtle overlays.
  - [ ] Slight frames around panes consistent with the sidebar aesthetic.

---

### 5. `neuroim2` Integration (**`~/code/neuroim2`**)

> The following tasks involve updates to the external R library at `~/code/neuroim2`.

- [ ] Implement or expose a helper to serialize `neuroim2` volumes for JS:
  - [ ] Return `list(dim, data, spacing, origin, axes)`.
- [ ] Ensure that spatial metadata (`spacing`, `origin`, `axes`) align with `neuroimjs` expectations.
- [ ] Add small tests or examples showing `neuroim2` → `orthoviewer` → `neuroimjs` flow.

---

### 6. Examples, Docs, and Validation (`orthoviewer`)

- [ ] Add a minimal Shiny example app:
  - [ ] Use a synthetic or example anatomy volume as background.
  - [ ] Add an overlay stat map via `p$add_layer()`.
  - [ ] Demonstrate window, threshold, colormap, and opacity adjustments.
- [ ] Write a vignette:
  - [ ] Describe the orthogonal viewer and sidebar controls.
  - [ ] Explain threshold/window semantics clearly.
  - [ ] Show end‑to‑end usage with `neuroim2`.
- [ ] Manual validation:
  - [ ] Confirm alignment and orientation across all three views.
  - [ ] Check interaction responsiveness with typical data sizes.
  - [ ] Verify visual styling meets the intended minimal Albers aesthetic.
