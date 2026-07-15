# Shared helpers for pdfium_all Windows scripts.
# Dot-source from other scripts: . "$PSScriptRoot\Common.ps1"

function Get-RepoRoot {
  return (Split-Path -Parent $PSScriptRoot)
}

function Add-PathFront([string] $Dir) {
  if ($Dir -and (Test-Path -LiteralPath $Dir)) {
    $env:Path = "$Dir;" + $env:Path
  }
}

function Find-Vswhere {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  return $null
}

function Find-VsInstallPath {
  $vswhere = Find-Vswhere
  if (-not $vswhere) { return $null }
  $p = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
  if ($p) { return $p.Trim() }
  return $null
}

function Find-Vcvars64 {
  $vs = Find-VsInstallPath
  if ($vs) {
    $bat = Join-Path $vs "VC\Auxiliary\Build\vcvars64.bat"
    if (Test-Path -LiteralPath $bat) { return $bat }
  }
  return $null
}

function Find-Vcvarsall {
  $vs = Find-VsInstallPath
  if ($vs) {
    $bat = Join-Path $vs "VC\Auxiliary\Build\vcvarsall.bat"
    if (Test-Path -LiteralPath $bat) { return $bat }
  }
  return $null
}

function Get-LatestWindowsSdkVersion {
  $sdkIncludeRoot = "C:\Program Files (x86)\Windows Kits\10\Include"
  if (-not (Test-Path -LiteralPath $sdkIncludeRoot)) { return "" }
  return (Get-ChildItem -LiteralPath $sdkIncludeRoot -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1 -ExpandProperty Name)
}

function Ensure-NinjaOnPath {
  $vs = Find-VsInstallPath
  if ($vs) {
    $ninjaDir = Join-Path $vs "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
    Add-PathFront $ninjaDir
  }
  $ninja = Get-Command ninja -ErrorAction SilentlyContinue
  if (-not $ninja) {
    throw "ninja not found. Install Ninja (or Visual Studio CMake tools) and ensure it is on PATH."
  }
  # Reject depot_tools shim that often cannot run outside Chromium env.
  if ($ninja.Source -match 'depot_tools') {
    throw "ninja resolves to depot_tools ($($ninja.Source)); put Visual Studio/CMake Ninja earlier on PATH."
  }
  Write-Host "OK ninja -> $($ninja.Source)"
}

function Ensure-ClangClOnPath {
  if (Get-Command clang-cl -ErrorAction SilentlyContinue) { return }
  # Default LLVM installer location (optional convenience; not a workspace path).
  Add-PathFront "${env:ProgramFiles}\LLVM\bin"
  if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) {
    throw "clang-cl not found. Install LLVM and ensure clang-cl is on PATH."
  }
}

function Resolve-VcpkgRoot {
  param(
    [string] $VcpkgRoot,
    [switch] $BootstrapVcpkg,
    [string] $RepoRoot = (Get-RepoRoot)
  )

  if ($VcpkgRoot) {
    return $VcpkgRoot
  }
  if ($env:VCPKG_ROOT) {
    return $env:VCPKG_ROOT
  }

  $cmd = Get-Command vcpkg -ErrorAction SilentlyContinue
  if ($cmd) {
    return (Split-Path -Parent $cmd.Source)
  }

  $local = Join-Path $RepoRoot ".tools\vcpkg"
  if (Test-Path (Join-Path $local "scripts\buildsystems\vcpkg.cmake")) {
    return $local
  }

  if ($BootstrapVcpkg) {
    Write-Host "Bootstrapping vcpkg into $local ..."
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $local) | Out-Null
    if (-not (Test-Path $local)) {
      git clone --depth 1 https://github.com/microsoft/vcpkg.git $local
      if ($LASTEXITCODE -ne 0) { throw "git clone vcpkg failed" }
    }
    & (Join-Path $local "bootstrap-vcpkg.bat") -disableMetrics
    if ($LASTEXITCODE -ne 0) { throw "bootstrap-vcpkg failed" }
    return $local
  }

  return $null
}

function Require-VcpkgRoot {
  param(
    [string] $VcpkgRoot,
    [switch] $BootstrapVcpkg,
    [string] $RepoRoot = (Get-RepoRoot)
  )
  $root = Resolve-VcpkgRoot -VcpkgRoot $VcpkgRoot -BootstrapVcpkg:$BootstrapVcpkg -RepoRoot $RepoRoot
  $toolchain = if ($root) { Join-Path $root "scripts\buildsystems\vcpkg.cmake" } else { $null }
  if (-not $root -or -not (Test-Path -LiteralPath $toolchain)) {
    throw @"
vcpkg not found.

Set VCPKG_ROOT to an existing vcpkg checkout, or run:
  .\scripts\bootstrap.ps1 -BootstrapVcpkg
"@
  }
  $env:VCPKG_ROOT = $root
  return $root
}

function Get-PdfiumDepsFile {
  param([string] $RepoRoot = (Get-RepoRoot))
  $p = Join-Path $RepoRoot "pdfium\DEPS"
  if (-not (Test-Path -LiteralPath $p)) {
    throw "pdfium/DEPS not found at $p (init submodules first)"
  }
  return $p
}

function Get-PdfiumV8Revision {
  param([string] $RepoRoot = (Get-RepoRoot))
  $deps = Get-Content -LiteralPath (Get-PdfiumDepsFile -RepoRoot $RepoRoot) -Raw
  if ($deps -match "'v8_revision'\s*:\s*'([0-9a-fA-F]+)'") {
    return $Matches[1]
  }
  throw "Could not parse v8_revision from pdfium/DEPS"
}

