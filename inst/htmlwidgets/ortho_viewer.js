HTMLWidgets.widget({
  name: "ortho_viewer",
  type: "output",

  factory: function(el, width, height) {
    // Debug flag - set via x.debug from R or default false
    var DEBUG = false;
    function log(...args) {
      if (DEBUG) console.log("[ortho_viewer]", ...args);
    }
    function warn(...args) {
      console.warn("[ortho_viewer]", ...args);
    }

    // DOM skeleton: sidebar + viewer container
    el.classList.add("ortho-widget-root");
    el.innerHTML = "";

    const shell = document.createElement("div");
    shell.className = "ortho-shell";

    const sidebar = document.createElement("div");
    sidebar.className = "ortho-sidebar";
    sidebar.setAttribute("role", "complementary");
    sidebar.setAttribute("aria-label", "Layer controls");

    // layer-control-panel is provided by ~/code/jscode/neuroimjs,
    // which should be loaded as a dependency of this widget.
    const panel = document.createElement("layer-control-panel");
    sidebar.appendChild(panel);

    const viewerWrap = document.createElement("div");
    viewerWrap.className = "ortho-viewer-container";
    viewerWrap.setAttribute("role", "region");
    viewerWrap.setAttribute("aria-label", "Orthogonal image viewer");

    // inner padded container for the orthogonal viewer grid
    const viewerInner = document.createElement("div");
    viewerInner.className = "ortho-viewer-inner";
    viewerInner.tabIndex = 0;
    viewerInner.setAttribute("role", "region");
    viewerInner.setAttribute("aria-label", "Slice viewer. Arrow keys move crosshair in X and Y. Page Up or Page Down moves Z.");
    viewerWrap.appendChild(viewerInner);

    // Status bar at bottom of viewer
    const statusBar = document.createElement("div");
    statusBar.className = "ortho-status-bar";
    statusBar.setAttribute("role", "status");
    statusBar.setAttribute("aria-live", "polite");
    statusBar.setAttribute("aria-atomic", "false");
    statusBar.innerHTML = createStatusBarHTML();
    viewerWrap.appendChild(statusBar);

    shell.appendChild(sidebar);
    shell.appendChild(viewerWrap);
    el.appendChild(shell);

    const state = {
      config: null,
      viewer: null,
      imageLayer: null,
      volStack: null,
      viewerPromise: null,
      statusBar: statusBar,
      statusEls: {
        world: null,
        voxel: null,
        intensity: null,
        slice: null
      },
      handlersSetup: false,
      lastStatusCoord: null,
      lastCrosshairCoord: null,
      statusPollTimer: null,
      crosshairPollTimer: null,
      hoverThrottleTimeout: null
    };

    function createStatusBarHTML() {
      return `
        <div class="status-group">
          <span class="status-label">World</span>
          <span class="status-value status-coord" data-status="world">L 0.0 | P 0.0 | S 0.0</span>
        </div>
        <div class="status-separator" aria-hidden="true"></div>
        <div class="status-group">
          <span class="status-label">Voxel</span>
          <span class="status-value status-coord" data-status="voxel">[0, 0, 0]</span>
        </div>
        <div class="status-separator" aria-hidden="true"></div>
        <div class="status-group">
          <span class="status-label">Value</span>
          <span class="status-intensity" data-status="intensity">—</span>
        </div>
        <div class="status-separator" aria-hidden="true"></div>
        <div class="status-group">
          <span class="status-label">Slice</span>
          <span class="status-value" data-status="slice">—</span>
        </div>
      `;
    }

    state.statusEls.world = statusBar.querySelector('[data-status="world"]');
    state.statusEls.voxel = statusBar.querySelector('[data-status="voxel"]');
    state.statusEls.intensity = statusBar.querySelector('[data-status="intensity"]');
    state.statusEls.slice = statusBar.querySelector('[data-status="slice"]');

    function formatCoord(val) {
      if (val === null || val === undefined || !Number.isFinite(val)) return "—";
      return val.toFixed(1);
    }

    function formatWorldCoord(coord) {
      if (!coord || coord.length < 3) return "L — | P — | S —";
      // Assuming LPI orientation: x=L-R, y=P-A, z=I-S
      var x = coord[0], y = coord[1], z = coord[2];
      var lr = x >= 0 ? "L " + formatCoord(Math.abs(x)) : "R " + formatCoord(Math.abs(x));
      var pa = y >= 0 ? "P " + formatCoord(Math.abs(y)) : "A " + formatCoord(Math.abs(y));
      var is = z >= 0 ? "S " + formatCoord(Math.abs(z)) : "I " + formatCoord(Math.abs(z));
      return lr + " | " + pa + " | " + is;
    }

    function formatVoxelCoord(coord, space) {
      if (!coord || coord.length < 3 || !space) return "[—, —, —]";
      // Convert world coord to voxel indices
      try {
        var voxel = space.worldToVoxel ? space.worldToVoxel(coord) : coord;
        return "[" + Math.round(voxel[0]) + ", " + Math.round(voxel[1]) + ", " + Math.round(voxel[2]) + "]";
      } catch (e) {
        return "[—, —, —]";
      }
    }

    function getIntensityAtCoord(coord) {
      if (!state.volStack || !coord || coord.length < 3) return [];
      var results = [];
      var layerIds = state.volStack.getLayerIds ? state.volStack.getLayerIds() : [];
      for (var i = 0; i < layerIds.length; i++) {
        var layer = state.volStack.getLayerById(layerIds[i]);
        if (layer && layer.volume) {
          try {
            // Convert world coordinate to voxel indices
            var space = layer.volume.space;
            var voxel = space.coordToGrid ? space.coordToGrid(coord) : coord;
            // Round to nearest integer voxel index
            var vi = Math.round(voxel[0]);
            var vj = Math.round(voxel[1]);
            var vk = Math.round(voxel[2]);
            // Check bounds
            var dims = layer.volume.dim;
            var val = null;
            if (vi >= 0 && vi < dims[0] && vj >= 0 && vj < dims[1] && vk >= 0 && vk < dims[2]) {
              val = layer.volume.getAt ? layer.volume.getAt(vi, vj, vk) : null;
            }
            results.push({
              id: layerIds[i],
              value: val,
              colormap: layer.colorMap ? layer.colorMap.name || "unknown" : "unknown"
            });
          } catch (e) {
            results.push({ id: layerIds[i], value: null, colormap: "unknown" });
          }
        }
      }
      return results;
    }

    function formatIntensities(intensities) {
      if (!intensities || intensities.length === 0) return "—";
      return intensities.map(function(item, idx) {
        var valStr = (item.value !== null && Number.isFinite(item.value))
          ? item.value.toFixed(2)
          : "—";
        var label = idx === 0 ? "bg" : "L" + idx;
        return '<span class="intensity-item"><span class="intensity-value">' + label + ': ' + valStr + '</span></span>';
      }).join("");
    }

    function formatIntensitiesPlain(intensities) {
      if (!intensities || intensities.length === 0) return "—";
      return intensities.map(function(item, idx) {
        var valStr = (item.value !== null && Number.isFinite(item.value))
          ? item.value.toFixed(2)
          : "—";
        var label = idx === 0 ? "bg" : "L" + idx;
        return label + ": " + valStr;
      }).join(", ");
    }

    function formatSliceInfo() {
      if (!state.viewer) return "—";
      try {
        var indices = state.viewer.sliceIndices;
        var totals = state.viewer.totalSlices;
        return "A:" + indices.axial + "/" + totals.axial +
               " C:" + indices.coronal + "/" + totals.coronal +
               " S:" + indices.sagittal + "/" + totals.sagittal;
      } catch (e) {
        return "—";
      }
    }

    function updateStatusBar() {
      if (!state.viewer || !state.statusBar) return;

      try {
        var mouseState = state.viewer.mouseState;
        var coord = mouseState && mouseState.worldCoordinate
          ? mouseState.worldCoordinate
          : state.viewer.currentCoord;

        var worldEl = state.statusEls.world;
        var voxelEl = state.statusEls.voxel;
        var intensityEl = state.statusEls.intensity;
        var sliceEl = state.statusEls.slice;

        var worldText = formatWorldCoord(coord);
        var voxelText = state.imageLayer
          ? formatVoxelCoord(coord, state.imageLayer.neuroSpace)
          : "[—, —, —]";
        var intensityVals = getIntensityAtCoord(coord);
        var intensityText = formatIntensitiesPlain(intensityVals);
        var sliceText = formatSliceInfo();

        if (worldEl) worldEl.textContent = worldText;
        if (voxelEl && state.imageLayer) {
          voxelEl.textContent = voxelText;
        }
        if (intensityEl) {
          intensityEl.innerHTML = formatIntensities(intensityVals);
        }
        if (sliceEl) {
          sliceEl.textContent = sliceText;
        }
        state.statusBar.setAttribute(
          "aria-label",
          "World " + worldText + ", Voxel " + voxelText + ", Value " + intensityText + ", Slice " + sliceText
        );
      } catch (e) {
        // Silent fail for status bar updates - not critical
      }
    }

    // Throttled status bar update (limit to 30fps)
    var statusUpdatePending = false;
    function requestStatusUpdate() {
      if (statusUpdatePending) return;
      statusUpdatePending = true;
      requestAnimationFrame(function() {
        updateStatusBar();
        statusUpdatePending = false;
      });
    }

    function clearPollingTimers() {
      if (state.statusPollTimer) {
        clearInterval(state.statusPollTimer);
        state.statusPollTimer = null;
      }
      if (state.crosshairPollTimer) {
        clearInterval(state.crosshairPollTimer);
        state.crosshairPollTimer = null;
      }
    }

    function volumeFromR(spec) {
      if (!spec || !spec.dim || !spec.data) {
        throw new Error("Invalid volume specification from R.");
      }

      log("volumeFromR: Creating NeuroSpace with dim=", spec.dim,
          "spacing=", spec.spacing, "origin=", spec.origin);

      // Create NeuroSpace with dim, spacing, and origin only.
      // Do NOT pass spec.axes - neuroimjs expects an AxisSet object,
      // not a plain string array. Let NeuroSpace create default axes.
      // The R-side axes metadata is kept in spec for future use but
      // not passed to the constructor.
      const ns = new neuroimjs.NeuroSpace(
        spec.dim,
        spec.spacing || [1, 1, 1],
        spec.origin || [0, 0, 0]
        // axes parameter omitted - NeuroSpace will use default AxisSet3D
      );

      log("volumeFromR: NeuroSpace created");

      // Use FloatNeuroVol (concrete class) instead of abstract DenseNeuroVol
      const data = new Float32Array(spec.data);
      log("volumeFromR: Creating FloatNeuroVol with data length=", data.length);

      const vol = new neuroimjs.FloatNeuroVol(ns, data);
      log("volumeFromR: FloatNeuroVol created");

      return vol;
    }

    function ensureViewer() {
      if (state.viewerPromise) return state.viewerPromise;
      if (!state.config) return Promise.resolve(null);

      state.viewerPromise = (async () => {
        const x = state.config;

        // Set debug flag from R config
        DEBUG = x.debug === true;

        const bgVol = volumeFromR(x.bg_volume);
        // FIX: Correct precedence - check x.bg_range first, then fall back to volume range
        const bgRange = x.bg_range
          ? x.bg_range
          : (bgVol.getRange ? bgVol.getRange() : [0, 1]);
        const bgThreshold = x.bg_threshold || [0, 0];
        const cmapName = x.bg_colormap || "Greys";
        const bgCmap = neuroimjs.ColorMap.fromPreset
          ? neuroimjs.ColorMap.fromPreset(cmapName)
          : null;

        log("ensureViewer: Creating VolLayer with id=", x.bg_id || "background");
        log("ensureViewer: bgRange=", bgRange);

        const bgLayer = new neuroimjs.VolLayer(
          x.bg_id || "background",
          bgVol,
          bgCmap,
          bgRange,
          bgThreshold,
          1  // opacity
        );

        log("ensureViewer: VolLayer created");

        // VolStack constructor uses spread syntax (...layers), so pass layer directly, not in array
        const volStack = new neuroimjs.VolStack(bgLayer);
        log("ensureViewer: VolStack created");

        const imageLayer = new neuroimjs.ImageLayer(volStack);
        log("ensureViewer: ImageLayer created");

        const viewer = await neuroimjs.OrthogonalImageViewer.create({
          container: viewerInner,
          imageLayer: imageLayer,
          options: {
            layout: "left-tall",
            showCrosshair: true,
            showSlider: true
          }
        });

        panel.imageLayer = imageLayer;
        panel.viewer = viewer;  // Give panel access to viewer for re-rendering
        panel.requestUpdate && panel.requestUpdate();

        state.viewer = viewer;
        state.imageLayer = imageLayer;
        state.volStack = volStack;

        setupViewerHandlers();

        // Initial status bar update
        requestStatusUpdate();

        return viewer;
      })();

      return state.viewerPromise;
    }

    function resolveLayer(layerId) {
      const img = state.imageLayer;
      if (!img) return null;
      const stack = img.getVolStack ? img.getVolStack() : null;
      if (!stack) return null;
      if (layerId) {
        return stack.getLayerById ? stack.getLayerById(layerId) : null;
      }
      if (!img.getLayerIds) return null;
      const ids = img.getLayerIds();
      if (!ids || !ids.length) return null;
      const lastId = ids[ids.length - 1];
      return stack.getLayerById ? stack.getLayerById(lastId) : null;
    }

    function forceRerender() {
      // Force all SliceViewers to re-render their current slice
      if (!state.viewer) return;
      var views = ["axial", "coronal", "sagittal"];
      views.forEach(function(viewName) {
        var sliceViewer = state.viewer.getSliceViewer
          ? state.viewer.getSliceViewer(viewName)
          : null;
        if (sliceViewer && sliceViewer.view && sliceViewer.view.renderSlice) {
          sliceViewer.view.renderSlice();
        }
      });
    }

    function applyCommand(cmd) {
      ensureViewer().then(function() {
        const img = state.imageLayer;
        if (!img || !cmd || !cmd.type) return;

        switch (cmd.type) {
          case "add-layer": {
            log("add-layer command received:", cmd.layer_id);
            const vol = volumeFromR(cmd.volume);
            log("volume created:", vol);
            const cmapName = cmd.colormap || "Greys";
            var cmap = null;
            try {
              cmap = neuroimjs.ColorMap.fromPreset
                ? neuroimjs.ColorMap.fromPreset(cmapName)
                : null;
            } catch (cmapError) {
              warn("Colormap preset '" + cmapName + "' not found, falling back to Greys");
              try {
                cmap = neuroimjs.ColorMap.fromPreset("Greys");
              } catch (e) {
                cmap = null;
              }
            }
            log("colormap:", cmapName, cmap);
            const range = cmd.range || (vol.getRange ? vol.getRange() : [0, 1]);
            const thr = cmd.threshold || [0, 0];
            const opacity = typeof cmd.opacity === "number" ? cmd.opacity : 1;
            const layerId = cmd.layer_id || ("layer_" + Date.now());

            log("creating VolLayer:", { layerId: layerId, range: range, thr: thr, opacity: opacity });
            const layer = new neuroimjs.VolLayer(
              layerId,
              vol,
              cmap,
              range,
              thr,
              opacity
            );
            log("VolLayer created:", layer);

            // Add layer to the shared VolStack via the main ImageLayer
            log("calling img.addVolLayer, img=", img);
            log("img.addVolLayer exists?", typeof img.addVolLayer);
            img.addVolLayer(layer);
            log("layer added successfully");
            // Force all views to re-render with the new layer
            forceRerender();
            // Update the control panel - must call initializeFromImageLayer directly
            // since setting the same imageLayer reference won't trigger Lit's change detection
            panel.imageLayer = img;
            if (panel.initializeFromImageLayer) {
              panel.initializeFromImageLayer();
            } else {
              panel.requestUpdate && panel.requestUpdate();
            }
            break;
          }

          case "set-window": {
            const layer = resolveLayer(cmd.layer_id);
            if (!layer) return;
            const range = cmd.range;
            if (!range) return;
            // Update all ImageLayers (main + per-view) and force re-render
            if (state.viewer && state.viewer.applyToImageLayers) {
              state.viewer.applyToImageLayers(function(imgLayer) {
                imgLayer.updateLayer(layer.id, { range: range });
              });
              forceRerender();
            }
            break;
          }

          case "set-threshold": {
            const layer = resolveLayer(cmd.layer_id);
            if (!layer) return;
            const thr = cmd.threshold;
            if (!thr) return;
            // Update all ImageLayers (main + per-view) and force re-render
            if (state.viewer && state.viewer.applyToImageLayers) {
              state.viewer.applyToImageLayers(function(imgLayer) {
                imgLayer.updateLayer(layer.id, { threshold: thr });
              });
              forceRerender();
            }
            break;
          }

          case "set-colormap": {
            const layer = resolveLayer(cmd.layer_id);
            if (!layer) return;
            const cmapName = cmd.colormap;
            if (!cmapName) return;
            const cmap = neuroimjs.ColorMap.fromPreset
              ? neuroimjs.ColorMap.fromPreset(cmapName)
              : null;
            // Update all ImageLayers (main + per-view) and force re-render
            if (state.viewer && state.viewer.applyToImageLayers) {
              state.viewer.applyToImageLayers(function(imgLayer) {
                imgLayer.updateLayer(layer.id, { colormap: cmap });
              });
              forceRerender();
            }
            break;
          }

          case "set-opacity": {
            const layer = resolveLayer(cmd.layer_id);
            if (!layer) return;
            const alpha = cmd.opacity;
            if (typeof alpha !== "number") return;
            // Update all ImageLayers (main + per-view) and force re-render
            if (state.viewer && state.viewer.applyToImageLayers) {
              state.viewer.applyToImageLayers(function(imgLayer) {
                imgLayer.updateLayer(layer.id, { alpha: alpha });
              });
              forceRerender();
            }
            break;
          }

          case "set-crosshair": {
            // Set crosshair/coordinate position
            const coord = cmd.coord;
            if (!coord || coord.length < 3) return;
            const animate = cmd.animate || false;
            const duration = cmd.duration || 500;

            if (animate && state.viewer) {
              // Animated transition
              var current = state.viewer.currentCoord;
              if (current && current.length >= 3) {
                animateCrosshair(current.slice(), coord, duration);
              } else {
                state.viewer.setWorldCoord(coord);
              }
            } else if (state.viewer && state.viewer.setWorldCoord) {
              state.viewer.setWorldCoord(coord);
            }
            break;
          }

          case "get-crosshair": {
            // Return current crosshair position via Shiny callback
            if (state.viewer && typeof Shiny !== "undefined" && Shiny.setInputValue) {
              var coord = state.viewer.currentCoord;
              var space = state.imageLayer ? state.imageLayer.neuroSpace : null;
              Shiny.setInputValue(el.id + "_crosshair_response", {
                request_id: cmd.request_id || null,
                world: coord ? coord.slice() : null,
                voxel: getVoxelArray(coord, space),
                timestamp: Date.now()
              }, { priority: "event" });
            }
            break;
          }

          case "set-layer-visible": {
            const layer = resolveLayer(cmd.layer_id);
            if (!layer) return;
            const visible = cmd.visible !== false; // default true
            // Update all ImageLayers (main + per-view) and force re-render
            if (state.viewer && state.viewer.applyToImageLayers) {
              state.viewer.applyToImageLayers(function(imgLayer) {
                imgLayer.updateLayer(layer.id, { visible: visible });
              });
              forceRerender();
            }
            break;
          }

          case "set-layer-order": {
            // Reorder layers based on provided array of layer IDs
            const layerIds = cmd.layer_ids;
            if (!layerIds || !Array.isArray(layerIds)) return;
            if (!state.volStack || !state.volStack.moveLayerById) return;

            // Move each layer to its desired position
            // Process from first to last - each moveLayerById puts layer at target index
            for (var i = 0; i < layerIds.length; i++) {
              try {
                state.volStack.moveLayerById(layerIds[i], i);
              } catch (e) {
                warn("Failed to move layer:", layerIds[i], e);
              }
            }
            forceRerender();
            // Update the control panel
            panel.imageLayer = state.imageLayer;
            panel.requestUpdate && panel.requestUpdate();
            break;
          }

          case "remove-layer": {
            const layerId = cmd.layer_id;
            if (!layerId || !state.volStack) return;
            try {
              var layer = state.volStack.getLayerById(layerId);
              if (layer && state.volStack.removeLayer) {
                state.volStack.removeLayer(layer);
                forceRerender();
                panel.imageLayer = state.imageLayer;
                panel.requestUpdate && panel.requestUpdate();
              }
            } catch (e) {
              warn("Failed to remove layer:", layerId, e);
            }
            break;
          }

          case "get-layers": {
            // Return list of layers via Shiny callback
            if (typeof Shiny !== "undefined" && Shiny.setInputValue) {
              var layers = [];
              if (state.volStack && state.volStack.getLayerIds) {
                var ids = state.volStack.getLayerIds();
                for (var i = 0; i < ids.length; i++) {
                  var layer = state.volStack.getLayerById(ids[i]);
                  if (layer) {
                    layers.push({
                      id: ids[i],
                      visible: layer.visible !== false,
                      opacity: layer.alpha !== undefined
                        ? layer.alpha
                        : (layer.opacity !== undefined ? layer.opacity : 1),
                      index: i
                    });
                  }
                }
              }
              Shiny.setInputValue(el.id + "_layers_response", {
                request_id: cmd.request_id || null,
                layers: layers,
                timestamp: Date.now()
              }, { priority: "event" });
            }
            break;
          }
        }
      });
    }

    // Animate crosshair from one position to another
    function animateCrosshair(fromCoord, toCoord, duration) {
      if (!state.viewer || !state.viewer.setWorldCoord) return;
      var prefersReducedMotion = window.matchMedia &&
        window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      if (prefersReducedMotion || !Number.isFinite(duration) || duration <= 0) {
        state.viewer.setWorldCoord(toCoord);
        return;
      }

      var startTime = performance.now();
      var dx = toCoord[0] - fromCoord[0];
      var dy = toCoord[1] - fromCoord[1];
      var dz = toCoord[2] - fromCoord[2];

      function step(currentTime) {
        var elapsed = currentTime - startTime;
        var t = Math.min(elapsed / duration, 1);
        // Ease-out cubic for smooth deceleration
        var eased = 1 - Math.pow(1 - t, 3);

        var x = fromCoord[0] + dx * eased;
        var y = fromCoord[1] + dy * eased;
        var z = fromCoord[2] + dz * eased;

        state.viewer.setWorldCoord([x, y, z]);

        if (t < 1) {
          requestAnimationFrame(step);
        }
      }

      requestAnimationFrame(step);
    }

    // expose internal state for Shiny custom messages
    el.__ortho_state__ = {
      state: state,
      applyCommand: applyCommand,
      panel: panel
    };

    // =========================================
    // Shiny Event Handling
    // =========================================

    function getVoxelArray(coord, space) {
      if (!coord || coord.length < 3 || !space) return null;
      try {
        var voxel = space.worldToVoxel ? space.worldToVoxel(coord) : space.coordToGrid ? space.coordToGrid(coord) : coord;
        return [Math.round(voxel[0]), Math.round(voxel[1]), Math.round(voxel[2])];
      } catch (e) {
        return null;
      }
    }

    function getIntensityObject(coord) {
      var result = {};
      if (!state.volStack || !coord || coord.length < 3) return result;
      var layerIds = state.volStack.getLayerIds ? state.volStack.getLayerIds() : [];
      for (var i = 0; i < layerIds.length; i++) {
        var layer = state.volStack.getLayerById(layerIds[i]);
        if (layer && layer.volume) {
          try {
            var space = layer.volume.space;
            var voxel = space.coordToGrid ? space.coordToGrid(coord) : coord;
            var vi = Math.round(voxel[0]);
            var vj = Math.round(voxel[1]);
            var vk = Math.round(voxel[2]);
            var dims = layer.volume.dim;
            var val = null;
            if (vi >= 0 && vi < dims[0] && vj >= 0 && vj < dims[1] && vk >= 0 && vk < dims[2]) {
              val = layer.volume.getAt ? layer.volume.getAt(vi, vj, vk) : null;
            }
            result[layerIds[i]] = val;
          } catch (e) {
            result[layerIds[i]] = null;
          }
        }
      }
      return result;
    }

    function buildEventData(coord, viewName, eventType, mouseEvent) {
      var space = state.imageLayer ? state.imageLayer.neuroSpace : null;
      return {
        world: coord ? coord.slice() : null,
        voxel: getVoxelArray(coord, space),
        intensity: getIntensityObject(coord),
        view: viewName || null,
        type: eventType,
        button: mouseEvent ? (mouseEvent.button === 0 ? "left" : mouseEvent.button === 2 ? "right" : "middle") : null,
        shift: mouseEvent ? mouseEvent.shiftKey : false,
        ctrl: mouseEvent ? (mouseEvent.ctrlKey || mouseEvent.metaKey) : false,
        alt: mouseEvent ? mouseEvent.altKey : false,
        timestamp: Date.now()
      };
    }

    function sendShinyEvent(eventName, data) {
      if (typeof Shiny !== "undefined" && Shiny.setInputValue) {
        Shiny.setInputValue(el.id + "_" + eventName, data, { priority: "event" });
      }
    }

    // Set up status and Shiny handlers once after viewer initialization.
    function setupViewerHandlers() {
      if (!state.viewer || state.handlersSetup) return;
      state.handlersSetup = true;

      // Keep status bar in sync while moving across slices.
      viewerInner.addEventListener("mousemove", requestStatusUpdate);

      // Poll crosshair coordinate changes for keyboard/programmatic updates.
      state.statusPollTimer = setInterval(function() {
        if (!document.body.contains(el)) {
          clearPollingTimers();
          return;
        }
        if (!state.viewer) return;
        var coord = state.viewer.currentCoord;
        if (coord && (!state.lastStatusCoord ||
            coord[0] !== state.lastStatusCoord[0] ||
            coord[1] !== state.lastStatusCoord[1] ||
            coord[2] !== state.lastStatusCoord[2])) {
          state.lastStatusCoord = coord.slice();
          requestStatusUpdate();
        }
      }, 100);

      // Click event
      viewerInner.addEventListener("click", function(e) {
        var mouseState = state.viewer.mouseState;
        var coord = mouseState && mouseState.worldCoordinate
          ? mouseState.worldCoordinate
          : state.viewer.currentCoord;
        var viewName = mouseState ? mouseState.viewName : null;
        sendShinyEvent("click", buildEventData(coord, viewName, "click", e));
      });

      // Double-click event
      viewerInner.addEventListener("dblclick", function(e) {
        var mouseState = state.viewer.mouseState;
        var coord = mouseState && mouseState.worldCoordinate
          ? mouseState.worldCoordinate
          : state.viewer.currentCoord;
        var viewName = mouseState ? mouseState.viewName : null;
        sendShinyEvent("dblclick", buildEventData(coord, viewName, "dblclick", e));
      });

      // Right-click (context menu) event
      viewerInner.addEventListener("contextmenu", function(e) {
        // Don't prevent default - let user decide in R if they want custom menu
        var mouseState = state.viewer.mouseState;
        var coord = mouseState && mouseState.worldCoordinate
          ? mouseState.worldCoordinate
          : state.viewer.currentCoord;
        var viewName = mouseState ? mouseState.viewName : null;
        sendShinyEvent("rightclick", buildEventData(coord, viewName, "rightclick", e));
      });

      // Crosshair change event (throttled)
      state.crosshairPollTimer = setInterval(function() {
        if (!document.body.contains(el)) {
          clearPollingTimers();
          return;
        }
        if (!state.viewer) return;
        var coord = state.viewer.currentCoord;
        if (coord && (!state.lastCrosshairCoord ||
            coord[0] !== state.lastCrosshairCoord[0] ||
            coord[1] !== state.lastCrosshairCoord[1] ||
            coord[2] !== state.lastCrosshairCoord[2])) {
          state.lastCrosshairCoord = coord.slice();
          var space = state.imageLayer ? state.imageLayer.neuroSpace : null;
          sendShinyEvent("crosshair", {
            world: coord.slice(),
            voxel: getVoxelArray(coord, space),
            intensity: getIntensityObject(coord),
            timestamp: Date.now()
          });
        }
      }, 100);

      // Hover event (throttled to avoid flooding)
      viewerInner.addEventListener("mousemove", function(e) {
        if (state.hoverThrottleTimeout) return;
        state.hoverThrottleTimeout = setTimeout(function() {
          state.hoverThrottleTimeout = null;
          var mouseState = state.viewer.mouseState;
          var coord = mouseState && mouseState.worldCoordinate
            ? mouseState.worldCoordinate
            : null;
          if (coord) {
            var viewName = mouseState ? mouseState.viewName : null;
            sendShinyEvent("hover", buildEventData(coord, viewName, "hover", e));
          }
        }, 150); // 150ms throttle for hover
      });

      // Mouse leave event
      viewerInner.addEventListener("mouseleave", function(e) {
        if (state.hoverThrottleTimeout) {
          clearTimeout(state.hoverThrottleTimeout);
          state.hoverThrottleTimeout = null;
        }
        sendShinyEvent("hover", {
          world: null,
          voxel: null,
          intensity: {},
          view: null,
          type: "leave",
          timestamp: Date.now()
        });
      });

      // Keyboard navigation for accessibility and precision control.
      viewerInner.addEventListener("keydown", function(e) {
        if (!state.viewer || !state.viewer.currentCoord || !state.viewer.setWorldCoord) return;
        var coord = state.viewer.currentCoord.slice();
        var step = e.shiftKey ? 5 : 1;
        var handled = true;

        switch (e.key) {
          case "ArrowLeft":
            coord[0] -= step;
            break;
          case "ArrowRight":
            coord[0] += step;
            break;
          case "ArrowUp":
            coord[1] += step;
            break;
          case "ArrowDown":
            coord[1] -= step;
            break;
          case "PageUp":
            coord[2] += step;
            break;
          case "PageDown":
            coord[2] -= step;
            break;
          default:
            handled = false;
        }

        if (!handled) return;
        e.preventDefault();
        state.viewer.setWorldCoord(coord);
        requestStatusUpdate();
      });
    }

    return {
      renderValue: function(x) {
        state.config = x || null;

        // When show_sidebar is false, remove sidebar from DOM and switch
        // to a single-column layout.  The panel element is still created
        // and wired (it lives in el.__ortho_state__.panel) so an
        // external host can relocate it.
        if (x && x.show_sidebar === false) {
          if (sidebar.parentNode) sidebar.parentNode.removeChild(sidebar);
          shell.classList.add("ortho-no-sidebar");
        }

        // trigger (re)initialization if needed
        ensureViewer().then(function(viewer) {
          if (!viewer) return;
          if (x && Array.isArray(x.commands)) {
            x.commands.forEach(applyCommand);
          }
        });
      },

      resize: function(width, height) {
        if (state.viewer && state.viewer.resize) {
          state.viewer.resize(width, height);
        }
      }
    };
  }
});

// Shiny custom message handler for proxy commands
// Must wait for Shiny to be defined and ready
(function() {
  var handlerRegistered = false;

  function registerHandler() {
    if (handlerRegistered) return;
    if (typeof Shiny === "undefined" || !Shiny.addCustomMessageHandler) {
      setTimeout(registerHandler, 50);
      return;
    }
    handlerRegistered = true;
    Shiny.addCustomMessageHandler("ortho-viewer-command", function(msg) {
      var el = document.getElementById(msg.id);
      if (!el || !el.__ortho_state__) return;
      el.__ortho_state__.applyCommand(msg);
    });
  }

  if (typeof HTMLWidgets !== "undefined" && HTMLWidgets.shinyMode) {
    // Try immediate registration
    registerHandler();
    // Also listen for shiny:connected in case we're too early
    document.addEventListener("shiny:connected", function() {
      registerHandler();
    });
  }
})();
