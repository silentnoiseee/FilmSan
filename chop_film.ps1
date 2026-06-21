# ============================================================
#  FilmFeed - film chopper
#  Cuts a full film into evenly-sized clips named the way FilmFeed
#  expects, while SKIPPING the end credits (and optional intro logos).
#  Usage: drag a film file onto chop_film.bat  (or double-click and paste the path)
#  Requires ffmpeg + ffprobe on PATH (https://ffmpeg.org , or: winget install Gyan.FFmpeg)
# ============================================================
param([string]$Source)
$ErrorActionPreference = 'Stop'

function HasCmd($c) { $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
if (-not (HasCmd 'ffmpeg') -or -not (HasCmd 'ffprobe')) {
  Write-Host "ffmpeg/ffprobe not found on your PATH." -ForegroundColor Red
  Write-Host "Install it (e.g.  winget install Gyan.FFmpeg  ) then reopen this window." -ForegroundColor Yellow
  Read-Host "Press Enter to exit"; exit 1
}

if (-not $Source) { $Source = Read-Host "Path to the film file" }
$Source = $Source.Trim('"')
if (-not (Test-Path $Source)) { Write-Host "File not found: $Source" -ForegroundColor Red; Read-Host "Enter to exit"; exit 1 }

# Guess title + year from a release-style filename (e.g. Fargo.1996.1080p...)
$base = [IO.Path]::GetFileNameWithoutExtension($Source)
$gTitle = $base; $gYear = ''
if ($base -match '^(?<t>.+?)[\.\s_]+(?<y>(19|20)\d{2})') { $gTitle = ($Matches.t -replace '[\._]',' ').Trim(); $gYear = $Matches.y }

$Title = Read-Host "Film title [$gTitle]"; if (-not $Title) { $Title = $gTitle }
$Year  = Read-Host "Year [$gYear]";        if (-not $Year)  { $Year  = $gYear }
$clipLen = Read-Host "Clip length in seconds [50]"; $clipLen = if ($clipLen) { [int]$clipLen } else { 50 }
$introMin = Read-Host "Skip opening credits / recap from the START, minutes [0]"; $introMin = if ($introMin) { [double]$introMin } else { 0 }
$creditMin = Read-Host "Skip END CREDITS, minutes from the end [7]"; $creditMin = if ($creditMin) { [double]$creditMin } else { 7 }

# Sanitize for Windows file names
$safe = ($Title -replace '[\\/:*?"<>|]', '').Trim()

$dur = [double](& ffprobe -v error -show_entries format=duration -of csv=p=0 "$Source")
$startS = [int][math]::Floor($introMin * 60)
$endS   = [int][math]::Floor($dur - $creditMin * 60)
if ($endS -le $startS) { Write-Host "Those trim values leave no film. Lower the credit/intro trim." -ForegroundColor Red; Read-Host "Enter to exit"; exit 1 }

function TS([int]$s) { '{0:00}.{1:00}.{2:00}' -f [int]($s/3600), [int](($s%3600)/60), [int]($s%60) }

$outDir = Join-Path $PSScriptRoot ("{0} ({1})_clips" -f $safe, $Year)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host ""
Write-Host ("Film runs {0}.  Chopping body {1} -> {2}  (skipping {3} min credits, {4} min intro)" -f (TS ([int]$dur)), (TS $startS), (TS $endS), $creditMin, $introMin) -ForegroundColor Cyan
Write-Host ("Output: {0}" -f $outDir)
Write-Host ""

$n = 0
for ($t = $startS; $t -lt $endS; $t += $clipLen) {
  $len = [math]::Min($clipLen, $endS - $t)
  $a = TS $t; $b = TS ($t + $len)
  $name = "{0} ({1}) - {2}-{3}.mp4" -f $safe, $Year, $a, $b
  $out = Join-Path $outDir $name
  & ffmpeg -nostdin -loglevel error -y -ss $t -i "$Source" -t $len -c copy -avoid_negative_ts make_zero "$out"
  $n++
  Write-Host ("  [{0}] {1} - {2}" -f $n, $a, $b)
}

Write-Host ""
Write-Host ("Done - {0} clips written." -f $n) -ForegroundColor Green
Write-Host "Next:  bunny_upload_all.bat  ->  build_feed_bunny.bat  ->  ingest_films.bat  ->  upload videos.js + films.json"
Read-Host "Press Enter to exit"
