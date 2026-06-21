# ============================================================
#  FilmFeed - batch film chopper
#  Chops EVERY film in a folder into clips, skipping opening
#  credits/recap and end credits, and writes them all into ONE
#  output folder (one "<Title> (<Year>)_clips" subfolder per film).
#  Usage: drag a FOLDER of films onto chop_folder.bat (or double-click).
#  Requires ffmpeg + ffprobe on PATH.
# ============================================================
param([string]$InputDir)
$ErrorActionPreference = 'Stop'

function HasCmd($c) { $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }
if (-not (HasCmd 'ffmpeg') -or -not (HasCmd 'ffprobe')) {
  Write-Host "ffmpeg/ffprobe not found on your PATH." -ForegroundColor Red
  Write-Host "Install it (e.g.  winget install Gyan.FFmpeg  ) then reopen." -ForegroundColor Yellow
  Read-Host "Press Enter to exit"; exit 1
}

if (-not $InputDir) { $InputDir = Read-Host "Folder containing your film files" }
$InputDir = $InputDir.Trim('"')
if (-not (Test-Path $InputDir)) { Write-Host "Folder not found: $InputDir" -ForegroundColor Red; Read-Host "Enter to exit"; exit 1 }

$OutBase = Read-Host "Output folder for ALL clips [$PSScriptRoot]"
if (-not $OutBase) { $OutBase = $PSScriptRoot } else { $OutBase = $OutBase.Trim('"') }
New-Item -ItemType Directory -Force -Path $OutBase | Out-Null

$clipLen   = Read-Host "Clip length in seconds [50]"; $clipLen = if ($clipLen) { [int]$clipLen } else { 50 }
$introMin  = Read-Host "Skip opening credits / recap, minutes (applied to all) [0]"; $introMin = if ($introMin) { [double]$introMin } else { 0 }
$creditMin = Read-Host "Skip end credits, minutes from the end (applied to all) [7]"; $creditMin = if ($creditMin) { [double]$creditMin } else { 7 }

function TS([int]$s) { '{0:00}.{1:00}.{2:00}' -f [int]($s/3600), [int](($s%3600)/60), [int]($s%60) }

$exts = '.mp4','.mkv','.mov','.m4v','.avi','.webm','.MP4','.MKV'
$films = Get-ChildItem -Path $InputDir -File | Where-Object { $exts -contains $_.Extension }
if (-not $films) { Write-Host "No video files found in that folder." -ForegroundColor Yellow; Read-Host "Enter to exit"; exit 0 }

Write-Host ""
Write-Host ("Found {0} film file(s). Output -> {1}" -f $films.Count, $OutBase) -ForegroundColor Cyan
Write-Host ""

$totalClips = 0; $done = 0; $skipped = @()
foreach ($file in $films) {
  $b = $file.BaseName; $title = $b; $year = ''
  if ($b -match '^(?<t>.+?)[\.\s_]+(?<y>(19|20)\d{2})') { $title = ($Matches.t -replace '[\._]',' ').Trim(); $year = $Matches.y }
  if (-not $year) { Write-Host ("  ! Skipped (no year in name): {0}" -f $file.Name) -ForegroundColor Yellow; $skipped += $file.Name; continue }
  $safe = ($title -replace '[\\/:*?"<>|]','').Trim()

  try {
    $dur = [double](& ffprobe -v error -show_entries format=duration -of csv=p=0 "$($file.FullName)")
    $startS = [int][math]::Floor($introMin * 60)
    $endS   = [int][math]::Floor($dur - $creditMin * 60)
    if ($endS -le $startS) { Write-Host ("  ! Skipped (trim too large): {0}" -f $file.Name) -ForegroundColor Yellow; $skipped += $file.Name; continue }

    $outDir = Join-Path $OutBase ("{0} ({1})_clips" -f $safe, $year)
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    Write-Host ("-> {0} ({1})  [{2} -> {3}]" -f $safe, $year, (TS $startS), (TS $endS)) -ForegroundColor White
    $n = 0
    for ($t = $startS; $t -lt $endS; $t += $clipLen) {
      $len = [math]::Min($clipLen, $endS - $t)
      $name = "{0} ({1}) - {2}-{3}.mp4" -f $safe, $year, (TS $t), (TS ($t + $len))
      & ffmpeg -nostdin -loglevel error -y -ss $t -i "$($file.FullName)" -t $len -c copy -avoid_negative_ts make_zero (Join-Path $outDir $name)
      $n++
    }
    Write-Host ("   {0} clips" -f $n) -ForegroundColor Green
    $totalClips += $n; $done++
  } catch {
    Write-Host ("  ! Failed on {0}: {1}" -f $file.Name, $_.Exception.Message) -ForegroundColor Red; $skipped += $file.Name
  }
}

Write-Host ""
Write-Host ("Done. {0} films -> {1} clips, in {2}" -f $done, $totalClips, $OutBase) -ForegroundColor Cyan
if ($skipped.Count) { Write-Host ("Skipped: {0}" -f ($skipped -join ', ')) -ForegroundColor Yellow; Write-Host "(Tip: rename those to include the year, or chop them with chop_film.bat)" }
Write-Host "Next:  bunny_upload_all.bat  ->  build_feed_bunny.bat  ->  ingest_films.bat  ->  upload videos.js + films.json"
Read-Host "Press Enter to exit"
