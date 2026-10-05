$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$log = Join-Path $root "docs\ai_team\scheduled_worker.log"
$running = Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" | Where-Object { $_.CommandLine -like "*langgraph_team.py*" }
if ($running) {
  "[$(Get-Date -Format o)] skip: langgraph worker already running (pid=$($running.ProcessId -join ','))" | Add-Content -LiteralPath $log -Encoding UTF8
  exit 0
}
$batch = if ($env:AI_TEAM_BATCH) { [int]$env:AI_TEAM_BATCH } else { 4 }
"[$(Get-Date -Format o)] run langgraph batch=$batch" | Add-Content -LiteralPath $log -Encoding UTF8
python (Join-Path $root "tools\langgraph_team.py") --batch $batch *>> $log
if ($LASTEXITCODE -ne 0) { throw "AI team worker failed: $LASTEXITCODE" }
