<#
.SYNOPSIS
  Configure + build PDFium CMake MVP, then stage into output/.

.PARAMETER EnableV8
  Build with Acrobat JS (PDFIUM_ENABLE_V8=ON). Requires a stamped V8 tree
  (see fetch_v8.ps1 / build_v8.ps1) or PDFIUM_V8_ROOT.
#>
param(
  [string] $VcpkgRoot = "",
  [string] $V8Root = "",
  [string] $BuildDir = "",
  [string] $Config = "Release",
  [switch] $BootstrapVcpkg,
  [switch] $EnableV8,
  [switch] $SkipStage
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\Common.ps1"
$RepoRoot = Get-RepoRoot
if (-not $BuildDir) {
  if ($EnableV8) {
    $BuildDir = Join-Path $RepoRoot "pdfium\out\cmake-v8"
  } else {
    $BuildDir = Join-Path $RepoRoot "pdfium\out\cmake"
  }
}

$vcpkg = Require-VcpkgRoot -VcpkgRoot $VcpkgRoot -BootstrapVcpkg:$BootstrapVcpkg -RepoRoot $RepoRoot
$toolchain = Join-Path $vcpkg "scripts\buildsystems\vcpkg.cmake"

Ensure-ClangClOnPath
Ensure-NinjaOnPath
$ninjaExe = (Get-Command ninja).Source

$pdfiumV8 = $null
if ($EnableV8) {
  $pdfiumV8 = Require-PdfiumV8Root -V8Root $V8Root -RepoRoot $RepoRoot
}

$vcvars = Find-Vcvars64

Write-Host "== configure =="
Write-Host "BuildDir=$BuildDir"
Write-Host "VcpkgRoot=$vcpkg"
Write-Host "EnableV8=$EnableV8"
if ($pdfiumV8) { Write-Host "PDFIUM_V8_ROOT=$pdfiumV8" }

$cmakeArgs = @(
  "-S", (Join-Path $RepoRoot "pdfium"),
  "-B", $BuildDir,
  "-G", "Ninja",
  "-DCMAKE_MAKE_PROGRAM=$ninjaExe",
  "-DCMAKE_BUILD_TYPE=$Config",
  "-DCMAKE_C_COMPILER=clang-cl",
  "-DCMAKE_CXX_COMPILER=clang-cl",
  "-DCMAKE_TOOLCHAIN_FILE=$toolchain",
  "-DVCPKG_TARGET_TRIPLET=x64-windows"
)

if ($EnableV8) {
  $cmakeArgs += @(
    "-DPDFIUM_ENABLE_V8=ON",
    "-DPDFIUM_V8_ROOT=$pdfiumV8"
  )
} else {
  $cmakeArgs += "-DPDFIUM_ENABLE_V8=OFF"
}

$targets = @("pdfium", "simple_no_v8")
if ($EnableV8) { $targets += "simple_with_v8" }
$targetArgs = ($targets | ForEach-Object { "--target"; $_ }) -join ' '

if ($vcvars) {
  $argLine = ($cmakeArgs | ForEach-Object {
      if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
  cmd /c "`"$vcvars`" && cmake $argLine"
  if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
  Write-Host "== build =="
  $tline = ($targets | ForEach-Object { "--target $_" }) -join ' '
  cmd /c "`"$vcvars`" && cmake --build `"$BuildDir`" $tline -j %NUMBER_OF_PROCESSORS%"
  if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }
} else {
  Write-Warning "vcvars64.bat not found via vswhere; configuring without VS env"
  & cmake @cmakeArgs
  if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }
  Write-Host "== build =="
  & cmake --build $BuildDir --target @targets
  if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }
}

if (-not $SkipStage) {
  Write-Host "== stage output =="
  $stageArgs = @{ BuildDir = $BuildDir; Config = $Config }
  if ($pdfiumV8) { $stageArgs.V8Root = $pdfiumV8 }
  & (Join-Path $PSScriptRoot "stage_output.ps1") @stageArgs
}

function Smoke-Exe([string] $Name) {
  $exe = Join-Path $RepoRoot "output\bin\$Name.exe"
  if (-not (Test-Path -LiteralPath $exe)) { return }
  Write-Host "== smoke test: $Name =="
  Push-Location (Split-Path -Parent $exe)
  try {
    & ".\$Name.exe"
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit $LASTEXITCODE" }
  } finally {
    Pop-Location
  }
  Write-Host "$Name OK"
}

Smoke-Exe -Name "simple_no_v8"
if ($EnableV8) { Smoke-Exe -Name "simple_with_v8" }

Write-Host "Build pipeline done."
