<#
.SYNOPSIS
  Build shared (component) V8 with GN and stamp into .tools/v8-out for CMake.

Prerequisites: .\scripts\fetch_v8.ps1
#>
param(
  [string] $Config = "x64.release",
  [switch] $SkipFetchCheck
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\Common.ps1"
$RepoRoot = Get-RepoRoot

$dt = Ensure-DepotTools -RepoRoot $RepoRoot
Start-SocksHttpBridge | Out-Null
Ensure-NinjaOnPath
Ensure-ClangClOnPath

$ws = Join-Path $RepoRoot ".tools\v8-workspace"
$v8Dir = Join-Path $ws "v8"
if (-not (Test-Path (Join-Path $v8Dir "include\v8.h"))) {
  if ($SkipFetchCheck) {
    throw "V8 sources not found at $v8Dir"
  }
  Write-Host "V8 sources missing; running fetch_v8.ps1 ..."
  & (Join-Path $PSScriptRoot "fetch_v8.ps1")
}

$outDir = Join-Path $v8Dir "out.gn\$Config"
$argsFile = Join-Path $outDir "args.gn"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Component / shared V8 for CMake SHARED pdfium consumers.
$argsGn = @"
is_debug = false
target_cpu = "x64"
is_component_build = true
is_clang = true
clang_use_chrome_plugins = false
use_lld = true
v8_monolithic = false
v8_use_external_startup_data = false
v8_enable_webassembly = false
v8_enable_temporal_support = false
v8_imminent_deprecation_warnings = false
v8_enable_sandbox = false
v8_enable_i18n_support = false
use_allocator_shim = false
use_partition_alloc_as_malloc = false
treat_warnings_as_errors = false
v8_generate_external_defines_header = true
# Required for this V8 pin on win/clang; consumers must use stamped libc++.
use_custom_libcxx = true
"@
Set-Content -LiteralPath $argsFile -Value $argsGn -Encoding ascii

$vcvarsall = Find-Vcvarsall
$sdkVersion = Get-LatestWindowsSdkVersion

Write-Host "== gn gen $outDir =="
Set-Location $v8Dir
Write-Host "WindowsSDKVersion=$sdkVersion"

if ($sdkVersion) {
  foreach ($rel in @(
      "build\toolchain\win\setup_toolchain.py",
      "build\vs_toolchain.py"
    )) {
    $p = Join-Path $v8Dir $rel
    if (-not (Test-Path -LiteralPath $p)) { continue }
    $text = Get-Content -LiteralPath $p -Raw
    $patched = [regex]::Replace(
      $text,
      "SDK_VERSION = '10\.\d+\.\d+\.\d+'",
      "SDK_VERSION = '$sdkVersion'"
    )
    if ($patched -ne $text) {
      Set-Content -LiteralPath $p -Value $patched -NoNewline
      Write-Host "Patched SDK_VERSION -> $sdkVersion in $rel"
    }
  }
}

$ninjaTargets = "v8 v8_libbase v8_libplatform"
if ($vcvarsall -and $sdkVersion) {
  cmd /c "`"$vcvarsall`" x64 $sdkVersion && gn gen `"$outDir`""
  if ($LASTEXITCODE -ne 0) { throw "gn gen failed" }
  Write-Host "== ninja $ninjaTargets =="
  cmd /c "`"$vcvarsall`" x64 $sdkVersion && ninja -C `"$outDir`" $ninjaTargets"
  if ($LASTEXITCODE -ne 0) { throw "ninja V8 component build failed" }
} elseif ($vcvarsall) {
  cmd /c "`"$vcvarsall`" x64 && gn gen `"$outDir`""
  if ($LASTEXITCODE -ne 0) { throw "gn gen failed" }
  Write-Host "== ninja $ninjaTargets =="
  cmd /c "`"$vcvarsall`" x64 && ninja -C `"$outDir`" $ninjaTargets"
  if ($LASTEXITCODE -ne 0) { throw "ninja V8 component build failed" }
} else {
  & gn gen $outDir
  if ($LASTEXITCODE -ne 0) { throw "gn gen failed" }
  & ninja -C $outDir v8 v8_libbase v8_libplatform
  if ($LASTEXITCODE -ne 0) { throw "ninja V8 component build failed" }
}

$stamp = Get-DefaultPdfiumV8Out -RepoRoot $RepoRoot
$libDst = Join-Path $stamp "lib"
$binDst = Join-Path $stamp "bin"
$v8Link = Join-Path $stamp "v8"
# Clean previous static stamp leftovers.
if (Test-Path $stamp) {
  Remove-Item -Recurse -Force -LiteralPath $libDst -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force -LiteralPath $binDst -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $libDst, $binDst | Out-Null

if (Test-Path -LiteralPath $v8Link) {
  cmd /c "rmdir `"$v8Link`""
}
cmd /c "mklink /J `"$v8Link`" `"$v8Dir`""
if ($LASTEXITCODE -ne 0) { throw "Failed to create junction $v8Link -> $v8Dir" }

function Copy-V8Artifact {
  param([string[]] $Patterns, [string] $DestDir)
  foreach ($pat in $Patterns) {
    Get-ChildItem -LiteralPath $outDir -Filter $pat -File -ErrorAction SilentlyContinue |
      ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $DestDir $_.Name) -Force
        Write-Host "Stamped $($_.Name) -> $DestDir"
      }
  }
}

# Import libs → lib/; DLLs → bin/
Copy-V8Artifact -Patterns @(
  "v8.dll.lib", "v8_libbase.dll.lib", "v8_libplatform.dll.lib",
  "libc++.dll.lib", "v8.lib", "v8_libbase.lib", "v8_libplatform.lib", "libc++.lib"
) -DestDir $libDst
Copy-V8Artifact -Patterns @(
  "v8.dll", "v8_libbase.dll", "v8_libplatform.dll", "libc++.dll"
) -DestDir $binDst

# Also scoop GN transitive DLLs (abseil / zlib / PA), but not MSVC CRT or debugger kits.
Get-ChildItem -LiteralPath $outDir -Filter *.dll -File -ErrorAction SilentlyContinue |
  Where-Object {
    $n = $_.Name.ToLowerInvariant()
    $n -notmatch '^(msvc|vcruntime|vccorlib|concrt|ucrtbase|api-ms-|dbghelp|dbgcore|symsrv|msdia)'
  } |
  ForEach-Object {
    $dst = Join-Path $binDst $_.Name
    if (-not (Test-Path $dst)) {
      Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
      Write-Host "Stamped extra DLL $($_.Name)"
    }
  }
Get-ChildItem -LiteralPath $outDir -Filter *.dll.lib -File -ErrorAction SilentlyContinue |
  Where-Object {
    $n = $_.Name.ToLowerInvariant()
    $n -notmatch '^(msvc|vcruntime|vccorlib|concrt|ucrtbase|api-ms-|dbghelp|dbgcore|symsrv|msdia)'
  } |
  ForEach-Object {
    $dst = Join-Path $libDst $_.Name
    if (-not (Test-Path $dst)) {
      Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
    }
  }

if (-not (Test-Path (Join-Path $binDst "v8.dll")) -and -not (Test-Path (Join-Path $libDst "v8.dll.lib"))) {
  # Fallback: recursive search (some GN layouts nest differently).
  $hit = Get-ChildItem -LiteralPath $outDir -Recurse -Filter "v8.dll" -File -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($hit) {
    Copy-Item $hit.FullName (Join-Path $binDst "v8.dll") -Force
    $impl = Join-Path $hit.DirectoryName "v8.dll.lib"
    if (Test-Path $impl) { Copy-Item $impl (Join-Path $libDst "v8.dll.lib") -Force }
  }
}
if (-not (Test-Path (Join-Path $binDst "v8.dll"))) {
  throw "v8.dll not found under $outDir after component build"
}

# Also archive Chromium libc++ objs for embedding into pdfium.dll (STATIC
# visibility). V8.dll still uses bin/libc++.dll at runtime.
$libcxxObjs = Join-Path $outDir "obj\buildtools\third_party\libc++\libc++"
if (Test-Path -LiteralPath $libcxxObjs) {
  $libcxxOut = Join-Path $libDst "libc++.lib"
  $objs = @(Get-ChildItem -LiteralPath $libcxxObjs -Filter *.obj | ForEach-Object { $_.FullName })
  if ($objs.Count -gt 0) {
    $libExe = Get-Command lib.exe -ErrorAction SilentlyContinue
    $llvmLib = Join-Path ${env:ProgramFiles} "LLVM\bin\llvm-lib.exe"
    if ($libExe) {
      & lib.exe "/OUT:$libcxxOut" @objs
    } elseif (Test-Path $llvmLib) {
      & $llvmLib "/OUT:$libcxxOut" @objs
    } else {
      Write-Warning "lib.exe/llvm-lib.exe not found; skip static libc++.lib"
    }
    if (Test-Path $libcxxOut) {
      Write-Host "Stamped static libc++.lib ($($objs.Count) objs) for pdfium embed"
    }
  }
}

# libc++ headers for CMake ABI.
$incStamp = Join-Path $stamp "include"
New-Item -ItemType Directory -Force -Path $incStamp | Out-Null
$libcxxSrcInclude = Join-Path $v8Dir "third_party\libc++\src\include"
$libcxxConfigDir = Join-Path $v8Dir "buildtools\third_party\libc++"
$libcxxConfigSiteGen = Join-Path $outDir "gen\third_party\libc++\src\include"
if (Test-Path $libcxxSrcInclude) {
  $cxxLink = Join-Path $incStamp "c++"
  if (Test-Path $cxxLink) { cmd /c "rmdir `"$cxxLink`"" }
  cmd /c "mklink /J `"$cxxLink`" `"$libcxxSrcInclude`""
}
$cfgLink = Join-Path $incStamp "c++config"
if (Test-Path $cfgLink) { cmd /c "rmdir `"$cfgLink`"" }
if (Test-Path (Join-Path $libcxxConfigSiteGen "__config_site")) {
  cmd /c "mklink /J `"$cfgLink`" `"$libcxxConfigSiteGen`""
} elseif (Test-Path (Join-Path $libcxxConfigDir "__config_site")) {
  New-Item -ItemType Directory -Force -Path $cfgLink | Out-Null
  Copy-Item -LiteralPath (Join-Path $libcxxConfigDir "__config_site") `
    -Destination (Join-Path $cfgLink "__config_site") -Force
  $assertion = Join-Path $libcxxConfigDir "__assertion_handler"
  if (Test-Path $assertion) {
    Copy-Item -LiteralPath $assertion `
      -Destination (Join-Path $cfgLink "__assertion_handler") -Force
  }
} else {
  throw "libc++ __config_site not found"
}

$v8GnHdr = Join-Path $outDir "gen\include\v8-gn.h"
if (-not (Test-Path $v8GnHdr)) {
  $v8GnHdr = Join-Path $outDir "gen\v8\include\v8-gn.h"
}
if (Test-Path $v8GnHdr) {
  Copy-Item -LiteralPath $v8GnHdr -Destination (Join-Path $incStamp "v8-gn.h") -Force
  Copy-Item -LiteralPath $v8GnHdr -Destination (Join-Path $v8Dir "include\v8-gn.h") -Force
  Write-Host "Stamped v8-gn.h"
}

foreach ($blob in @("snapshot_blob.bin", "icudtl.dat")) {
  $src = Join-Path $outDir $blob
  if (Test-Path -LiteralPath $src) {
    Copy-Item -LiteralPath $src -Destination (Join-Path $binDst $blob) -Force
  }
}

Set-Content -LiteralPath (Join-Path $stamp "V8_SHARED.txt") -Value "component" -Encoding ascii
$revFile = Join-Path $ws "V8_REVISION.txt"
$rev = if (Test-Path $revFile) { (Get-Content $revFile -Raw).Trim() } else { Get-PdfiumV8Revision -RepoRoot $RepoRoot }
Set-Content -LiteralPath (Join-Path $stamp "V8_REVISION.txt") -Value $rev -Encoding ascii

$env:PDFIUM_V8_ROOT = $stamp
Write-Host "Stamped shared V8 product tree: $stamp"
Write-Host "Next: .\scripts\build.ps1 -EnableV8"
