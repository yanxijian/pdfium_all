<#
.SYNOPSIS
  Fetch V8 sources pinned to pdfium/DEPS `v8_revision` into .tools/v8-workspace.

Requires network access to chromium.googlesource.com and depot_tools (auto-cloned).
#>
param(
  [string] $Revision = "",
  [switch] $Force
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\Common.ps1"
$RepoRoot = Get-RepoRoot

if (-not $Revision) {
  $Revision = Get-PdfiumV8Revision -RepoRoot $RepoRoot
}
Write-Host "V8 revision (from pdfium/DEPS unless overridden): $Revision"

$dt = Ensure-DepotTools -RepoRoot $RepoRoot
Start-SocksHttpBridge | Out-Null
$ws = Join-Path $RepoRoot ".tools\v8-workspace"
$v8Dir = Join-Path $ws "v8"

New-Item -ItemType Directory -Force -Path $ws | Out-Null
if ($Force -and (Test-Path $ws)) {
  Write-Host "Force: removing $ws"
  Remove-Item -LiteralPath $ws -Recurse -Force
  New-Item -ItemType Directory -Force -Path $ws | Out-Null
}
Set-Location $ws

$gclient = @"
solutions = [
  {
    "name": "v8",
    "url": "https://chromium.googlesource.com/v8/v8.git@$Revision",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
"@

$gclientPath = Join-Path $ws ".gclient"
Set-Content -LiteralPath $gclientPath -Value $gclient -Encoding ascii

Write-Host "== gclient sync (V8 + deps; may take a long time) =="
& gclient sync --with_branch_heads --revision "v8@$Revision"
if ($LASTEXITCODE -ne 0) { throw "gclient sync failed" }

if (-not (Test-Path (Join-Path $v8Dir "include\v8.h"))) {
  throw "V8 checkout missing include/v8.h under $v8Dir"
}

# Record pin for build_v8.ps1.
Set-Content -LiteralPath (Join-Path $ws "V8_REVISION.txt") -Value $Revision -Encoding ascii
Write-Host "Fetched V8 into $v8Dir"
Write-Host "Next: .\scripts\build_v8.ps1"
