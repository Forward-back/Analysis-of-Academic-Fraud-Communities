param(
  [string]$Limit = "",
  [switch]$DryRun
)

$arguments = @()
if ($DryRun) { $arguments += "--dry-run" }
if ($Limit -ne "") { $arguments += "--limit=$Limit" }

& (Join-Path $PSScriptRoot "run_in_ascii_stage.ps1") `
  -RScript "scripts/run_selected_control_fetch.R" `
  -IncludeCache `
  -IncludeOutputs `
  -RScriptArguments $arguments
