param(
  [switch]$Refresh
)

$arguments = @()
if ($Refresh) {
  $arguments += "--refresh"
}

& (Join-Path $PSScriptRoot "run_in_ascii_stage.ps1") `
  -RScript "scripts/run_crossref_denominators.R" `
  -IncludeCache -IncludeOutputs `
  -RScriptArguments $arguments
