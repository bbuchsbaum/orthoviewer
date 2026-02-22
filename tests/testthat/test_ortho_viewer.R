test_that("ortho_viewer creates an htmlwidget with expected payload", {
  arr <- array(rnorm(8 * 8 * 8), dim = c(8, 8, 8))

  w <- ortho_viewer(arr, bg_colormap = "Greys")

  expect_s3_class(w, "htmlwidget")
  expect_true(!is.null(w$x$bg_volume))
  expect_equal(w$x$bg_colormap, "Greys")
  expect_equal(w$x$bg_volume$dim, dim(arr))
})

