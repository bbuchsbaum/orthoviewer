# Ortho Viewer Event Handling

Functions for handling interactive events from the ortho_viewer widget
in Shiny applications. The viewer emits several event types that can be
accessed as Shiny inputs.

## Available Events

For a viewer with `outputId = "viewer"`, the following inputs are
available:

- `input$viewer_click`:

  Fired when user clicks on any slice view

- `input$viewer_dblclick`:

  Fired on double-click

- `input$viewer_rightclick`:

  Fired on right-click (context menu)

- `input$viewer_hover`:

  Fired as mouse moves over slices (throttled)

- `input$viewer_crosshair`:

  Fired when crosshair position changes

## Event Data Structure

Each event contains a list with the following components:

- `world`:

  Numeric vector of length 3: world coordinates in mm (x, y, z)

- `voxel`:

  Integer vector of length 3: voxel indices (i, j, k)

- `intensity`:

  Named list of intensity values at the coordinate for each layer

- `view`:

  Character: which view was interacted with ("axial", "coronal", or
  "sagittal")

- `type`:

  Character: event type ("click", "dblclick", "rightclick", "hover",
  "leave")

- `button`:

  Character: mouse button ("left", "right", "middle") - for click events

- `shift`:

  Logical: was Shift key held

- `ctrl`:

  Logical: was Ctrl/Cmd key held

- `alt`:

  Logical: was Alt key held

- `timestamp`:

  Numeric: JavaScript timestamp (milliseconds since epoch)
