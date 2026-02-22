## OrthoViewer Project Plan

This plan coordinates work across three codebases:
- `orthoviewer` (R package, current repo) – HTML widgets, Shiny integration, R-facing API.
- `~/code/jscode/neuroimjs` – JavaScript core viewer + controls (orthogonal viewer, layer panel).
- `~/code/neuroim2` – R-side neuroim data structures and volume serialization.

Progress is tracked in `Progress.md`; architecture is summarized in `Architecture.md`.

---

### Phase 1 — Core Integration & Wiring

- [ ] Define JS htmlwidget binding for the orthogonal viewer in `orthoviewer`:
  - `inst/htmlwidgets/ortho_viewer.js` factory with:
    - Ortho shell layout (sidebar + three‑pane viewer container).
    - Creation of `OrthogonalImageViewer` with `"left-tall"` layout.
    - Wiring of `layer-control-panel` to the `ImageLayer`.
- [ ] Add R widget constructor and Shiny bindings in `orthoviewer`:
  - `ortho_viewer()` to initialize with a background volume.
  - `ortho_viewerOutput()` and `renderOrtho_viewer()` for Shiny.
- [ ] Implement R→JS proxy API in `orthoviewer`:
  - `ortho_proxy()` R6 class with methods:
    - `add_layer()`, `set_window()`, `set_threshold()`, `set_colormap()`, `set_opacity()`.
  - Proxies send `session$sendCustomMessage("ortho-viewer-command", ...)`.
- [ ] Implement volume serialization utilities in `orthoviewer` or `neuroim2`:
  - Convert R volume objects (from `neuroim2`) to JSON specs for `neuroimjs`.

---

### Phase 2 — JS Viewer & Panel Integration (`neuroimjs`)

- [ ] **[neuroimjs]** Ensure orthogonal viewer factory supports `"left-tall"` layout:
  - Axial pane tall on the left; coronal + sagittal stacked on the right.
- [ ] **[neuroimjs]** Expose a clean JS API used by the widget:
  - `OrthogonalImageViewer.create({ container, imageLayer, options })`.
  - `ImageLayer` / `VolStack` helpers for background + overlay layers.
- [ ] **[neuroimjs]** Integrate `<layer-control-panel>`:
  - Accept an `imageLayer` reference.
  - Panel introspects available layers and colormaps and updates them via existing handlers.
- [ ] **[neuroimjs]** Verify threshold semantics:
  - Confirm `ColorMap.buildLookupTable()` uses:
    - Values `< low` or `> high` → opaque.
    - `low < value < high` → transparent.

---

### Phase 3 — Albers-Inspired Theming

- [x] Apply warm paper + ochre/teal theme to `ortho_viewer` shell in `orthoviewer`:
  - [x] CSS for `.ortho-widget-root`, `.ortho-shell`, `.ortho-sidebar`, `.ortho-viewer-container`.
  - [ ] Flat planes, minimal borders, small uppercase labels.
- [ ] **[neuroimjs]** Update `LayerControlPanelLit.ts` styles:
  - Replace `static styles = css\`...\`` with Albers-inspired block (warm gradient, system UI font, scoped Shoelace tokens).
  - Ensure no behavior changes—style only.
- [ ] Optionally add threshold semantics caption in `layer-control-panel` template:
  - “Values \< low or \> high are opaque; between low and high are transparent.”

---

### Phase 4 — R API Polish & Examples

- [ ] Finalize the `orthoviewer` R API:
  - `ortho_viewer(bg, bg_colormap = "greys")`.
  - Layer operations via `ortho_proxy()`:
    - `p$add_layer(vol, thresh = c(-2, 2), colormap = "viridis")`.
    - `p$set_window(c(0, 120))`, `p$set_threshold(c(-3, 3))`, `p$set_colormap("magma")`, etc.
- [ ] Provide a minimal Shiny example in `orthoviewer`:
  - Show background anatomy + one stat map.
  - Demonstrate real‑time tuning via JS panel, plus one or two R‑driven updates.
- [ ] Document usage in `orthoviewer` vignettes:
  - Overview of the viewer, sidebar controls, and proxy API.
  - Short explanation of threshold/window semantics.

---

### Phase 5 — Validation & Refinement

- [ ] Validate round‑trip from `neuroim2` → `orthoviewer` → `neuroimjs`:
  - Confirm dimensions, spacing, orientation and ranges are consistent.
  - Check that layers align across all three views (axial, coronal, sagittal).
- [ ] Performance tuning:
  - Confirm responsive interaction for typical 3D volumes.
  - Assess behavior with multiple overlay layers.
- [ ] Visual polish:
  - Adjust colors, spacing, and typography to keep the composition clean and minimal.
  - Optionally add viewer chrome (pane labels, subtle frames) consistent with the sidebar.
