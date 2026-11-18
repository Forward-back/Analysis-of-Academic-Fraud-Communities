$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "run_in_ascii_stage.ps1") `
  -RScript "scripts/run_institution_tier_sources.R" `
  -IncludeOutputs
