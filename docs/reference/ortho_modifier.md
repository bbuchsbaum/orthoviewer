# Check if a modifier key was held during an event

Check if a modifier key was held during an event

## Usage

``` r
ortho_modifier(event, key = "shift")
```

## Arguments

- event:

  An ortho_event object or the raw input value.

- key:

  Character: which modifier key to check. One of "shift", "ctrl", or
  "alt".

## Value

Logical indicating whether the key was held, or FALSE if event is NULL.
