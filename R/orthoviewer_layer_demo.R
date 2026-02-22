##' Internal layering demo app
##'
##' This launches a small Shiny app that is intended primarily as a
##' developer-facing test of multi-layer behaviour: background anatomy,
##' two overlay layers with distinct thresholds, colormaps and opacity,
##' and interaction via the JavaScript control panel.
##'
##' @keywords internal
orthoviewer_layer_demo <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("The 'shiny' package is required to run the layering demo.",
         call. = FALSE)
  }

  ## Construct a simple, interpretable 64^3 background volume:
  ## a smooth radial gradient from centre to periphery.
  make_background <- function(dim = c(64L, 64L, 64L)) {
    nx <- dim[1]; ny <- dim[2]; nz <- dim[3]
    x <- seq(-1, 1, length.out = nx)
    y <- seq(-1, 1, length.out = ny)
    z <- seq(-1, 1, length.out = nz)
    g <- array(0, dim = dim)
    for (i in seq_len(nx)) {
      for (j in seq_len(ny)) {
        for (k in seq_len(nz)) {
          r2 <- x[i]^2 + y[j]^2 + z[k]^2
          g[i, j, k] <- exp(-4 * r2)
        }
      }
    }
    g
  }

  ## Two overlays: a positive and a negative Gaussian blob at different
  ## locations, plus low-level noise.
  make_blob <- function(dim = c(64L, 64L, 64L),
                        centre = c(0, 0, 0),
                        sign = 1) {
    nx <- dim[1]; ny <- dim[2]; nz <- dim[3]
    x <- seq(-1, 1, length.out = nx)
    y <- seq(-1, 1, length.out = ny)
    z <- seq(-1, 1, length.out = nz)
    arr <- array(rnorm(nx * ny * nz, sd = 0.15), dim = dim)
    for (i in seq_len(nx)) {
      for (j in seq_len(ny)) {
        for (k in seq_len(nz)) {
          dx <- x[i] - centre[1]
          dy <- y[j] - centre[2]
          dz <- z[k] - centre[3]
          r2 <- dx^2 + dy^2 + dz^2
          arr[i, j, k] <- arr[i, j, k] + sign * 3 * exp(-30 * r2)
        }
      }
    }
    arr
  }

  dim3 <- c(64L, 64L, 64L)
  bg   <- make_background(dim3)
  stat1 <- make_blob(dim3, centre = c(-0.3, -0.2, 0.1), sign = 1)
  stat2 <- make_blob(dim3, centre = c(0.3, 0.2, -0.1), sign = -1)

  ui <- shiny::fluidPage(
    shiny::tags$style("html, body { height: 100%; margin: 0; }"),
    ortho_viewerOutput("viewer", height = "700px")
  )

  server <- function(input, output, session) {
    output$viewer <- renderOrtho_viewer({
      ortho_viewer(bg, bg_colormap = "Greys")
    })

    ## Add overlay layers once the viewer widget has rendered.
    ## We use session$onFlushed to ensure the initial widget render
    ## has been sent to the client before we send proxy commands.
    session$onFlushed(function() {
      p <- ortho_proxy("viewer", session)

      ## Positive blob: show high positive values.
      p$add_layer(
        stat1,
        id       = "stat_pos",
        thresh   = c(1.5, 5),
        range    = c(-2, 5),
        colormap = "Reds",
        opacity  = 0.9
      )

      ## Negative blob: show strong negative values with a different colormap.
      p$add_layer(
        stat2,
        id       = "stat_neg",
        thresh   = c(-5, -1.5),
        range    = c(-5, 2),
        colormap = "Blues",
        opacity  = 0.7
      )
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
