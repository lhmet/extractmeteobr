# extractmeteobr 0.1.0

First public release.

* Aggregate daily BR-DWGD NetCDF files into monthly rasters and process
  meteorological data over Brazilian municipalities and other polygons.
* Calculate exact-intersection, physical-area-weighted spatial means using
  reusable polygon-cell weights and sparse matrices. Exclude missing values
  from both numerator and denominator; return NA for zero available weight.
* Load IBGE municipality polygons with lowercase state and region attributes.
* Select the pipeline reference raster from the first requested variable;
  avoid reference-file reading when the target CRS is supplied explicitly.
* Select polygon attributes with `attribute_cols` when joining means and
  writing FST files. Validate polygon identifiers and their correspondence
  with the means. Derive geographic filename suffixes from polygon metadata.
* Support interactive maps with tmap 4.0 and later.
* Document the IBGE 2022 and BR-DWGD data sources and download locations.
* Add synthetic numerical, geographic attribute, identifier validation,
  interactive map, and complete pipeline variable/CRS regression tests.
* Require R 4.1.0 or later and use `funique::funique()` for unique values.

## Interface notes

* `attribute_cols` replaces the former `state_col` and `region` arguments in
  `join_and_write_municipal_means()`.
* Municipality outputs now include a `region` column. A complete Brazilian
  region uses its name as the filename suffix, including when its states
  are supplied individually; partial selections use sorted state codes.
* Raw IBGE and BR-DWGD inputs are external and are not distributed with
  the package. Local agent skills are excluded from the current repository
  tree and package archive.
