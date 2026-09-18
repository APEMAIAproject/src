param(
    [string]$Image = "pms-prediction-intra-urban:local"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Building local image: $Image"
docker build -t $Image $root
if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed with exit code $LASTEXITCODE."
}
Write-Host "Build completed: $Image"
