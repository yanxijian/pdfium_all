<#
.SYNOPSIS
  Initialize submodules and check toolchain for PDFium CMake MVP.

.PARAMETER VcpkgRoot
  Optional path to vcpkg. Defaults to $env:VCPKG_ROOT, then `vcpkg` on PATH, then .tools/vcpkg.

.PARAMETER BootstrapVcpkg
  If set and no vcpkg is found, clone+bootstrap vcpkg into <repo>/.tools/vcpkg (gitignored).

.PARAMETER InstallDeps
  If set, run `vcpkg install` for the packages listed in deps.lock.md.
#>
param(
  [string] $VcpkgRoot = "",
  [switch] $BootstrapVcpkg,
  [switch] $InstallDeps
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\Common.ps1"
$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

Write-Host "== git submodule update --init --recursive =="
git submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "submodule update failed" }

function Require-Cmd([string] $Name) {
  $c = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $c) { throw "Required command not found: $Name" }
  Write-Host "OK $Name -> $($c.Source)"
}

Write-Host "== toolchain =="
Require-Cmd cmake
Require-Cmd git
Ensure-NinjaOnPath
Require-Cmd ninja
Ensure-ClangClOnPath
Require-Cmd clang-cl

$vcpkg = Require-VcpkgRoot -VcpkgRoot $VcpkgRoot -BootstrapVcpkg:$BootstrapVcpkg -RepoRoot $RepoRoot
Write-Host "OK vcpkg -> $vcpkg"

if ($InstallDeps) {
  Write-Host "== vcpkg install (see deps.lock.md) =="
  $vcpkgExe = Join-Path $vcpkg "vcpkg.exe"
  & $vcpkgExe install zlib libjpeg-turbo freetype icu harfbuzz abseil --triplet x64-windows
  if ($LASTEXITCODE -ne 0) { throw "vcpkg install failed" }
}

Write-Host "== pins (see deps.lock.md) =="
git submodule status
Write-Host "Bootstrap done."
Write-Host "Next: .\scripts\build.ps1"
