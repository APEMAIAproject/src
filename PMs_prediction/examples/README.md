# Bundled inference test dataset

`test.data.csv.gz` is a compressed full-grid inference example supplied with this deployment.

- date: **2019-02-28**;
- spatial domain: full Puglia reference grid;
- rows: **219,832** data rows;
- predictors: the same **26 already-preprocessed model features** documented in the main README;
- grid identifier: one `FID` per Puglia cell;
- compression: gzip (`.csv.gz`); the container reads it directly, so manual decompression is not required.

The CSV also contains the original leading row-number column. The inference script intentionally ignores this common export-index field.

## Run the example

With a locally built image:

```powershell
.\build_local.ps1
.\quick_test.ps1 -Image "pms-prediction:local"
```

With the published GHCR image:

```powershell
.\quick_test.ps1 -Pull
```

A successful quick test creates `output/example_test/` and checks that all nine documented output files are present.

## Redistribution note

This example is included to make the container reproducible and immediately testable. Before making the repository public, the project maintainers should ensure that redistribution of the derived input variables is compatible with the licences/terms of their upstream data sources.