function Get-DefaultPdfiumV8Out {
  param([string] $RepoRoot = (Get-RepoRoot))
  return (Join-Path $RepoRoot ".tools\v8-out")
}

function Resolve-PdfiumV8Root {
  param(
    [string] $V8Root = "",
    [string] $RepoRoot = (Get-RepoRoot)
  )
  if ($V8Root) { return $V8Root }
  if ($env:PDFIUM_V8_ROOT) { return $env:PDFIUM_V8_ROOT }
  if ($env:V8_ROOT) { return $env:V8_ROOT }
  $stamp = Get-DefaultPdfiumV8Out -RepoRoot $RepoRoot
  if (Test-Path (Join-Path $stamp "v8\include\v8.h")) {
    return $stamp
  }
  return $null
}

function Require-PdfiumV8Root {
  param(
    [string] $V8Root = "",
    [string] $RepoRoot = (Get-RepoRoot)
  )
  $root = Resolve-PdfiumV8Root -V8Root $V8Root -RepoRoot $RepoRoot
  if (-not $root -or -not (Test-Path (Join-Path $root "v8\include\v8.h"))) {
    throw @"
V8 product tree not found (need v8/include/v8.h).

Run:
  .\scripts\fetch_v8.ps1
  .\scripts\build_v8.ps1
Or set PDFIUM_V8_ROOT to a stamped V8 tree.
"@
  }
  $env:PDFIUM_V8_ROOT = $root
  return $root
}

function Ensure-DepotTools {
  param([string] $RepoRoot = (Get-RepoRoot))
  $dt = Join-Path $RepoRoot ".tools\depot_tools"
  if (-not (Test-Path (Join-Path $dt "gclient.bat"))) {
    Write-Host "Cloning depot_tools into $dt ..."
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dt) | Out-Null
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git $dt
    if ($LASTEXITCODE -ne 0) { throw "depot_tools clone failed" }
  }
  # depot_tools must win over other python/git shims on Windows.
  Add-PathFront $dt
  $env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"

  # PowerShell Invoke-WebRequest cannot use socks5:// proxies; bootstrap CIPD via curl when needed.
  Ensure-CipdClient -DepotToolsDir $dt
  return $dt
}

function Ensure-CipdClient {
  param([string] $DepotToolsDir)
  $cipdExe = Join-Path $DepotToolsDir ".cipd_client.exe"
  if (Test-Path -LiteralPath $cipdExe) {
    if ((Get-Item -LiteralPath $cipdExe).Length -gt 1000000) { return }
  }
  $verFile = Join-Path $DepotToolsDir "cipd_client_version"
  if (-not (Test-Path -LiteralPath $verFile)) {
    Write-Warning "cipd_client_version missing; gclient may bootstrap CIPD itself"
    return
  }
  $ver = (Get-Content -LiteralPath $verFile -Raw).Trim()
  $url = "https://chrome-infra-packages.appspot.com/client?platform=windows-amd64&version=$ver"
  $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
  if (-not $curl) {
    Write-Warning "curl.exe not found; cannot pre-bootstrap CIPD (socks5-incompatible IWR)"
    return
  }
  Write-Host "Bootstrapping CIPD client via curl -> $cipdExe"
  $proxyArgs = @()
  foreach ($p in @($env:ALL_PROXY, $env:HTTPS_PROXY, $env:HTTP_PROXY, $env:GIT_HTTPS_PROXY)) {
    if ($p) { $proxyArgs = @("--proxy", $p); break }
  }
  & curl.exe -L @proxyArgs -o $cipdExe $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $cipdExe) -or (Get-Item $cipdExe).Length -lt 1000000) {
    throw "Failed to download CIPD client from $url"
  }
}

function Start-SocksHttpBridge {
  param(
    [string] $Listen = "127.0.0.1:18080",
    [string] $Socks = "127.0.0.1:10808"
  )
  # Infer SOCKS upstream from env when present.
  foreach ($p in @($env:ALL_PROXY, $env:all_proxy)) {
    if ($p -match '^socks5?h?://([^:/]+):(\d+)') {
      $Socks = "$($Matches[1]):$($Matches[2])"
      break
    }
  }
  $script = Join-Path $PSScriptRoot "socks_http_bridge.py"
  if (-not (Test-Path $script)) { throw "missing $script" }
  # Only start if ALL_PROXY/HTTPS_PROXY looks like socks and HTTP bridge not up.
  $need = $false
  foreach ($p in @($env:ALL_PROXY, $env:HTTPS_PROXY, $env:HTTP_PROXY)) {
    if ($p -and ($p -match '^socks5?h?://')) { $need = $true; break }
  }
  if (-not $need) { return $null }

  $port = [int]($Listen.Split(':')[-1])
  $up = $false
  try {
    $up = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue -InformationLevel Quiet
  } catch { $up = $false }
  if (-not $up) {
    Write-Host "Starting local HTTP→SOCKS bridge on $Listen (upstream $Socks)"
    Start-Process -FilePath "python" -ArgumentList @($script, "--listen", $Listen, "--socks", $Socks) -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 1
  }
  $http = "http://$Listen"
  $env:HTTP_PROXY = $http
  $env:HTTPS_PROXY = $http
  $env:http_proxy = $http
  $env:https_proxy = $http
  # Keep git happy; some clients prefer ALL_PROXY unset once HTTP proxy is set.
  Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
  Remove-Item Env:all_proxy -ErrorAction SilentlyContinue
  Write-Host "Using HTTP_PROXY=$http for depot_tools (SOCKS via bridge)"
  return $http
}
