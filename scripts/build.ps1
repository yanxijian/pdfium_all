<#
.SYNOPSIS
  Configure + build PDFium CMake MVP, then stage into output/.

.PARAMETER VcpkgRoot
  Optional path to vcpkg. Defaults to $env:VCPKG_ROOT / PATH / .tools/vcpkg.

.PARAMETER BootstrapVcpkg
  Passed through to vcpkg resolution (clone into .tools/vcpkg if missing).
#>
param(
  [string] $VcpkgRoot = "",
  [string] $BuildDir = "",
  [string] $Config = "Release",
  [switch] $BootstrapVcpkg,
  [switch] $SkipStage
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\Common.ps1"
$RepoRoot = Get-RepoRoot
if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot "pdfium\out\cmake" }

$vcpkg = Require-VcpkgRoot -VcpkgRoot $VcpkgRoot -BootstrapVcpkg:$BootstrapVcpkg -RepoRoot $RepoRoot
$toolchain = Join-Path $vcpkg "scripts\buildsystems\vcpkg.cmake"

Ensure-ClangClOnPath
Ensure-NinjaOnPath

$vcvars = Find-Vcvars64

Write-Host "== configure =="
Write-Host "BuildDir=$BuildDir"
Write-Host "VcpkgRoot=$vcpkg"

$cmakeArgs = @(
  "-S", (Join-Path $RepoRoot "pdfium"),
  "-B", $BuildDir,
  "-G", "Ninja",
  "-DCMAKE_BUILD_TYPE=$Config",
  "-DCMAKE_C_COMPILER=clang-cl",
  "-DCMAKE_CXX_COMPILER=clang-cl",
  "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
  "-DVCPKG_TARGET_TRIPLET=x64-windows"
)

if ($vcvars) {
  $argLine = ($cmakeArgs | ForEach-Object {
      if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
  cmd /c "`"$vcvars`" && cmake $argLine"
  if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
  Write-Host "== build =="
  cmd /c "`"$vcvars`" && cmake --build `"$BuildDir`" --target pdfium simple_no_v8 -j %NUMBER_OF_PROCESSORS%"
  if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }
} else {
  Write-Warning "vcvars64.bat not found via vswhere; configuring without VS env"
  & cmake @cmakeArgs
  if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
  Write-Host "== build =="
  & cmake --build $BuildDir --target pdfium simple_no_v8
  if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }
}

if (-not $SkipStage) {
  Write-Host "== stage output =="
  & (Join-Path $PSScriptRoot "stage_output.ps1") -BuildDir $BuildDir -Config $Config
}

$exe = Join-Path $RepoRoot "output\bin\simple_no_v8.exe"
if (Test-Path -LiteralPath $exe) {
  Write-Host "== smoke test =="
  Push-Location (Split-Path -Parent $exe)
  try {
    & .\simple_no_v8.exe
    if ($LASTEXITCODE -ne 0) { throw "simple_no_v8 failed with exit $LASTEXITCODE" }
  } finally {
    Pop-Location
  }
  Write-Host "simple_no_v8 OK"
}

Write-Host "Build pipeline done."
