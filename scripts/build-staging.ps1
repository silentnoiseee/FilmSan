[CmdletBinding()]
param(
  [string]$SourceRoot = (Split-Path -Parent $PSScriptRoot),
  [string]$OutputRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) '.deploy')
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $SourceRoot 'deploy-manifest.txt'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Missing deployment manifest: $manifestPath" }

$source = [IO.Path]::GetFullPath($SourceRoot)
$output = [IO.Path]::GetFullPath($OutputRoot)
if ($output -eq $source -or -not $output.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'OutputRoot must be a child directory of SourceRoot.'
}

if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
New-Item -ItemType Directory -Path $output | Out-Null

$entries = Get-Content -LiteralPath $manifestPath | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }
foreach ($relative in $entries) {
  $sourcePath = [IO.Path]::GetFullPath((Join-Path $source $relative))
  if (-not $sourcePath.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes source root: $relative" }
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Manifest file missing: $relative" }
  $destinationPath = Join-Path $output $relative
  $destinationDir = Split-Path -Parent $destinationPath
  if (-not (Test-Path -LiteralPath $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }
  Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
}

Write-Host ("Built staging artifact: {0} files in {1}" -f $entries.Count, $output)
