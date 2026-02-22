##' Run a minimal orthoviewer Shiny example
##'
##' This launches a small Shiny app that demonstrates the
##' \code{ortho_viewer()} widget and the \code{ortho_proxy()} API using
##' synthetic background and overlay volumes.
##'
##' @return A Shiny app object, invisibly.
##' @importFrom stats rnorm
##' @export
orthoviewer_example_app <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to run the example app.",
         call. = FALSE)
  }
  ## Simple volumes for demonstration. If neuroim2 is available, use a
  ## DenseNeuroVol to exercise the serializer; otherwise fall back to
  ## plain arrays.
  if (requireNamespace("neuroim2", quietly = TRUE)) {
    arr_bg <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    arr_stat <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    sp <- neuroim2::NeuroSpace(
      dim     = c(64L, 64L, 64L),
      spacing = c(2, 2, 2),
      origin  = c(0, 0, 0)
    )
    bg <- methods::new("DenseNeuroVol", .Data = arr_bg, space = sp)
    stat <- methods::new("DenseNeuroVol", .Data = arr_stat, space = sp)
  } else {
    bg <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    stat <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
  }

  ui <- shiny::fluidPage(
    shiny::tags$style("html, body { height: 100%; }"),
    ortho_viewerOutput("brain_viewer", height = "700px")
  )

  server <- function(input, output, session) {
    output$brain_viewer <- renderOrtho_viewer({
      ortho_viewer(bg, bg_colormap = "Greys")
    })

    session$onFlushed(function() {
      p <- ortho_proxy("brain_viewer", session)
      p$add_layer(stat, id = "stat_map", thresh = c(-2, 2), colormap = "viridis")
    }, once = TRUE)
  }

  app <- shiny::shinyApp(ui, server)
  if (interactive()) {
    shiny::runApp(app)
    invisible(app)
  } else {
    app
  }
}


