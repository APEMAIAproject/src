param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputCsv,

    [string]$Image = "ghcr.io/apemaiaproject/pms-prediction-intra-urban:latest",

    [string]$OutputDir = "",

    [switch]$Pull
)

$ErrorActionPreference = "Stop"

try {
    $inputItem = Get-Item -LiteralPath $InputCsv -ErrorAction Stop
} catch {
    throw "Input CSV not found: $InputCsv"
}

if ($inputItem.PSIsContainer) {
    throw "Input path points to a directory, not a CSV file: $($inputItem.FullName)"
}

$lowerName = $inputItem.Name.ToLowerInvariant()
if (-not ($lowerName.EndsWith(".csv") -or $lowerName.EndsWith(".csv.gz"))) {
    throw "Input must be a .csv or .csv.gz file: $($inputItem.Name)"
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$inputDir = $inputItem.Directory.FullName
$inputName = $inputItem.Name

if ($lowerName.EndsWith(".csv.gz")) {
    $inputStem = $inputName.Substring(0, $inputName.Length - 7)
} else {
    $inputStem = [System.IO.Path]::GetFileNameWithoutExtension($inputName)
}

$safeStem = ($inputStem -replace '[^A-Za-z0-9._-]', '_')
if ([string]::IsNullOrWhiteSpace($safeStem)) { $safeStem = "inference" }

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $out = Join-Path (Join-Path $root "output") $safeStem
} else {
    if ([System.IO.Path]::IsPathRooted($OutputDir)) {
        $out = $OutputDir
    } else {
        $out = Join-Path $root $OutputDir
    }
}

New-Item -ItemType Directory -Force $out | Out-Null
$out = (Get-Item -LiteralPath $out).FullName

if ($Pull) {
    Write-Host "Pulling Docker image: $Image"
    docker pull $Image
    if ($LASTEXITCODE -ne 0) { throw "Docker pull failed with exit code $LASTEXITCODE." }
} else {
    docker image inspect $Image *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker image not found locally. Pulling: $Image"
        docker pull $Image
        if ($LASTEXITCODE -ne 0) { throw "Docker pull failed with exit code $LASTEXITCODE." }
    }
}

Write-Host "Running PM10 intra-urban inference..."
Write-Host "Image : $Image"
Write-Host "Input : $($inputItem.FullName)"
Write-Host "Output: $out"

docker run --rm `
  --mount "type=bind,source=$inputDir,target=/input,readonly" `
  --mount "type=bind,source=$out,target=/output" `
  -e INPUT_PATH="/input/$inputName" `
  -e OUTPUT_DIR=/output `
  $Image

if ($LASTEXITCODE -ne 0) {
    throw "Inference failed with exit code $LASTEXITCODE. Check the error printed above."
}

Write-Host "Inference completed successfully."
Write-Host "Results are in: $out"
