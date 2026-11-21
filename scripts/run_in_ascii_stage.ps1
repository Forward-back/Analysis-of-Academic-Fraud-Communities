param(
  [Parameter(Mandatory = $true)]
  [string]$RScript,
  [switch]$KeepStage,
  [switch]$IncludeOutputs,
  [switch]$IncludeCache,
  [string[]]$CacheSubpaths = @(),
  [string[]]$RScriptArguments = @()
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$stageName = "retraction-resource-network-stage-" + (Get-Date -Format "yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
$stageRoot = Join-Path $env:TEMP $stageName

New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

foreach ($relative in @("R", "scripts", "config", "tests", "app", "reports")) {
  $source = Join-Path $projectRoot $relative
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
}

$docsSource = Join-Path $projectRoot "docs"
$docsDestination = Join-Path $stageRoot "docs"
New-Item -ItemType Directory -Path $docsDestination -Force | Out-Null
Copy-Item -Path (Join-Path $docsSource "*") -Destination $docsDestination -Recurse -Force

foreach ($file in @("README.md", "CONTEXT.md", "CONTRIBUTING.md", ".gitattributes")) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $stageRoot $file) -Force
}

$githubSource = Join-Path $projectRoot ".github"
if (Test-Path -LiteralPath $githubSource) {
  Copy-Item -LiteralPath $githubSource -Destination (Join-Path $stageRoot ".github") -Recurse -Force
}

foreach ($relative in @("data\raw", "data\external", "data\reference")) {
  $source = Join-Path $projectRoot $relative
  $destination = Join-Path $stageRoot $relative
  New-Item -ItemType Directory -Path $destination -Force | Out-Null
  Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
}

if ($IncludeCache) {
  $cacheSource = Join-Path $projectRoot "data\cache"
  if (Test-Path -LiteralPath $cacheSource) {
    $cacheDestination = Join-Path $stageRoot "data\cache"
    New-Item -ItemType Directory -Path $cacheDestination -Force | Out-Null
    Copy-Item -Path (Join-Path $cacheSource "*") -Destination $cacheDestination -Recurse -Force
  }
}

if (-not $IncludeCache) {
  foreach ($relative in $CacheSubpaths) {
    $source = Join-Path $projectRoot (Join-Path "data\cache" $relative)
    if (-not (Test-Path -LiteralPath $source)) {
      continue
    }
    $destination = Join-Path $stageRoot (Join-Path "data\cache" $relative)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
  }
}

if ($IncludeOutputs) {
  foreach ($relative in @("data\outputs", "data\interim", "data\processed")) {
    $source = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $source)) {
      continue
    }
    $destination = Join-Path $stageRoot $relative
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -Path (Join-Path $source "*") -Destination $destination -Recurse -Force
  }
}

Push-Location $stageRoot
try {
  & Rscript --encoding=UTF-8 $RScript @RScriptArguments
  if ($LASTEXITCODE -ne 0) {
    throw "R script failed with exit code $LASTEXITCODE. Stage retained at $stageRoot"
  }
} finally {
  Pop-Location
}

foreach ($relative in @(
  "data\cache",
  "data\external",
  "data\reference",
  "data\interim",
  "data\processed",
  "data\outputs",
  "app\data",
  "reports\assets"
)) {
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
