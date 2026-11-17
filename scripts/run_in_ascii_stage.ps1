param(
  [Parameter(Mandatory = $true)]
  [string]$RScript,
  [switch]$KeepStage,
  [switch]$IncludeOutputs
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$stageName = "retraction-resource-network-stage-" + (Get-Date -Format "yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
$stageRoot = Join-Path $env:TEMP $stageName

New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

foreach ($relative in @("R", "scripts", "config", "tests")) {
  $source = Join-Path $projectRoot $relative
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
}

$docsSource = Join-Path $projectRoot "docs"
$docsDestination = Join-Path $stageRoot "docs"
New-Item -ItemType Directory -Path $docsDestination -Force | Out-Null
Copy-Item -Path (Join-Path $docsSource "*") -Destination $docsDestination -Recurse -Force

foreach ($file in @("README.md", "CONTEXT.md")) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $stageRoot $file) -Force
}

foreach ($relative in @("data\raw", "data\external")) {
  $source = Join-Path $projectRoot $relative
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
}

if ($IncludeOutputs -and (Test-Path -LiteralPath (Join-Path $projectRoot "data\outputs"))) {
  $source = Join-Path $projectRoot "data\outputs"
  $destination = Join-Path $stageRoot "data\outputs"
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
}

Push-Location $stageRoot
try {
  & Rscript --encoding=UTF-8 $RScript
  if ($LASTEXITCODE -ne 0) {
    throw "R script failed with exit code $LASTEXITCODE. Stage retained at $stageRoot"
  }
} finally {
  Pop-Location
}

foreach ($relative in @("data\cache", "data\interim", "data\processed", "data\outputs")) {
  $source = Join-Path $stageRoot $relative
  if (-not (Test-Path -LiteralPath $source)) {
    continue
  }

  $destination = Join-Path $projectRoot $relative
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
}

if (-not $KeepStage) {
  $stageResolved = (Resolve-Path -LiteralPath $stageRoot).Path
  $tempResolved = (Resolve-Path -LiteralPath $env:TEMP).Path
  if (-not $stageResolved.StartsWith($tempResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove stage outside temp: $stageResolved"
  }
  Remove-Item -LiteralPath $stageResolved -Recurse -Force
} else {
  Write-Host "Stage retained at $stageRoot"
}
