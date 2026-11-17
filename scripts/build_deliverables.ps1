$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "run_in_ascii_stage.ps1") `
  -RScript "scripts/build_deliverables.R" `
  -IncludeOutputs
