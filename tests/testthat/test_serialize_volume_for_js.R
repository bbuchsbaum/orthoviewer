test_that("serialize_volume_for_js works for plain 3D arrays", {
  arr <- array(runif(5 * 6 * 7), dim = c(5, 6, 7))

  spec <- serialize_volume_for_js(arr)

  expect_type(spec, "list")
  expect_equal(spec$dim, dim(arr))
  expect_length(spec$data, length(arr))
  expect_equal(spec$spacing, c(1, 1, 1))
  expect_equal(spec$origin, c(0, 0, 0))
  expect_equal(spec$axes, c("i", "j", "k"))
})

test_that("serialize_volume_for_js uses neuroim2 metadata when available", {
  testthat::skip_if_not_installed("neuroim2")

  arr <- array(runif(4 * 4 * 4), dim = c(4, 4, 4))
  sp <- neuroim2::NeuroSpace(
    dim     = c(4L, 4L, 4L),
    spacing = c(2, 3, 4),
    origin  = c(1, 2, 3)
  )
  vol <- methods::new("DenseNeuroVol", .Data = arr, space = sp)

  spec <- serialize_volume_for_js(vol)

  expect_equal(spec$dim, dim(arr))
  expect_length(spec$data, length(arr))
  expect_equal(spec$spacing, c(2, 3, 4))
  expect_equal(spec$origin, c(1, 2, 3))
  expect_length(spec$axes, 3L)
})

