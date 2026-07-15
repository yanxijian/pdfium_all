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

function Ensure-NinjaOnPath {
  if (Get-Command ninja -ErrorAction SilentlyContinue) { return }
  $vs = Find-VsInstallPath
  if ($vs) {
    $ninjaDir = Join-Path $vs "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
    Add-PathFront $ninjaDir
  }
  if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    throw "ninja not found. Install Ninja (or Visual Studio CMake tools) and ensure it is on PATH."
  }
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