##' Run an interactive orthoviewer example with click handling
##'
##' This launches a Shiny app that demonstrates the click event handling
##' capabilities of ortho_viewer. It displays click coordinates, intensity
##' values, and other event information in real-time.
##'
##' @return A Shiny app object, invisibly.
##' @export
##' @examples
##' \dontrun{
##' orthoviewer_click_example()
##' }
orthoviewer_click_example <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to run the example app.",
         call. = FALSE)
  }

  ## Create synthetic volumes
  if (requireNamespace("neuroim2", quietly = TRUE)) {
    arr_bg <- array(rnorm(64 * 64 * 64, mean = 500, sd = 100), dim = c(64, 64, 64))
    arr_stat <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    sp <- neuroim2::NeuroSpace(
      dim     = c(64L, 64L, 64L),
      spacing = c(2, 2, 2),
      origin  = c(-64, -64, -64)
    )
    bg <- methods::new("DenseNeuroVol", .Data = arr_bg, space = sp)
    stat <- methods::new("DenseNeuroVol", .Data = arr_stat, space = sp)
  } else {
    bg <- array(rnorm(64 * 64 * 64, mean = 500, sd = 100), dim = c(64, 64, 64))
    stat <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
  }

  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$style(shiny::HTML("
        html, body { height: 100%; margin: 0; background: #edf1f8; }
        .container-fluid { padding: 0; }
        .main-container {
          display: grid;
          grid-template-columns: minmax(0, 1fr) 340px;
          height: 100vh;
          gap: 0;
          background: radial-gradient(circle at top left, #f8fbff 0%, #edf1f8 55%, #e8edf6 100%);
        }
        .viewer-panel {
          min-width: 0;
          padding: 18px;
          box-sizing: border-box;
        }
        .info-panel {
          padding: 16px;
          background: linear-gradient(180deg, #f8faff 0%, #eef3fb 100%);
          border-left: 1px solid rgba(21, 31, 56, 0.1);
          overflow-y: auto;
        }
        .info-section {
          margin-bottom: 14px;
          padding: 12px 12px 10px;
          background: rgba(255, 255, 255, 0.9);
          border: 1px solid rgba(21, 31, 56, 0.08);
          border-radius: 10px;
          box-shadow: 0 10px 24px -20px rgba(8, 20, 48, 0.45);
        }
        .info-section h4 {
          margin: 0 0 10px 0;
          color: #1f2b43;
          font-size: 12px;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          font-weight: 700;
          border-bottom: 1px solid rgba(21, 31, 56, 0.08);
          padding-bottom: 8px;
        }
        .info-row {
          display: flex;
          justify-content: space-between;
          gap: 10px;
          margin: 4px 0;
          font-size: 12px;
        }
        .info-label { color: #5e6c89; }
        .info-value {
          font-family: 'JetBrains Mono', 'SF Mono', 'Consolas', monospace;
          color: #1b2436;
          text-align: right;
          word-break: break-word;
        }
        .click-history {
          max-height: 230px;
          overflow-y: auto;
          font-size: 11px;
          font-family: 'JetBrains Mono', 'SF Mono', 'Consolas', monospace;
        }
        .click-history-item {
          padding: 7px 0;
          border-bottom: 1px solid rgba(21, 31, 56, 0.08);
          color: #2e3c58;
        }
        @media (max-width: 980px) {
          .main-container {
            grid-template-columns: 1fr;
            grid-template-rows: minmax(420px, 52vh) minmax(0, 1fr);
          }
          .viewer-panel { padding: 10px; }
          .info-panel { border-left: none; border-top: 1px solid rgba(21, 31, 56, 0.1); }
        }
      "))
    ),
    shiny::div(class = "main-container",
      shiny::div(class = "viewer-panel",
        ortho_viewerOutput("viewer", height = "100%")
      ),
      shiny::div(class = "info-panel",
        shiny::div(class = "info-section",
          shiny::h4("Last Click"),
          shiny::uiOutput("click_info")
        ),
        shiny::div(class = "info-section",
          shiny::h4("Current Hover"),
          shiny::uiOutput("hover_info")
        ),
        shiny::div(class = "info-section",
          shiny::h4("Crosshair Position"),
          shiny::uiOutput("crosshair_info")
        ),
        shiny::div(class = "info-section",
          shiny::h4("Click History"),
          shiny::div(class = "click-history",
            shiny::uiOutput("click_history")
          )
        )
      )
    )
  )

  server <- function(input, output, session) {
    # Render the viewer
    output$viewer <- renderOrtho_viewer({
      ortho_viewer(bg, bg_colormap = "Greys")
    })

    # Add overlay layer once after initial render
    session$onFlushed(function() {
      p <- ortho_proxy("viewer", session)
      p$add_layer(stat, id = "stat_map", thresh = c(-2, 2), colormap = "viridis")
    }, once = TRUE)

    # Store click history
    click_history <- shiny::reactiveVal(list())

    # Handle click events
    shiny::observeEvent(input$viewer_click, {
      click <- ortho_event(input, "viewer", "click")
      if (!is.null(click)) {
        history <- click_history()
        history <- c(list(click), history)
        if (length(history) > 10) history <- history[1:10]
        click_history(history)
      }
    })

    # Display click info
    output$click_info <- shiny::renderUI({
      click <- ortho_event(input, "viewer", "click")
      if (is.null(click)) {
        return(shiny::div(class = "info-row",
          shiny::span(class = "info-value", "Click on the viewer...")
        ))
      }

      world <- ortho_world(click)
      voxel <- ortho_voxel(click)
      intensity <- ortho_intensity(click)

      shiny::tagList(
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "View:"),
          shiny::span(class = "info-value", click$view %||% "-")
        ),
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "World:"),
          shiny::span(class = "info-value", .fmt_world_vec(world))
        ),
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "Anatomical:"),
          shiny::span(class = "info-value", format_world_coord(world))
        ),
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "Voxel:"),
          shiny::span(class = "info-value", .fmt_voxel_vec(voxel))
        ),
        if (length(intensity) > 0) {
          shiny::tagList(
            lapply(names(intensity), function(nm) {
              shiny::div(class = "info-row",
                shiny::span(class = "info-label", paste0(nm, ":")),
                shiny::span(class = "info-value", sprintf("%.2f", intensity[nm]))
              )
            })
          )
        }
      )
    })

    # Display hover info
    output$hover_info <- shiny::renderUI({
      hover <- ortho_event(input, "viewer", "hover")
      if (is.null(hover) || hover$type == "leave") {
        return(shiny::div(class = "info-row",
          shiny::span(class = "info-value", "Mouse not over viewer")
        ))
      }

      world <- ortho_world(hover)
      shiny::tagList(
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "View:"),
          shiny::span(class = "info-value", hover$view %||% "-")
        ),
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "World:"),
          shiny::span(class = "info-value", .fmt_world_vec(world))
        )
      )
    })

    # Display crosshair info
    output$crosshair_info <- shiny::renderUI({
      crosshair <- ortho_event(input, "viewer", "crosshair")
      if (is.null(crosshair)) {
        return(shiny::div(class = "info-row",
          shiny::span(class = "info-value", "Waiting for crosshair...")
        ))
      }

      world <- ortho_world(crosshair)
      voxel <- ortho_voxel(crosshair)

      shiny::tagList(
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "World:"),
          shiny::span(class = "info-value", .fmt_world_vec(world))
        ),
        shiny::div(class = "info-row",
          shiny::span(class = "info-label", "Voxel:"),
          shiny::span(class = "info-value", .fmt_voxel_vec(voxel))
        )
      )
    })

    # Display click history
    output$click_history <- shiny::renderUI({
      history <- click_history()
      if (length(history) == 0) {
        return(shiny::div("No clicks yet"))
      }

      shiny::tagList(
        lapply(seq_along(history), function(i) {
          click <- history[[i]]
          world <- ortho_world(click)
          shiny::div(class = "click-history-item",
            sprintf("#%d: %s %s",
                    i, click$view %||% "?",
                    .fmt_world_vec(world, digits = 0))
          )
        })
      )
    })
  }

  app <- shiny::shinyApp(ui, server)
  if (interactive()) {
    shiny::runApp(app)
    invisible(app)
  } else {
    app
  }
}

