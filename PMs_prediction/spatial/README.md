# Embedded spatial reference grids

The Docker image uses two fixed reference grids. They are stored compressed in the Git repository and expanded during `docker build`.

| Archive | Uncompressed content | Rows/geometries | Identifier | CRS | Nominal resolution |
|---|---|---:|---|---|---|
| `grid_puglia_minimal.gpkg.zip` | `grid_puglia_minimal.gpkg` | 219,832 | `source_FID`, unique | EPSG:32632 | 300 m |
| `grid_bari_minimal.gpkg.zip` | `grid_bari_minimal.gpkg` | 1,932 | `source_FID`, 1,875 unique | EPSG:32632 | 300 m |

Only the identifier and geometry are retained. All static and environmental covariates from the original shapefiles were removed because inference reads those variables from the preprocessed CSV, not from the spatial grid.

The Bari grid contains 57 repeated source identifiers because some Puglia source cells are represented by more than one clipped Bari geometry. This is expected; all pieces sharing a `source_FID` receive the same prediction.

To extract a grid manually, unzip the corresponding archive with any standard ZIP utility.
