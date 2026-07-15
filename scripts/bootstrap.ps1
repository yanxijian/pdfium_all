<#
.SYNOPSIS
  Initialize submodules and check local toolchain for PDFium CMake MVP.
#>
param(
  [string] $VcpkgRoot = $env:VCPKG_ROOT
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
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
# Ninja: PATH, or Visual Studio's bundled copy
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
  $vsNinja = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
  if (-not (Test-Path $vsNinja)) {
    $vsNinja = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
  }
  if (Test-Path (Join-Path $vsNinja "ninja.exe")) {
    $env:Path = "$vsNinja;" + $env:Path
  }
}
Require-Cmd ninja
Require-Cmd git

$clang = Get-Command clang-cl -ErrorAction SilentlyContinue
if (-not $clang) {
  $guess = "C:\Program Files\LLVM\bin\clang-cl.exe"
  if (Test-Path -LiteralPath $guess) {
    $env:Path = "C:\Program Files\LLVM\bin;" + $env:Path
    $clang = Get-Command clang-cl -ErrorAction SilentlyContinue
  }
}
if (-not $clang) {
  throw "clang-cl not found. Install LLVM and ensure it is on PATH."
}
Write-Host "OK clang-cl -> $($clang.Source)"

if (-not $VcpkgRoot) {
  if (Test-Path "D:\Codes\vcpkg\vcpkg.exe") { $VcpkgRoot = "D:\Codes\vcpkg" }
}
if (-not $VcpkgRoot -or -not (Test-Path (Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"))) {
  Write-Warning "VCPKG_ROOT not set / vcpkg.cmake missing. build.ps1 will require -VcpkgRoot."
} else {
  Write-Host "OK vcpkg -> $VcpkgRoot"
  $env:VCPKG_ROOT = $VcpkgRoot
}

Write-Host "== pins (see deps.lock.md) =="
git submodule status
Write-Host "Bootstrap done."
