param(
    [string]$Image = "ghcr.io/apemaiaproject/pms-prediction-intra-urban:latest",
    [switch]$Pull
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$example = Join-Path $root "examples\bari_2022_07_25.csv.gz"
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
    "predictions_bari.geojson",
    "PM10_Bari_intra_urban_2022-07-25.png",
    "run_metadata.json",
    "environment.txt"
)

$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $out $_)) })
if ($missing.Count -gt 0) {
    throw "Quick test finished but expected outputs are missing: $($missing -join ', ')"
}

$pred = Import-Csv (Join-Path $out "predictions.csv")
if ($pred.Count -ne 5394) {
    throw "Unexpected number of prediction rows. Expected 5394, found $($pred.Count)."
}

$mean = ($pred | Measure-Object -Property PM10_pred -Average).Average
$expectedMean = 30.459033966064453
if ([Math]::Abs([double]$mean - $expectedMean) -gt 0.0001) {
    throw "Prediction mean differs from the reference test. Expected about $expectedMean, found $mean."
}

Write-Host "Quick test PASSED."
Write-Host "Rows: $($pred.Count)"
Write-Host "Mean PM10 prediction: $mean"
Write-Host "Outputs: $out"
