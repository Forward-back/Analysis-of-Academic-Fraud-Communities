param(
  [string]$Limit = "",
  [switch]$DryRun,
  [switch]$Refresh
)

$ErrorActionPreference = "Stop"

$arguments = @()
if ($DryRun) {
  $arguments += "--dry-run"
}
if ($Refresh) {
  $arguments += "--refresh"
}
if ($Limit -ne "") {
  $arguments += "--limit=$Limit"
}

& (Join-Path $PSScriptRoot "run_in_ascii_stage.ps1") `
  -RScript "scripts/run_openalex_fetch.R" `
  -IncludeCache `
  -IncludeOutputs `
  -RScriptArguments $arguments
