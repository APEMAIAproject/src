param(
    [string]$Image = "ghcr.io/apemaiaproject/pms-prediction:latest",
    [switch]$Pull
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$example = Join-Path $root "examples\test.data.csv.gz"
$out = Join-Path $root "output\example_test"
$runner = Join-Path $root "run_docker.ps1"

if (-not (Test-Path -LiteralPath $example)) {
    throw "Bundled example dataset not found: $example"
}

if ($Pull) {
    & $runner -InputCsv $example -Image $Image -OutputDir $out -Pull
} else {
    & $runner -InputCsv $example -Image $Image -OutputDir $out
}

$required = @(
    "predictions.csv",
    "predictions_puglia.gpkg",
    "predictions_bari.gpkg",
    "PM2.5_Puglia.png",
    "PM10_Puglia.png",
    "PM2.5_Bari.png",
    "PM10_Bari.png",
    "run_metadata.txt",
    "sessionInfo.txt"
)

$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $out $_)) })
if ($missing.Count -gt 0) {
    throw "Quick test finished but expected outputs are missing: $($missing -join ', ')"
}

Write-Host "Quick test PASSED. All expected outputs are present in: $out"
