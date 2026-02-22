##' Launch orthoviewer with folder discovery
##'
##' Scans a folder for NIfTI files (\code{.nii}, \code{.nii.gz}), extracts
##' header metadata, and provides a lightweight UI for loading supported files
##' into the orthogonal viewer.
##'
##' Eligibility rules:
##' \itemize{
##'   \item 3D files are loadable.
##'   \item 4D files are loadable only when they contain fewer than 3 volumes.
##' }
##'
##' @param path Folder to scan. Defaults to current working directory.
##' @param recursive Logical; if TRUE, also scan subfolders.
##' @param run Logical; if TRUE and interactive, launch immediately.
##'
##' @return A Shiny app object (invisibly if run interactively).
##' @export
orthoviewer <- function(path = ".",
                        recursive = FALSE,
                        run = interactive()) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to launch orthoviewer().",
         call. = FALSE)
  }
  if (!requireNamespace("neuroim2", quietly = TRUE)) {
    stop("The 'neuroim2' package is required to load NIfTI files.",
         call. = FALSE)
  }
  if (!dir.exists(path)) {
    stop("Folder does not exist: ", path, call. = FALSE)
  }

  initial_path <- normalizePath(path, winslash = "/", mustWork = TRUE)

  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$title("orthoviewer"),
      shiny::tags$style(shiny::HTML("
        html, body { height: 100%; margin: 0; background: #eef2f7; }
        .container-fluid { height: 100%; padding: 0; }
        .ov-shell {
          display: grid;
          grid-template-columns: 420px minmax(0, 1fr);
          height: 100vh;
          background: radial-gradient(circle at top left, #f9fbff 0%, #edf2f9 55%, #e6edf6 100%);
        }
        .ov-sidebar {
          border-right: 1px solid rgba(18, 34, 62, 0.12);
          background: linear-gradient(180deg, #f8fbff 0%, #eef3fa 100%);
          box-sizing: border-box;
        }
        .ov-card {
          background: rgba(255, 255, 255, 0.94);
          border: 1px solid rgba(18, 34, 62, 0.09);
          border-radius: 12px;
          box-shadow: 0 14px 32px -26px rgba(11, 25, 52, 0.7);
          padding: 12px;
          margin-bottom: 12px;
        }
        .ov-card h3 {
          margin: 0 0 6px 0;
          font-size: 18px;
          color: #1e2b42;
          letter-spacing: 0.01em;
        }
        .ov-card h4 {
          margin: 0 0 8px 0;
          font-size: 12px;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: #52627f;
          font-weight: 700;
        }
        .ov-subtitle {
          margin: 0 0 10px 0;
          color: #5f6e8c;
          font-size: 12px;
        }
        .ov-summary { margin-top: 10px; }
        .ov-pills { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 6px; }
        .ov-pill {
          font-size: 11px;
          padding: 4px 8px;
          border-radius: 999px;
          font-weight: 600;
          border: 1px solid transparent;
        }
        .ov-pill-total { background: #edf2ff; color: #2f4a7d; border-color: #d8e2ff; }
        .ov-pill-ok { background: #e8f7ee; color: #14683f; border-color: #cdebd8; }
        .ov-pill-skip { background: #fff1e8; color: #8a4418; border-color: #f4dccd; }
        .ov-scan-meta {
          margin: 0;
          color: #5f6d86;
          font-size: 11px;
          line-height: 1.35;
          word-break: break-word;
        }
        .ov-table-wrap {
          border: 1px solid rgba(18, 34, 62, 0.09);
          border-radius: 10px;
          overflow: auto;
          max-height: 290px;
          background: #fdfefe;
        }
        .ov-table { width: 100%; border-collapse: collapse; font-size: 11px; }
        .ov-table th {
          position: sticky;
          top: 0;
          z-index: 1;
          background: #edf2fb;
          color: #32425f;
          text-align: left;
          font-weight: 700;
          padding: 7px 8px;
          border-bottom: 1px solid rgba(18, 34, 62, 0.09);
          white-space: nowrap;
        }
        .ov-table td {
          padding: 7px 8px;
          border-bottom: 1px solid rgba(18, 34, 62, 0.06);
          vertical-align: top;
          color: #2a3752;
          white-space: nowrap;
        }
        .ov-table tr:last-child td { border-bottom: none; }
        .ov-file {
          font-family: 'JetBrains Mono', 'SF Mono', 'Consolas', monospace;
          font-size: 11px;
          white-space: normal;
          word-break: break-word;
        }
        .ov-reason {
          margin-top: 4px;
          color: #87400f;
          font-size: 11px;
          white-space: normal;
          line-height: 1.3;
        }
        .ov-status {
          display: inline-block;
          border-radius: 999px;
          padding: 2px 6px;
          font-size: 11px;
          font-weight: 700;
          letter-spacing: 0.02em;
        }
        .ov-status-ok {
          background: #e8f7ee;
          color: #14683f;
          border: 1px solid #cdebd8;
        }
        .ov-status-skip {
          background: #fff1e8;
          color: #8a4418;
          border: 1px solid #f4dccd;
        }
        .ov-empty {
          font-size: 12px;
          color: #5f6d86;
          padding: 10px 4px;
        }
        .ov-meta-row {
          display: flex;
          justify-content: space-between;
          gap: 10px;
          padding: 4px 0;
          border-bottom: 1px solid rgba(18, 34, 62, 0.06);
          font-size: 12px;
        }
        .ov-meta-row:last-child { border-bottom: none; }
        .ov-meta-label { color: #60708a; }
        .ov-meta-value {
          color: #23324f;
          font-family: 'JetBrains Mono', 'SF Mono', 'Consolas', monospace;
          text-align: right;
        }
        .ov-load-status {
          margin-top: 8px;
          color: #2c3c5b;
          font-size: 12px;
          min-height: 18px;
        }
        .ov-main {
          min-width: 0;
          height: 100%;
          padding: 14px;
          box-sizing: border-box;
        }
        .ov-viewer-shell {
          position: relative;
          height: 100%;
          border-radius: 12px;
          overflow: hidden;
          border: 1px solid rgba(18, 34, 62, 0.1);
          box-shadow: 0 14px 32px -26px rgba(11, 25, 52, 0.7);
          background: #0f1724;
        }
        .ov-viewer-banner {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          z-index: 3;
          padding: 7px 10px;
          font-size: 11px;
          font-family: 'JetBrains Mono', 'SF Mono', 'Consolas', monospace;
          color: #d6e1f3;
          background: linear-gradient(90deg, rgba(10, 20, 34, 0.94), rgba(18, 31, 51, 0.78));
          border-bottom: 1px solid rgba(192, 210, 238, 0.16);
          backdrop-filter: blur(2px);
          text-overflow: ellipsis;
          overflow: hidden;
          white-space: nowrap;
        }
        .ov-viewer {
          position: absolute;
          top: 30px;
          left: 0;
          right: 0;
          bottom: 0;
        }
        .ov-placeholder {
          position: absolute;
          inset: 30px 0 0 0;
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
          background: linear-gradient(180deg, rgba(9, 14, 24, 0.55) 0%, rgba(8, 12, 21, 0.65) 100%);
          color: #d2ddf1;
          padding: 24px;
          font-size: 14px;
          line-height: 1.5;
        }
        .ov-row-ok td:first-child { border-left: 3px solid #2ea35e; }
        .ov-row-skip td:first-child { border-left: 3px solid #d4813a; }
        .ov-row-clickable { cursor: pointer; }
        .ov-row-clickable:hover { background: rgba(46, 163, 94, 0.06); }
        .ov-copy-btn {
          background: transparent;
          border: 1px solid rgba(192, 210, 238, 0.3);
          color: #d6e1f3;
          cursor: pointer;
          padding: 2px 8px;
          border-radius: 4px;
          font-size: 11px;
          margin-left: 8px;
        }
        .ov-copy-btn:hover { background: rgba(192, 210, 238, 0.12); border-color: rgba(192, 210, 238, 0.5); }
        .ov-card.ov-load-card { display: flex; flex-direction: column; }
        .ov-load-card-body { display: flex; flex-direction: column; flex: 1; }
        .ov-load-card-body .btn-success { margin-top: auto; }
        #scan_path { font-family: 'JetBrains Mono', 'SF Mono', 'Consolas', monospace; font-size: 11px; }
        .ov-banner-empty { font-style: italic; color: #8a9bba; }
        .ov-connector {
          text-align: center;
          color: #8a9bba;
          font-size: 11px;
          padding: 2px 0;
          letter-spacing: 0.02em;
        }
        .ov-filter-help {
          font-size: 11px;
          color: #5f6d86;
          margin-top: -6px;
          margin-bottom: 8px;
        }
        /* --- Tabbed sidebar --- */
        .ov-sidebar {
          display: flex;
          flex-direction: column;
        }
        .ov-tabs {
          display: flex;
          border-bottom: 1px solid rgba(18, 34, 62, 0.12);
          flex-shrink: 0;
        }
        .ov-tab-btn {
          flex: 1;
          padding: 10px 0;
          border: none;
          background: transparent;
          font-size: 12px;
          font-weight: 700;
          letter-spacing: 0.04em;
          text-transform: uppercase;
          color: #5f6e8c;
          cursor: pointer;
          border-bottom: 2px solid transparent;
          transition: color 0.15s, border-color 0.15s;
        }
        .ov-tab-btn:hover { color: #2c3c5b; }
        .ov-tab-btn.ov-tab-active {
          color: #2c6fdf;
          border-bottom-color: #2c6fdf;
        }
        .ov-tab-pane {
          display: none;
          flex: 1;
          overflow-y: auto;
          padding: 14px;
          box-sizing: border-box;
        }
        .ov-tab-pane.ov-tab-active { display: block; }

        /* Theme overrides for layer-control-panel in app sidebar */
        #ov-layers-mount layer-control-panel {
          --panel-bg-start: #f8fbff;
          --panel-bg-end: #eef3fa;
          --accent-teal: #2c6fdf;
          --accent-ochre: #2c6fdf;
          --label-color: #3a4a68;
          --border-subtle: rgba(18, 34, 62, 0.12);
          --input-bg: rgba(255, 255, 255, 0.7);
          --input-border: rgba(18, 34, 62, 0.15);
          --input-focus: #2c6fdf;
        }

        @media (max-width: 900px) {
          .ov-shell {
            grid-template-columns: 1fr;
            grid-template-rows: minmax(0, auto) minmax(430px, 1fr);
          }
          .ov-sidebar {
            border-right: none;
            border-bottom: 1px solid rgba(18, 34, 62, 0.12);
            max-height: 54vh;
          }
          .ov-main { padding: 10px; }
        }
      ")),
      shiny::tags$script(shiny::HTML("
        $(document).on('click', '.ov-row-clickable', function() {
          var fileId = $(this).data('file-id');
          if (fileId !== undefined) {
            Shiny.setInputValue('table_row_click', String(fileId), {priority: 'event'});
          }
        });
        Shiny.addCustomMessageHandler('ov-toggle-load-btn', function(msg) {
          var btn = document.getElementById('load_file');
          if (btn) { btn.disabled = !!msg.disabled; }
        });
        function ovCopyPath(text, btn) {
          navigator.clipboard.writeText(text).then(function() {
            var orig = btn.textContent;
            btn.textContent = '\\u2713';
            setTimeout(function() { btn.textContent = orig; }, 1200);
          });
        }
        Shiny.addCustomMessageHandler('ov-focus-viewer', function(msg) {
          var el = document.querySelector('.ov-viewer');
          if (el) { el.focus(); }
        });
        function ovSwitchTab(tabName) {
          document.querySelectorAll('.ov-tab-btn').forEach(function(btn) {
            btn.classList.toggle('ov-tab-active', btn.dataset.tab === tabName);
          });
          document.querySelectorAll('.ov-tab-pane').forEach(function(pane) {
            pane.classList.toggle('ov-tab-active', pane.dataset.tab === tabName);
          });
        }
        function ovRelocatePanel() {
          var mount = document.getElementById('ov-layers-mount');
          if (!mount) return;
          var widgetEl = document.getElementById('viewer');
          if (!widgetEl) { setTimeout(ovRelocatePanel, 200); return; }
          var st = widgetEl.__ortho_state__;
          if (!st || !st.panel) { setTimeout(ovRelocatePanel, 200); return; }
          mount.innerHTML = '';
          mount.appendChild(st.panel);
        }
        Shiny.addCustomMessageHandler('ov-relocate-panel', function(msg) {
          ovRelocatePanel();
        });
      "))
    ),
    shiny::div(class = "ov-shell",
      shiny::div(class = "ov-sidebar",
        shiny::div(class = "ov-tabs",
          shiny::tags$button(class = "ov-tab-btn ov-tab-active",
                             `data-tab` = "files",
                             onclick = "ovSwitchTab('files')", "Files"),
          shiny::tags$button(class = "ov-tab-btn",
                             `data-tab` = "layers",
                             onclick = "ovSwitchTab('layers')", "Layers")
        ),
        shiny::div(class = "ov-tab-pane ov-tab-active", `data-tab` = "files",
          shiny::div(class = "ov-card",
            shiny::h3("orthoviewer"),
            shiny::p(class = "ov-subtitle",
              "Discover local NIfTI files, inspect metadata, and load supported volumes."
            ),
            shiny::textInput("scan_path", "Folder", value = initial_path,
                            placeholder = "/path/to/nifti/folder"),
            shiny::checkboxInput("scan_recursive", "Include subfolders",
                                 value = isTRUE(recursive)),
            shiny::actionButton("rescan", "Rescan folder",
                                class = "btn-primary", width = "100%"),
            shiny::uiOutput("scan_summary"),
            shiny::selectInput(
              "scan_filter",
              "Show",
              choices = c(
                "Loadable only" = "loadable",
                "All discovered" = "all",
                "Skipped only" = "skipped"
              ),
              selected = "loadable"
            ),
            shiny::div(class = "ov-filter-help",
              "4D files with \u22653 volumes are skipped.",
              shiny::tags$span(
                title = "Only 3D volumes and 4D files with 1\u20132 volumes can be loaded.",
                style = "cursor: help; text-decoration: underline dotted;",
                "(why?)"
              )
            ),
            shiny::uiOutput("scan_table")
          ),
          shiny::div(class = "ov-connector",
            "\u2193 select from loadable files"
          ),
          shiny::div(class = "ov-card ov-load-card",
            shiny::h4("Load Selected File"),
            shiny::div(class = "ov-load-card-body",
              shiny::selectInput("file_id", "Loadable files", choices = character(0)),
              shiny::uiOutput("file_meta"),
              shiny::uiOutput("volume_selector"),
              shiny::actionButton("load_file", "Load in viewer",
                                  class = "btn-success", width = "100%"),
              shiny::div(class = "ov-load-status", shiny::textOutput("load_status"))
            )
          )
        ),
        shiny::div(class = "ov-tab-pane", `data-tab` = "layers",
          shiny::div(id = "ov-layers-mount")
        )
      ),
      shiny::div(class = "ov-main",
        shiny::div(class = "ov-viewer-shell",
          shiny::div(class = "ov-viewer-banner",
            shiny::uiOutput("loaded_banner_ui", inline = TRUE)
          ),
          shiny::div(class = "ov-viewer",
            ortho_viewerOutput("viewer", height = "100%")
          ),
          shiny::uiOutput("viewer_placeholder")
        )
      )
    )
  )

  server <- function(input, output, session) {
    scan_results <- shiny::reactiveVal(list(
      path = initial_path,
      recursive = isTRUE(recursive),
      elapsed = 0,
      files = .orthoviewer_empty_scan_table()
    ))
    current_volume <- shiny::reactiveVal(NULL)
    load_status <- shiny::reactiveVal("No file loaded.")
    loaded_banner <- shiny::reactiveVal("No file loaded")
    has_scanned <- shiny::reactiveVal(FALSE)

    run_scan <- function(target_path, recursive_flag) {
      target_path <- trimws(target_path)
      if (!nzchar(target_path)) {
        shiny::showNotification("Folder path is empty.", type = "error")
        return(invisible(NULL))
      }
      if (!dir.exists(target_path)) {
        shiny::showNotification(
          sprintf("Folder does not exist: %s", target_path),
          type = "error"
        )
        return(invisible(NULL))
      }

      resolved_path <- normalizePath(target_path, winslash = "/", mustWork = TRUE)
      result <- shiny::withProgress(
        message = "Scanning NIfTI files",
        value = 0,
        {
          .orthoviewer_scan_nifti(
            path = resolved_path,
            recursive = isTRUE(recursive_flag),
            progress = function(i, n, file_path) {
              detail <- sprintf("[%d/%d] %s", i, n, basename(file_path))
              shiny::incProgress(1 / max(n, 1), detail = detail)
            }
          )
        }
      )

      scan_results(result)
      has_scanned(TRUE)

      counts <- .orthoviewer_scan_counts(result$files)
      shiny::showNotification(
        sprintf(
          "Scan complete: %d files, %d loadable, %d skipped.",
          counts$total, counts$eligible, counts$ineligible
        ),
        type = if (counts$eligible > 0L) "message" else "warning",
        duration = 4
      )

      invisible(result)
    }

    session$onFlushed(function() {
      run_scan(initial_path, recursive)
    }, once = TRUE)

    shiny::observeEvent(input$rescan, {
      run_scan(input$scan_path, input$scan_recursive)
    }, ignoreInit = TRUE)

    eligible_files <- shiny::reactive({
      df <- scan_results()$files
      df[df$eligible, , drop = FALSE]
    })

    shiny::observe({
      eligible <- eligible_files()
      if (nrow(eligible) == 0L) {
        shiny::updateSelectInput(
          session,
          "file_id",
          choices = c("-- no loadable files --" = ""),
          selected = ""
        )
        return()
      }

      labels <- sprintf(
        "%s (%s | %s)",
        eligible$rel_path,
        eligible$type_label,
        eligible$dims_label
      )
      values <- as.character(eligible$file_id)
      current <- input$file_id
      selected <- if (!is.null(current) && current %in% values) {
        current
      } else {
        values[[1]]
      }

      shiny::updateSelectInput(
        session,
        "file_id",
        choices = stats::setNames(values, labels),
        selected = selected
      )
    })

    selected_file <- shiny::reactive({
      eligible <- eligible_files()
      if (nrow(eligible) == 0L) {
        return(NULL)
      }

      id_value <- suppressWarnings(as.integer(input$file_id))
      if (!is.finite(id_value)) {
        return(NULL)
      }

      hit <- eligible[eligible$file_id == id_value, , drop = FALSE]
      if (nrow(hit) == 0L) {
        return(NULL)
      }

      hit[1, , drop = FALSE]
    })

    filtered_files <- shiny::reactive({
      df <- scan_results()$files
      if (nrow(df) == 0L) {
        return(df)
      }

      filter_mode <- input$scan_filter
      if (is.null(filter_mode) || identical(filter_mode, "loadable")) {
        return(df[df$eligible, , drop = FALSE])
      }
      if (identical(filter_mode, "skipped")) {
        return(df[!df$eligible, , drop = FALSE])
      }
      df
    })

    output$scan_summary <- shiny::renderUI({
      result <- scan_results()
      counts <- .orthoviewer_scan_counts(result$files)

      shiny::div(class = "ov-summary",
        shiny::div(class = "ov-pills",
          shiny::span(class = "ov-pill ov-pill-total",
                      sprintf("Total %d", counts$total)),
          shiny::span(class = "ov-pill ov-pill-ok",
                      sprintf("Loadable %d", counts$eligible)),
          shiny::span(class = "ov-pill ov-pill-skip",
                      sprintf("Skipped %d", counts$ineligible))
        ),
        shiny::p(class = "ov-scan-meta",
          sprintf("Scan path: %s", result$path),
          if (isTRUE(has_scanned())) {
            shiny::tagList(
              shiny::tags$br(),
              sprintf("Elapsed: %.2fs", result$elapsed)
            )
          }
        )
      )
    })

    output$scan_table <- shiny::renderUI({
      df <- filtered_files()
      all_df <- scan_results()$files
      if (nrow(df) == 0L) {
        if (nrow(all_df) == 0L) {
          return(shiny::div(class = "ov-empty",
            "No NIfTI files found.", shiny::tags$br(),
            "Try enabling 'Include subfolders'."
          ))
        }
        filter_mode <- input$scan_filter
        hint <- if (identical(filter_mode, "loadable")) {
          "No loadable files. Switch to 'All discovered' to see skipped files."
        } else if (identical(filter_mode, "skipped")) {
          "No skipped files. Switch to 'All discovered' to see all files."
        } else {
          "No files match the current filter."
        }
        return(shiny::div(class = "ov-empty", hint))
      }

      shiny::div(class = "ov-table-wrap",
        shiny::tags$table(class = "ov-table", role = "table",
          shiny::tags$thead(
            shiny::tags$tr(role = "row",
              shiny::tags$th("File", scope = "col"),
              shiny::tags$th("Type", scope = "col"),
              shiny::tags$th("Dims", scope = "col"),
              shiny::tags$th("Space", scope = "col"),
              shiny::tags$th("Voxel", scope = "col"),
              shiny::tags$th("Status", scope = "col")
            )
          ),
          shiny::tags$tbody(
            lapply(seq_len(nrow(df)), function(i) {
              row <- df[i, , drop = FALSE]
              is_ok <- isTRUE(row$eligible[[1]])
              status_class <- if (is_ok) {
                "ov-status ov-status-ok"
              } else {
                "ov-status ov-status-skip"
              }
              row_class <- paste(
                if (is_ok) "ov-row-ok" else "ov-row-skip",
                if (is_ok) "ov-row-clickable" else ""
              )

              shiny::tags$tr(
                role = "row",
                class = row_class,
                `data-file-id` = as.character(row$file_id[[1]]),
                shiny::tags$td(role = "cell",
                  shiny::div(class = "ov-file", row$rel_path[[1]]),
                  if (!is_ok && nzchar(row$reason[[1]])) {
                    shiny::div(class = "ov-reason", row$reason[[1]])
                  }
                ),
                shiny::tags$td(role = "cell", row$type_label[[1]]),
                shiny::tags$td(role = "cell", row$dims_label[[1]]),
                shiny::tags$td(role = "cell", row$space_label[[1]]),
                shiny::tags$td(role = "cell", row$spacing_label[[1]]),
                shiny::tags$td(role = "cell",
                  shiny::span(class = status_class, row$status_label[[1]])
                )
              )
            })
          )
        )
      )
    })

    output$file_meta <- shiny::renderUI({
      row <- selected_file()
      if (is.null(row)) {
        return(shiny::div(class = "ov-empty",
          "No loadable files found in this scan."
        ))
      }

      shiny::tagList(
        shiny::div(class = "ov-meta-row",
          shiny::span(class = "ov-meta-label", "File"),
          shiny::span(class = "ov-meta-value", row$name[[1]])
        ),
        shiny::div(class = "ov-meta-row",
          shiny::span(class = "ov-meta-label", "Type"),
          shiny::span(class = "ov-meta-value", row$type_label[[1]])
        ),
        shiny::div(class = "ov-meta-row",
          shiny::span(class = "ov-meta-label", "Dimensions"),
          shiny::span(class = "ov-meta-value", row$dims_label[[1]])
        ),
        shiny::div(class = "ov-meta-row",
          shiny::span(class = "ov-meta-label", "Voxel size (mm)"),
          shiny::span(class = "ov-meta-value", row$spacing_label[[1]])
        ),
        shiny::div(class = "ov-meta-row",
          shiny::span(class = "ov-meta-label", "Space"),
          shiny::span(class = "ov-meta-value", row$space_label[[1]])
        )
      )
    })

    output$volume_selector <- shiny::renderUI({
      row <- selected_file()
      if (is.null(row) || row$nvol[[1]] < 2L) {
        return(NULL)
      }

      shiny::sliderInput(
        "volume_index",
        sprintf("Volume [1 of %d]", row$nvol[[1]]),
        min = 1,
        max = row$nvol[[1]],
        value = 1,
        step = 1,
        width = "100%"
      )
    })

    shiny::observeEvent(input$load_file, {
      row <- selected_file()
      if (is.null(row)) {
        shiny::showNotification("No loadable file selected.", type = "error")
        return()
      }

      vol_index <- 1L
      if (row$nvol[[1]] > 1L) {
        vol_index <- suppressWarnings(as.integer(input$volume_index))
        if (!is.finite(vol_index)) {
          vol_index <- 1L
        }
        vol_index <- max(1L, min(vol_index, row$nvol[[1]]))
      }

      loaded <- shiny::withProgress(
        message = sprintf("Loading %s", row$name[[1]]),
        value = 0,
        {
          shiny::incProgress(0.35, detail = "Reading NIfTI volume")
          vol <- tryCatch(
            neuroim2::read_vol(row$abs_path[[1]], index = vol_index),
            error = function(e) e
          )
          shiny::incProgress(1, detail = "Preparing viewer")
          vol
        }
      )

      if (inherits(loaded, "error")) {
        msg <- conditionMessage(loaded)
        load_status(sprintf("Failed to load %s: %s", row$rel_path[[1]], msg))
        shiny::showNotification(
          sprintf("Failed to load %s: %s", row$rel_path[[1]], msg),
          type = "error",
          duration = 7
        )
        return()
      }

      current_volume(loaded)
      label <- if (row$nvol[[1]] > 1L) {
        sprintf("%s [volume %d/%d]", row$rel_path[[1]], vol_index, row$nvol[[1]])
      } else {
        row$rel_path[[1]]
      }

      loaded_banner(label)
      load_status(sprintf("Loaded %s", label))
      session$sendCustomMessage("ov-focus-viewer", list())
    }, ignoreInit = TRUE)

    shiny::observeEvent(input$table_row_click, {
      file_id <- input$table_row_click
      eligible <- eligible_files()
      if (nrow(eligible) > 0L && file_id %in% as.character(eligible$file_id)) {
        shiny::updateSelectInput(session, "file_id", selected = file_id)
      }
    }, ignoreInit = TRUE)

    shiny::observe({
      eligible <- eligible_files()
      no_selection <- is.null(input$file_id) || !nzchar(input$file_id)
      disabled <- nrow(eligible) == 0L || no_selection
      session$sendCustomMessage("ov-toggle-load-btn", list(disabled = disabled))
    })

    output$load_status <- shiny::renderText(load_status())

    output$loaded_banner_ui <- shiny::renderUI({
      label <- loaded_banner()
      if (identical(label, "No file loaded")) {
        return(shiny::span(class = "ov-banner-empty", label))
      }
      shiny::tagList(
        shiny::span(label),
        shiny::tags$button(
          class = "ov-copy-btn",
          onclick = sprintf("ovCopyPath('%s', this)",
                            gsub("'", "\\\\'", label)),
          "copy"
        )
      )
    })

    output$viewer <- renderOrtho_viewer({
      shiny::req(current_volume())
      ortho_viewer(current_volume(), bg_colormap = "Greys",
                   show_sidebar = FALSE)
    })

    # After the widget renders with a new volume, relocate its
    # layer-control-panel into the app's Layers tab.
    shiny::observe({
      shiny::req(current_volume())
      session$sendCustomMessage("ov-relocate-panel", list())
    })

    output$viewer_placeholder <- shiny::renderUI({
      if (!is.null(current_volume())) {
        return(NULL)
      }
      shiny::div(class = "ov-placeholder",
        "Select a loadable file and click 'Load in viewer'.",
        shiny::tags$br(),
        "Only 3D volumes and 4D files with fewer than 3 volumes are enabled."
      )
    })
  }

  app <- shiny::shinyApp(ui = ui, server = server)

  if (run && interactive()) {
    shiny::runApp(app)
    invisible(app)
  } else {
    app
  }
}


.orthoviewer_scan_nifti <- function(path,
                                    recursive = FALSE,
                                    progress = NULL) {
  scan_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  started <- proc.time()[["elapsed"]]

  files <- list.files(
    path = scan_path,
    pattern = "\\.nii(\\.gz)?$",
    full.names = TRUE,
    recursive = isTRUE(recursive),
    ignore.case = TRUE
  )
  files <- sort(unique(files))
  if (length(files) > 0L) {
    info <- file.info(files)
    files <- files[!is.na(info$isdir) & !info$isdir]
  }

  if (length(files) == 0L) {
    elapsed <- proc.time()[["elapsed"]] - started
    return(list(
      path = scan_path,
      recursive = isTRUE(recursive),
      elapsed = as.numeric(elapsed),
      files = .orthoviewer_empty_scan_table()
    ))
  }

  rows <- vector("list", length(files))
  for (i in seq_along(files)) {
    if (is.function(progress)) {
      progress(i, length(files), files[[i]])
    }
    rows[[i]] <- .orthoviewer_probe_file(
      file_path = files[[i]],
      root_path = scan_path,
      file_id = i
    )
  }

  elapsed <- proc.time()[["elapsed"]] - started

  list(
    path = scan_path,
    recursive = isTRUE(recursive),
    elapsed = as.numeric(elapsed),
    files = do.call(rbind, rows)
  )
}


.orthoviewer_probe_file <- function(file_path,
                                    root_path,
                                    file_id) {
  rel_path <- .orthoviewer_rel_path(file_path, root_path)
  header <- tryCatch(
    neuroim2::read_header(file_path),
    error = function(e) e
  )

  row <- list(
    file_id = as.integer(file_id),
    name = basename(file_path),
    rel_path = rel_path,
    abs_path = normalizePath(file_path, winslash = "/", mustWork = TRUE),
    ndim = NA_integer_,
    nvol = NA_integer_,
    type_label = "unknown",
    dims_label = "-",
    spacing_label = "-",
    space_label = "unspecified",
    eligible = FALSE,
    status_label = "Skipped",
    reason = "",
    has_error = FALSE
  )

  if (inherits(header, "error")) {
    row$has_error <- TRUE
    row$reason <- conditionMessage(header)
    return(as.data.frame(row, stringsAsFactors = FALSE))
  }

  meta <- .orthoviewer_header_metadata(header)
  row$ndim <- meta$ndim
  row$nvol <- meta$nvol
  row$type_label <- meta$type_label
  row$dims_label <- meta$dims_label
  row$spacing_label <- meta$spacing_label
  row$space_label <- meta$space_label
  row$eligible <- meta$eligible
  row$status_label <- if (isTRUE(meta$eligible)) "Loadable" else "Skipped"
  row$reason <- meta$reason

  as.data.frame(row, stringsAsFactors = FALSE)
}


.orthoviewer_header_metadata <- function(header) {
  ## Support both S4 NIFTIMetaInfo objects (from neuroim2::read_header)
  ## and plain lists (used by unit tests / legacy callers).
  is_s4 <- isS4(header)

  if (is_s4) {
    ## S4 path: @dims is a numeric vector of spatial extents (length 3).
    spatial_dims <- suppressWarnings(as.integer(header@dims))
    if (length(spatial_dims) < 3L) {
      spatial_dims <- c(spatial_dims, rep(1L, 3L - length(spatial_dims)))
    }
    spatial_dims[!is.finite(spatial_dims) | spatial_dims < 1L] <- 1L

    nvol <- 1L
    ndim <- length(header@dims)
    add_axes <- tryCatch(header@additional_axes, error = function(e) NULL)
    if (!is.null(add_axes) && methods::is(add_axes, "AxisSet")) {
      add_ndim <- tryCatch(add_axes@ndim, error = function(e) 0L)
      if (is.finite(add_ndim) && add_ndim > 0L) {
        ndim <- 3L + as.integer(add_ndim)
        nvol_raw <- tryCatch(length(add_axes), error = function(e) 1L)
        if (is.finite(nvol_raw) && nvol_raw > 0L) nvol <- as.integer(nvol_raw)
      }
    }

    spacing <- suppressWarnings(as.numeric(header@spacing))
    spacing_label <- if (length(spacing) >= 3L) {
      .orthoviewer_format_spacing(spacing[1:3])
    } else {
      "-"
    }
  } else {
    ## Plain-list path (unit tests / legacy).
    dims <- suppressWarnings(as.integer(header$dimensions))
    if (length(dims) < 8L) {
      dims <- c(dims, rep(1L, 8L - length(dims)))
    }

    ndim <- suppressWarnings(as.integer(header$num_dimensions))
    if (!is.finite(ndim)) ndim <- dims[[1]]

    spatial_dims <- dims[2:4]
    spatial_dims[!is.finite(spatial_dims)] <- 1L
    spatial_dims[spatial_dims < 1L] <- 1L

    nvol <- if (is.finite(ndim) && ndim >= 4L) {
      vol_dim <- dims[[5]]
      if (!is.finite(vol_dim) || vol_dim < 1L) 1L else as.integer(vol_dim)
    } else {
      1L
    }

    spacing <- suppressWarnings(as.numeric(header$pixdim))
    spacing_label <- if (length(spacing) >= 4L) {
      .orthoviewer_format_spacing(spacing[2:4])
    } else {
      "-"
    }
  }

  if (!is.finite(ndim) || ndim < 3L) ndim <- NA_integer_

  dims_label <- if (is.finite(ndim) && ndim >= 4L) {
    sprintf("%d x %d x %d x %d",
            spatial_dims[[1]], spatial_dims[[2]], spatial_dims[[3]], nvol)
  } else {
    sprintf("%d x %d x %d",
            spatial_dims[[1]], spatial_dims[[2]], spatial_dims[[3]])
  }

  type_label <- if (!is.finite(ndim)) {
    "unknown"
  } else if (ndim <= 3L) {
    "3D"
  } else if (ndim == 4L) {
    sprintf("4D (%d vol)", nvol)
  } else {
    sprintf("%dD", ndim)
  }

  eligible <- FALSE
  reason <- ""
  if (!is.finite(ndim) || ndim < 3L) {
    reason <- "Not a volumetric file (need 3D or supported 4D)."
  } else if (ndim == 3L) {
    eligible <- TRUE
  } else if (ndim == 4L && nvol < 3L) {
    eligible <- TRUE
  } else if (ndim == 4L) {
    reason <- sprintf("4D file has %d volumes (need < 3).", nvol)
  } else {
    reason <- sprintf("Unsupported dimensionality: %dD.", ndim)
  }

  list(
    ndim = as.integer(ndim),
    nvol = as.integer(nvol),
    type_label = type_label,
    dims_label = dims_label,
    spacing_label = spacing_label,
    space_label = .orthoviewer_space_label(header),
    eligible = isTRUE(eligible),
    reason = reason
  )
}


.orthoviewer_space_label <- function(header) {
  ## For S4 NIFTIMetaInfo the raw NIfTI fields live in header@header.
  ## For plain lists (unit tests) they live directly on the list.
  if (isS4(header)) {
    raw <- tryCatch(header@header, error = function(e) list())
  } else {
    raw <- header
  }
  sform_code <- suppressWarnings(as.integer(raw$sform_code))
  qform_code <- suppressWarnings(as.integer(raw$qform_code))

  if (is.finite(sform_code) && sform_code > 0L) {
    return(sprintf("sform:%s", .orthoviewer_xform_label(sform_code)))
  }
  if (is.finite(qform_code) && qform_code > 0L) {
    return(sprintf("qform:%s", .orthoviewer_xform_label(qform_code)))
  }
  "unspecified"
}


.orthoviewer_xform_label <- function(code) {
  switch(
    as.character(as.integer(code)),
    "1" = "scanner",
    "2" = "aligned",
    "3" = "talairach",
    "4" = "mni152",
    paste0("code-", as.integer(code))
  )
}


.orthoviewer_rel_path <- function(file_path, root_path) {
  full <- normalizePath(file_path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(root_path, winslash = "/", mustWork = TRUE)

  prefix <- paste0(root, "/")
  if (startsWith(full, prefix)) {
    substring(full, nchar(prefix) + 1L)
  } else {
    basename(full)
  }
}


.orthoviewer_scan_counts <- function(df) {
  total <- nrow(df)
  eligible <- if (total > 0L) sum(df$eligible, na.rm = TRUE) else 0L
  ineligible <- total - eligible
  list(
    total = as.integer(total),
    eligible = as.integer(eligible),
    ineligible = as.integer(ineligible)
  )
}


.orthoviewer_empty_scan_table <- function() {
  data.frame(
    file_id = integer(),
    name = character(),
    rel_path = character(),
    abs_path = character(),
    ndim = integer(),
    nvol = integer(),
    type_label = character(),
    dims_label = character(),
    spacing_label = character(),
    space_label = character(),
    eligible = logical(),
    status_label = character(),
    reason = character(),
    has_error = logical(),
    stringsAsFactors = FALSE
  )
}


.orthoviewer_format_spacing <- function(spacing) {
  xyz <- suppressWarnings(as.numeric(spacing))
  if (length(xyz) < 3L || any(!is.finite(xyz[1:3]))) {
    return("-")
  }
  sprintf("%.2f x %.2f x %.2f", xyz[[1]], xyz[[2]], xyz[[3]])
}
