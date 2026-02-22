# Serialize a 3D volume for use in neuroimjs

This function converts an R array or a `neuroim2` volume into a plain
list that can be JSON-encoded and consumed by the JavaScript viewer. For
now the implementation is intentionally minimal and assumes a 3D numeric
array. Integration with `neuroim2` objects will be added once the JS
side is fully wired.

## Usage

``` r
serialize_volume_for_js(vol)
```

## Arguments

- vol:

  A 3D numeric array or a compatible object. If the object comes from
  `neuroim2` (e.g., a `DenseNeuroVol`), spatial metadata (spacing,
  origin, axes) will be extracted when possible.

## Value

A list with `dim`, `data`, and placeholders for spatial metadata.