# Internal helper
`%||%` <- function(a, b) if (is.null(a)) b else a

# Internal formatting helpers for example apps
.fmt_world_vec <- function(world, digits = 1) {
  if (is.null(world) || length(world) < 3) return("-")
  world <- suppressWarnings(as.numeric(world[1:3]))
  if (any(!is.finite(world))) return("-")
  fmt <- paste0("[%.", digits, "f, %.", digits, "f, %.", digits, "f]")
  sprintf(fmt, world[1], world[2], world[3])
}

.fmt_voxel_vec <- function(voxel) {
  if (is.null(voxel) || length(voxel) < 3) return("-")
  voxel <- suppressWarnings(as.integer(voxel[1:3]))
  if (any(is.na(voxel))) return("-")
  sprintf("[%d, %d, %d]", voxel[1], voxel[2], voxel[3])
}


##' Run an interactive orthoviewer example with navigation controls
##'
##' This launches a Shiny app that demonstrates the crosshair navigation
##' and layer control capabilities of ortho_viewer. It shows how to use
##' set_crosshair(), show_layer(), hide_layer(), and set_layer_order().
##'
##' @return A Shiny app object, invisibly.
##' @export
##' @examples
##' \dontrun{
##' orthoviewer_navigation_example()
##' }
orthoviewer_navigation_example <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to run the example app.",
         call. = FALSE)
  }

  ## Create synthetic volumes
  if (requireNamespace("neuroim2", quietly = TRUE)) {
    arr_bg <- array(rnorm(64 * 64 * 64, mean = 500, sd = 100), dim = c(64, 64, 64))
    arr_stat1 <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    arr_stat2 <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    sp <- neuroim2::NeuroSpace(
      dim     = c(64L, 64L, 64L),
      spacing = c(2, 2, 2),
      origin  = c(-64, -64, -64)
    )
    bg <- methods::new("DenseNeuroVol", .Data = arr_bg, space = sp)
    stat1 <- methods::new("DenseNeuroVol", .Data = arr_stat1, space = sp)
    stat2 <- methods::new("DenseNeuroVol", .Data = arr_stat2, space = sp)
  } else {
    bg <- array(rnorm(64 * 64 * 64, mean = 500, sd = 100), dim = c(64, 64, 64))
    stat1 <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
    stat2 <- array(rnorm(64 * 64 * 64, mean = 0, sd = 1), dim = c(64, 64, 64))
  }

  # Predefined coordinates of interest
  landmarks <- list(
    "Center" = c(0, 0, 0),
    "Anterior" = c(0, 40, 0),
    "Posterior" = c(0, -40, 0),
    "Left" = c(-40, 0, 0),
    "Right" = c(40, 0, 0),
    "Superior" = c(0, 0, 40),
    "Inferior" = c(0, 0, -40)
  )

  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$style(shiny::HTML("
        html, body { height: 100%; margin: 0; background: #edf1f8; }
        .container-fluid { padding: 0; }
        .main-container {
          display: grid;
          grid-template-columns: minmax(0, 1fr) 320px;
          height: 100vh;
          background: radial-gradient(circle at top left, #f8fbff 0%, #edf1f8 55%, #e8edf6 100%);
        }
        .viewer-panel {
          min-width: 0;
          padding: 18px;
          box-sizing: border-box;
        }
        .control-panel {
          padding: 16px;
          background: linear-gradient(180deg, #f8faff 0%, #eef3fb 100%);
          border-left: 1px solid rgba(21, 31, 56, 0.1);
          overflow-y: auto;
        }
        .control-section {
          margin-bottom: 12px;
          padding: 12px;
          background: rgba(255, 255, 255, 0.9);
          border: 1px solid rgba(21, 31, 56, 0.08);
          border-radius: 10px;
          box-shadow: 0 10px 24px -20px rgba(8, 20, 48, 0.45);
        }
        .control-section h4 {
          margin: 0 0 10px 0;
          color: #1f2b43;
          font-size: 12px;
          letter-spacing: 0.08em;
          text-transform: uppercase;
          font-weight: 700;
          border-bottom: 1px solid rgba(21, 31, 56, 0.08);
          padding-bottom: 8px;
        }
        .btn-nav {
          margin-top: 6px;
          width: 100%;
          border-radius: 8px;
          background: linear-gradient(135deg, #1685f8 0%, #5f9dff 100%);
          border: none;
        }
        .layer-control {
          padding: 6px 0;
          border-bottom: 1px solid rgba(21, 31, 56, 0.08);
        }
        .layer-control:last-child { border-bottom: none; }
        .form-group { margin-bottom: 10px; }
        .control-panel .radio { margin-top: 0; margin-bottom: 6px; }
        @media (max-width: 1080px) {
          .main-container {
            grid-template-columns: 1fr;
            grid-template-rows: minmax(430px, 52vh) minmax(0, 1fr);
          }
          .viewer-panel { padding: 10px; }
          .control-panel { border-left: none; border-top: 1px solid rgba(21, 31, 56, 0.1); }
        }
      "))
    ),
    shiny::div(class = "main-container",
      shiny::div(class = "viewer-panel",
        ortho_viewerOutput("viewer", height = "100%")
      ),
      shiny::div(class = "control-panel",
        shiny::div(class = "control-section",
          shiny::h4("Navigate to Landmark"),
          shiny::selectInput("landmark", NULL,
            choices = names(landmarks),
            selected = "Center"
          ),
          shiny::checkboxInput("animate", "Animate transition", value = TRUE),
          shiny::sliderInput("duration", "Duration (ms)",
            min = 100, max = 2000, value = 500, step = 100
          ),
          shiny::actionButton("go_landmark", "Go", class = "btn-primary btn-nav")
        ),
        shiny::div(class = "control-section",
          shiny::h4("Manual Coordinates"),
          shiny::numericInput("coord_x", "X (mm)", value = 0, step = 5),
          shiny::numericInput("coord_y", "Y (mm)", value = 0, step = 5),
          shiny::numericInput("coord_z", "Z (mm)", value = 0, step = 5),
          shiny::actionButton("go_coords", "Go to Coordinates", class = "btn-primary btn-nav")
        ),
        shiny::div(class = "control-section",
          shiny::h4("Layer Controls"),
          shiny::div(class = "layer-control",
            shiny::span("Layer 1 (viridis)"),
            shiny::checkboxInput("layer1_visible", "Visible", value = TRUE)
          ),
          shiny::div(class = "layer-control",
            shiny::span("Opacity"),
            shiny::sliderInput("layer1_opacity", NULL,
              min = 0, max = 1, value = 1, step = 0.1,
              width = "100%"
            )
          ),
          shiny::div(class = "layer-control",
            shiny::span("Layer 2 (hot)"),
            shiny::checkboxInput("layer2_visible", "Visible", value = TRUE)
          ),
          shiny::div(class = "layer-control",
            shiny::span("Opacity"),
            shiny::sliderInput("layer2_opacity", NULL,
              min = 0, max = 1, value = 1, step = 0.1,
              width = "100%"
            )
          )
        ),
        shiny::div(class = "control-section",
          shiny::h4("Layer Order"),
          shiny::radioButtons("layer_order", NULL,
            choices = c(
              "Layer 1 on top" = "layer1_top",
              "Layer 2 on top" = "layer2_top"
            ),
            selected = "layer2_top"
          )
        ),
        shiny::div(class = "control-section",
          shiny::h4("Current Position"),
          shiny::verbatimTextOutput("current_pos")
        )
      )
    )
  )

  server <- function(input, output, session) {
    # Render the viewer
    output$viewer <- renderOrtho_viewer({
      ortho_viewer(bg, bg_colormap = "Greys")
    })

    # Add overlay layers once after initial render
    session$onFlushed(function() {
      p <- ortho_proxy("viewer", session)
      p$add_layer(stat1, id = "layer1", thresh = c(-2, 2), colormap = "viridis", opacity = 1)
      p$add_layer(stat2, id = "layer2", thresh = c(-2, 2), colormap = "hot", opacity = 1)
    }, once = TRUE)

    # Navigate to landmark
    shiny::observeEvent(input$go_landmark, {
      coord <- landmarks[[input$landmark]]
      p <- ortho_proxy("viewer", session)
      p$set_crosshair(coord, animate = input$animate, duration = input$duration)
    })

    # Navigate to manual coordinates
    shiny::observeEvent(input$go_coords, {
      coord <- c(input$coord_x, input$coord_y, input$coord_z)
      p <- ortho_proxy("viewer", session)
      p$set_crosshair(coord, animate = input$animate, duration = input$duration)
    })

    # Layer 1 visibility
    shiny::observeEvent(input$layer1_visible, {
      p <- ortho_proxy("viewer", session)
      p$set_layer_visible("layer1", input$layer1_visible)
    }, ignoreInit = TRUE)

    # Layer 2 visibility
    shiny::observeEvent(input$layer2_visible, {
      p <- ortho_proxy("viewer", session)
      p$set_layer_visible("layer2", input$layer2_visible)
    }, ignoreInit = TRUE)

    # Layer 1 opacity
    shiny::observeEvent(input$layer1_opacity, {
      p <- ortho_proxy("viewer", session)
      p$set_opacity(input$layer1_opacity, layer_id = "layer1")
    }, ignoreInit = TRUE)

    # Layer 2 opacity
    shiny::observeEvent(input$layer2_opacity, {
      p <- ortho_proxy("viewer", session)
      p$set_opacity(input$layer2_opacity, layer_id = "layer2")
    }, ignoreInit = TRUE)

    # Layer order
    shiny::observeEvent(input$layer_order, {
      p <- ortho_proxy("viewer", session)
      if (input$layer_order == "layer1_top") {
        p$set_layer_order(c("background", "layer2", "layer1"))
      } else {
        p$set_layer_order(c("background", "layer1", "layer2"))
      }
    }, ignoreInit = TRUE)

    # Display current position from crosshair events
    output$current_pos <- shiny::renderText({
      crosshair <- ortho_event(input, "viewer", "crosshair")
      if (is.null(crosshair)) return("Waiting...")

      world <- ortho_world(crosshair)
      voxel <- ortho_voxel(crosshair)

      sprintf("World: %s\nVoxel: %s",
              .fmt_world_vec(world),
              .fmt_voxel_vec(voxel))
    })
  }

  app <- shiny::shinyApp(ui, server)
  if (interactive()) {
    shiny::runApp(app)
    invisible(app)
  } else {
    app
  }
}
