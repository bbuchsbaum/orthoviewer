test_that("ortho_proxy sends well-formed messages", {
  fake_session <- new.env(parent = emptyenv())
  fake_session$messages <- list()
  fake_session$sendCustomMessage <- function(type, message) {
    fake_session$messages[[length(fake_session$messages) + 1L]] <<- list(
      type = type,
      message = message
    )
  }

  p <- ortho_proxy("brain_viewer", session = fake_session)

  arr <- array(rnorm(4 * 4 * 4), dim = c(4, 4, 4))
  p$add_layer(arr, thresh = c(-1, 1), colormap = "viridis", opacity = 0.5)
  p$set_window(c(0, 1))

  msgs <- fake_session$messages
  expect_gte(length(msgs), 2L)

  add_msg <- msgs[[1L]]$message
  expect_equal(add_msg$type, "add-layer")
  expect_equal(add_msg$id, "brain_viewer")
  expect_equal(add_msg$threshold, c(-1, 1))
  expect_equal(add_msg$colormap, "viridis")
  expect_equal(add_msg$opacity, 0.5)
  expect_equal(add_msg$volume$dim, dim(arr))

  win_msg <- msgs[[2L]]$message
  expect_equal(win_msg$type, "set-window")
  expect_equal(win_msg$id, "brain_viewer")
  expect_equal(win_msg$range, c(0, 1))
})

