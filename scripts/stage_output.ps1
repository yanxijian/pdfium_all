<#
.SYNOPSIS
  Copy PDFium CMake build products into pdfium_all/output/
#>
param(
  [Parameter(Mandatory = $true)]
  [string] $BuildDir,

  [string] $Config = "Release"
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

$exe = Resolve-OneArtifact -FileName "simple_no_v8.exe"
if (-not $exe) { $exe = Resolve-OneArtifact -FileName "simple_no_v8" }
if ($exe) {
  Copy-Item -LiteralPath $exe -Destination $binDst -Force
  Write-Host "Staged bin: $exe"
  # Runtime DLLs next to the sample (vcpkg shared deps), if present.
  $exeDir = Split-Path -Parent $exe
  Get-ChildItem -LiteralPath $exeDir -Filter *.dll -File -ErrorAction SilentlyContinue |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination $binDst -Force
      Write-Host "Staged bin: $($_.Name)"
    }
}

Write-Host "Done. Output root: $OutRoot"
