<#
.SYNOPSIS
  Copy PDFium CMake build products into pdfium_all/output/
#>
param(
  [Parameter(Mandatory = $true)]
  [string] $BuildDir,

  [string] $Config = "Release",
  [string] $V8Root = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutRoot = Join-Path $RepoRoot "output"
$PdfiumRoot = Join-Path $RepoRoot "pdfium"

if (-not (Test-Path -LiteralPath $BuildDir)) {
  throw "BuildDir not found: $BuildDir"
}

$includeDst = Join-Path $OutRoot "include\pdfium"
$libDst = Join-Path $OutRoot "lib"
$binDst = Join-Path $OutRoot "bin"
$publicDst = Join-Path $includeDst "public"

New-Item -ItemType Directory -Force -Path $includeDst, $libDst, $binDst | Out-Null
if (Test-Path -LiteralPath $publicDst) {
  Remove-Item -Recurse -Force -LiteralPath $publicDst
}
New-Item -ItemType Directory -Force -Path $publicDst | Out-Null

$publicSrc = Join-Path $PdfiumRoot "public"
if (-not (Test-Path -LiteralPath $publicSrc)) {
  throw "Missing pdfium/public at $publicSrc"
}

Get-ChildItem -LiteralPath $publicSrc -Recurse -Filter *.h | ForEach-Object {
  $rel = $_.FullName.Substring($publicSrc.Length).TrimStart('\', '/')
  $dest = Join-Path $publicDst $rel
  $destDir = Split-Path -Parent $dest
  if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  }
  Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
}
Write-Host "Staged headers -> $publicDst"

function Resolve-OneArtifact {
  param([string] $FileName)
  $paths = New-Object System.Collections.Generic.List[string]
  [void]$paths.Add((Join-Path $BuildDir $FileName))
  [void]$paths.Add((Join-Path (Join-Path $BuildDir $Config) $FileName))
  [void]$paths.Add((Join-Path (Join-Path $BuildDir "lib") $FileName))
  [void]$paths.Add((Join-Path (Join-Path (Join-Path $BuildDir $Config) "lib") $FileName))
  foreach ($c in $paths) {
    if (Test-Path -LiteralPath $c) {
      return (Resolve-Path -LiteralPath $c).Path
    }
  }
  $hit = Get-ChildItem -LiteralPath $BuildDir -Recurse -Filter $FileName -File -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -ne $hit) { return $hit.FullName }
  return $null
}

$lib = Resolve-OneArtifact -FileName "pdfium.lib"
if (-not $lib) { $lib = Resolve-OneArtifact -FileName "libpdfium.a" }
if (-not $lib) { $lib = Resolve-OneArtifact -FileName "libpdfium.lib" }
if ($lib) {
  Copy-Item -LiteralPath $lib -Destination $libDst -Force
  Write-Host "Staged lib: $lib"
} else {
  Write-Warning "No pdfium library found under $BuildDir"
}

$dll = Resolve-OneArtifact -FileName "pdfium.dll"
if (-not $dll) { $dll = Resolve-OneArtifact -FileName "libpdfium.so" }
if (-not $dll) { $dll = Resolve-OneArtifact -FileName "libpdfium.dylib" }
if ($dll) {
  Copy-Item -LiteralPath $dll -Destination $binDst -Force
  Write-Host "Staged bin: $dll"
}

$pdb = Resolve-OneArtifact -FileName "pdfium.pdb"
if ($pdb) {
  Copy-Item -LiteralPath $pdb -Destination $binDst -Force
}

function Stage-SampleExe([string] $Name) {
  $exe = Resolve-OneArtifact -FileName "$Name.exe"
  if (-not $exe) { $exe = Resolve-OneArtifact -FileName $Name }
  if (-not $exe) { return $null }
  Copy-Item -LiteralPath $exe -Destination $binDst -Force
  Write-Host "Staged bin: $exe"
  $exeDir = Split-Path -Parent $exe
  Get-ChildItem -LiteralPath $exeDir -Filter *.dll -File -ErrorAction SilentlyContinue |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $binDst -Force
      Write-Host "Staged bin: $($_.Name)"
    }
  foreach ($blob in @("snapshot_blob.bin", "icudtl.dat")) {
    $src = Join-Path $exeDir $blob
    if (Test-Path -LiteralPath $src) {
      Copy-Item -LiteralPath $src -Destination $binDst -Force
      Write-Host "Staged bin: $blob"
    }
  }
  return $exe
}

Stage-SampleExe -Name "simple_no_v8" | Out-Null
Stage-SampleExe -Name "simple_with_v8" | Out-Null

# Also stage shared V8 runtimes from the stamp (in case POST_BUILD skipped some).
if (-not $V8Root) {
  if ($env:PDFIUM_V8_ROOT) { $V8Root = $env:PDFIUM_V8_ROOT }
  else {
    $def = Join-Path $RepoRoot ".tools\v8-out"
    if (Test-Path (Join-Path $def "bin\v8.dll")) { $V8Root = $def }
  }
}
if ($V8Root) {
  $v8Bin = Join-Path $V8Root "bin"
  if (Test-Path -LiteralPath $v8Bin) {
    Get-ChildItem -LiteralPath $v8Bin -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in '.dll','.so','.dylib' -or $_.Name -in 'snapshot_blob.bin','icudtl.dat' } |
      ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $binDst -Force
        Write-Host "Staged V8 runtime: $($_.Name)"
      }
  }
  $v8Lib = Join-Path $V8Root "lib"
  if (Test-Path -LiteralPath $v8Lib) {
    Get-ChildItem -LiteralPath $v8Lib -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in '.lib','.a' -or $_.Name -like '*.dll.lib' } |
      ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $libDst -Force
        Write-Host "Staged V8 lib: $($_.Name)"
      }
  }
}

Write-Host "Done. Output root: $OutRoot"
