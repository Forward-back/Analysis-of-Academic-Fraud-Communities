param(
  [switch]$Refresh
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$queuePath = Join-Path $projectRoot "data\outputs\audits\tables\funding_project_verification_queue.csv"
$snapshotDir = Join-Path $projectRoot "data\external\snapshots\funding_official_verification_v1\nsfc"
$summaryPath = Join-Path $projectRoot "data\outputs\audits\tables\funding_nsfc_verification_raw.csv"

New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $encoding = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Decrypt-NsfcResponse {
  param([Parameter(Mandatory = $true)][string]$Encoded)

  $bytes = [Convert]::FromBase64String($Encoded.Trim())
  $des = [System.Security.Cryptography.DES]::Create()
  try {
    $des.Key = [Text.Encoding]::ASCII.GetBytes("IFROMC86")
    $des.Mode = [System.Security.Cryptography.CipherMode]::ECB
    $des.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $decryptor = $des.CreateDecryptor()
    $plain = $decryptor.TransformFinalBlock($bytes, 0, $bytes.Length)
    return [Text.Encoding]::UTF8.GetString($plain)
  } finally {
    $des.Dispose()
  }
}

function Test-NsfcFunder {
  param([string]$FunderNames)

  $accepted = @(
    "National Natural Science Foundation of China",
    "National Natural Science Foundation Young of China",
    "International Young Scientists from National Natural Science Foundation of China",
    "China National Funds for Distinguished Young Scientists",
    "National Nature Science Fund for Distinguished Young Scholars of China"
  )
  $names = @($FunderNames -split ";" | ForEach-Object { $_.Trim() })
  return $names | Where-Object { $_ -in $accepted } | Select-Object -First 1
}

$queue = Import-Csv -LiteralPath $queuePath
$summaryRows = @()

foreach ($row in $queue) {
  $funderMatch = Test-NsfcFunder -FunderNames $row.funder_names
  if (-not $funderMatch) {
    continue
  }

  $award = $row.award_number
  $snapshotPath = Join-Path $snapshotDir ($award + ".json")
  $payloadPath = Join-Path $env:TEMP ("nsfc-query-" + $award + ".json")
  $responsePath = Join-Path $env:TEMP ("nsfc-response-" + $award + ".txt")

  $payload = [ordered]@{
    complete = $true
    fuzzyKeyword = ""
    isFuzzySearch = $false
    conclusionYear = ""
    dependUnit = ""
    keywords = ""
    pageNum = 0
    pageSize = 10
    projectType = ""
    projectTypeName = ""
    code = ""
    ratifyNo = $award
    ratifyYear = ""
    order = "enddate"
    ordering = "desc"
    codeScreening = ""
    dependUnitScreening = ""
    keywordsScreening = ""
    projectTypeNameScreening = ""
  } | ConvertTo-Json -Compress

  if ($Refresh -or -not (Test-Path -LiteralPath $snapshotPath)) {
    Write-Utf8NoBom -Path $payloadPath -Content $payload
    $attemptDelays = @(0, 2, 4, 8, 16)
    $decrypted = $null
    $httpStatus = $null
    foreach ($attemptDelay in $attemptDelays) {
      if ($attemptDelay -gt 0) {
        Start-Sleep -Seconds $attemptDelay
      }
      $curlArgs = @(
        "--noproxy", "*",
        "-L",
        "--ssl-no-revoke",
        "--tlsv1.2",
        "--max-time", "45",
        "-A", "Mozilla/5.0",
        "-H", "Content-Type: application/json;charset=UTF-8",
        "-H", "Referer: https://kd.nsfc.cn/finalProjectInit?advanced=true",
        "--data-binary", "@$payloadPath",
        "-sS",
        "https://kd.nsfc.cn/api/baseQuery/completionQueryResultsData",
        "-o", $responsePath
      )
      $httpStatus = & curl.exe @curlArgs -w "%{http_code}"
      if ($LASTEXITCODE -ne 0) {
        continue
      }
      $encoded = (Get-Content -Raw -LiteralPath $responsePath).Trim()
      if (-not $encoded -or $encoded.StartsWith("<")) {
        continue
      }
      try {
        $decrypted = if ($encoded.StartsWith("{")) {
          $encoded
        } else {
          Decrypt-NsfcResponse -Encoded $encoded
        }
        break
      } catch {
        continue
      }
    }
    if (-not $decrypted) {
      throw "NSFC request failed for $award after retries; last HTTP status: $httpStatus"
    }
    $snapshot = [ordered]@{
      contract_version = "1.0"
      artifact = "nsfc-completion-project-record-v1"
      award_number = $award
      access_date = (Get-Date -Format "yyyy-MM-dd")
      fetched_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
      http_status = [int]$httpStatus
      official_api = "https://kd.nsfc.cn/api/baseQuery/completionQueryResultsData"
      official_query_page = "https://kd.nsfc.cn/finalProjectInit?advanced=true"
      request_payload = $payload | ConvertFrom-Json
      response = $decrypted | ConvertFrom-Json
    }
    Write-Utf8NoBom `
      -Path $snapshotPath `
      -Content ($snapshot | ConvertTo-Json -Depth 20)
    Start-Sleep -Milliseconds 250
  }

  $snapshotData = Get-Content -Raw -Encoding UTF8 -LiteralPath $snapshotPath | ConvertFrom-Json
  $records = @($snapshotData.response.data.resultsData)
  if ($records.Count -eq 0) {
    $summaryRows += [pscustomobject]@{
      award_number = $award
      verification_status = "not_found"
      official_record_id = ""
      official_record_url = ""
      funding_organization = $funderMatch
      official_project_title = ""
      project_type = ""
      undertaking_unit = ""
      project_leader = ""
      approved_year = ""
      conclusion_year = ""
      amount = ""
      currency = ""
      amount_unit = ""
      official_supporting_text = ""
      access_date = $snapshotData.access_date
      source_snapshot = $snapshotPath.Substring($projectRoot.Length + 1).Replace("\", "/")
    }
  } else {
    foreach ($record in $records) {
      $recordId = [string]$record[0]
      $title = [string]$record[1]
      $approvedAward = [string]$record[2]
      $projectType = [string]$record[3]
      $dependUnit = [string]$record[4]
      $leader = [string]$record[5]
      $amount = [string]$record[6]
      $approvedYear = [string]$record[7]
      $keywords = ($record[8] -join ";")
      $code = [string]$record[14]
      $conclusionYear = [string]$record[15]
      $summaryRows += [pscustomobject]@{
        award_number = $award
        verification_status = "officially_verified"
        official_record_id = $recordId
        official_record_url = "https://kd.nsfc.cn/finalDetails?id=$recordId"
        funding_organization = $funderMatch
        official_project_title = $title
        project_type = $projectType
        undertaking_unit = $dependUnit
        project_leader = $leader
        approved_year = $approvedYear
        conclusion_year = $conclusionYear
        amount = $amount
        currency = "CNY"
        amount_unit = "10,000 CNY"
        official_supporting_text = "ratifyNo=$approvedAward; title=$title; projectType=$projectType; projectLeader=$leader; amount=$amount; amountUnit=10,000 CNY; approvedYear=$approvedYear; conclusionYear=$conclusionYear; undertakingUnit=$dependUnit; code=$code; keywords=$keywords"
        access_date = $snapshotData.access_date
        source_snapshot = $snapshotPath.Substring($projectRoot.Length + 1).Replace("\", "/")
      }
    }
  }
}

$summaryCsv = $summaryRows | ConvertTo-Csv -NoTypeInformation
Write-Utf8NoBom -Path $summaryPath -Content (($summaryCsv -join "`r`n") + "`r`n")
Write-Output ("NSFC records checked: " + $summaryRows.Count)
Write-Output ("NSFC records verified: " + @($summaryRows | Where-Object { $_.verification_status -eq "officially_verified" }).Count)

