<#
.SYNOPSIS
  Configure + build PDFium CMake MVP, then stage into output/.
#>
param(
  [string] $VcpkgRoot = $env:VCPKG_ROOT,
  [string] $BuildDir = "",
  [string] $Config = "Release",
  [switch] $SkipStage
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot "pdfium\out\cmake" }

if (-not $VcpkgRoot) {
  if (Test-Path "D:\Codes\vcpkg\vcpkg.exe") { $VcpkgRoot = "D:\Codes\vcpkg" }
}
$toolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
if (-not (Test-Path -LiteralPath $toolchain)) {
  throw "vcpkg toolchain not found: $toolchain (pass -VcpkgRoot)"
}

# Ensure clang-cl and ninja on PATH
if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) {
  $llvmBin = "C:\Program Files\LLVM\bin"
  if (Test-Path $llvmBin) { $env:Path = "$llvmBin;" + $env:Path }
}
if (-not (Get-Command clang-cl -ErrorAction SilentlyContinue)) {
  throw "clang-cl required on Windows"
}
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
  $vsNinja = "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
  if (-not (Test-Path (Join-Path $vsNinja "ninja.exe"))) {
    $vsNinja = "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"
  }
  if (Test-Path (Join-Path $vsNinja "ninja.exe")) {
    $env:Path = "$vsNinja;" + $env:Path
  }
}
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
  throw "ninja not found on PATH"
}

# Prefer VS env for Windows SDK link libs
$vcvarsCandidates = @(
  "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat",
  "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
)
$vcvars = $vcvarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

Write-Host "== configure =="
Write-Host "BuildDir=$BuildDir"
Write-Host "VcpkgRoot=$VcpkgRoot"

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
  Write-Warning "vcvars64.bat not found; configuring without VS env"
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
  & $exe
  if ($LASTEXITCODE -ne 0) { throw "simple_no_v8 failed with exit $LASTEXITCODE" }
  Write-Host "simple_no_v8 OK"
}

Write-Host "Build pipeline done."
