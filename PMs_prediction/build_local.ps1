param(
    [string]$Image = "pms-prediction:local"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Building local image: $Image"
docker build -t $Image $root
if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed with exit code $LASTEXITCODE."
}
Write-Host "Local image built successfully: $Image"
Write-Host "Run it with: .\run_docker.ps1 '<input.csv[.gz]>' -Image '$Image'"
