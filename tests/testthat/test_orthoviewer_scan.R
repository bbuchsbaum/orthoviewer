test_that("header metadata marks supported dimensionalities as loadable", {
  hdr_3d <- list(
    dimensions = c(3L, 64L, 64L, 36L, 1L, 1L, 1L, 1L),
    num_dimensions = 3L,
    pixdim = c(1, 2, 2, 2, 0, 0, 0, 0),
    sform_code = 4L,
    qform_code = 0L
  )

  meta_3d <- orthoviewer:::.orthoviewer_header_metadata(hdr_3d)
  expect_true(meta_3d$eligible)
  expect_equal(meta_3d$type_label, "3D")
  expect_equal(meta_3d$nvol, 1L)
  expect_equal(meta_3d$dims_label, "64 x 64 x 36")
  expect_equal(meta_3d$spacing_label, "2.00 x 2.00 x 2.00")
  expect_equal(meta_3d$space_label, "sform:mni152")

  hdr_4d <- list(
    dimensions = c(4L, 96L, 96L, 60L, 2L, 1L, 1L, 1L),
    num_dimensions = 4L,
    pixdim = c(1, 1.5, 1.5, 2.5, 0, 0, 0, 0),
    sform_code = 0L,
    qform_code = 1L
  )

  meta_4d <- orthoviewer:::.orthoviewer_header_metadata(hdr_4d)
  expect_true(meta_4d$eligible)
  expect_equal(meta_4d$type_label, "4D (2 vol)")
  expect_equal(meta_4d$nvol, 2L)
  expect_equal(meta_4d$dims_label, "96 x 96 x 60 x 2")
  expect_equal(meta_4d$space_label, "qform:scanner")
})

test_that("header metadata rejects unsupported dimensionalities", {
  hdr_many_volumes <- list(
    dimensions = c(4L, 64L, 64L, 40L, 3L, 1L, 1L, 1L),
    num_dimensions = 4L,
    pixdim = c(1, 2, 2, 2, 0, 0, 0, 0),
    sform_code = 2L,
    qform_code = 0L
  )

  meta_many <- orthoviewer:::.orthoviewer_header_metadata(hdr_many_volumes)
  expect_false(meta_many$eligible)
  expect_match(meta_many$reason, "need < 3")

  hdr_5d <- list(
    dimensions = c(5L, 64L, 64L, 40L, 2L, 2L, 1L, 1L),
    num_dimensions = 5L,
    pixdim = c(1, 2, 2, 2, 0, 0, 0, 0),
    sform_code = 0L,
    qform_code = 0L
  )

  meta_5d <- orthoviewer:::.orthoviewer_header_metadata(hdr_5d)
  expect_false(meta_5d$eligible)
  expect_match(meta_5d$reason, "Unsupported dimensionality")
})

test_that("scan helper returns an empty table when no NIfTI files are present", {
  scan_dir <- tempfile("orthoviewer_scan_")
  dir.create(scan_dir)

  result <- orthoviewer:::.orthoviewer_scan_nifti(scan_dir, recursive = FALSE)
  expect_equal(nrow(result$files), 0L)
  expect_equal(result$path, normalizePath(scan_dir, winslash = "/", mustWork = TRUE))
})
