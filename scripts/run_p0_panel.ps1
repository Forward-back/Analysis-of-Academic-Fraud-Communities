$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "run_in_ascii_stage.ps1") -RScript "scripts/run_p0_panel.R"
