# ============================================================
#  FilmFeed - Bunny Stream bulk uploader
#  Reads bunny_config.json, uploads every clip in *_clips folders
#  to your Bunny Stream library, and records playback IDs to
#  bunny_uploads.json (used later by rebuild_feed).
#
#  Usage (from this folder):
#    Right-click > Run with PowerShell, or:
#      powershell -ExecutionPolicy Bypass -File bunny_upload.ps1            (upload everything)
#      powershell -ExecutionPolicy Bypass -File bunny_upload.ps1 -TestOne  (upload ONE clip only)
# ============================================================

param(
    [switch]$TestOne
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Locate this script's folder and load config ---------------------------
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$configPath = Join-Path $root "bunny_config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: bunny_config.json not found in $root" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
$cfg       = Get-Content $configPath -Raw | ConvertFrom-Json
$libraryId = $cfg.libraryId
$apiKey    = $cfg.apiKey
$base      = "https://video.bunnycdn.com/library/$libraryId"
$headers   = @{ "AccessKey" = $apiKey; "accept" = "application/json" }

$mapPath = Join-Path $root "bunny_uploads.json"
$errPath = Join-Path $root "bunny_upload_errors.log"

# --- Load any prior upload record so re-runs resume -------------------------
$records = @()
if (Test-Path $mapPath) {
    $records = @(Get-Content $mapPath -Raw | ConvertFrom-Json)
}
# Build a quick lookup of already-uploaded relative paths
$done = @{}
foreach ($r in $records) { if ($r.guid) { $done[$r.relpath] = $true } }

function Save-Records {
    ($records | ConvertTo-Json -Depth 6) | Set-Content -Path $mapPath -Encoding UTF8
}

# --- Collections: one per film folder, created on demand -------------------
$collections = @{}   # folderName -> collectionGuid
foreach ($r in $records) {
    if ($r.folder -and $r.collectionId) { $collections[$r.folder] = $r.collectionId }
}
function Get-CollectionId([string]$folderName) {
    if ($collections.ContainsKey($folderName)) { return $collections[$folderName] }
    $body = @{ name = $folderName } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri "$base/collections" -Headers $headers `
                -ContentType "application/json" -Body $body
    $collections[$folderName] = $resp.guid
    return $resp.guid
}

# --- Gather clips ----------------------------------------------------------
$exts = @(".mp4",".MP4",".mkv",".MKV",".webm",".mov",".m4v")
$clipFolders = Get-ChildItem -Path $root -Directory | Where-Object { $_.Name -like "*_clips" }

$allClips = @()
foreach ($folder in $clipFolders) {
    $files = Get-ChildItem -Path $folder.FullName -File -Recurse |
             Where-Object { $exts -contains $_.Extension }
    foreach ($f in $files) { $allClips += [pscustomobject]@{ folder = $folder.Name; file = $f } }
}

if ($allClips.Count -eq 0) {
    Write-Host "No clips found in *_clips folders under $root" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"; exit 0
}

Write-Host ""
Write-Host "Library $libraryId  |  Found $($allClips.Count) clip(s) across $($clipFolders.Count) film folder(s)." -ForegroundColor Cyan
if ($TestOne) { Write-Host "TEST MODE: uploading only the first not-yet-uploaded clip." -ForegroundColor Yellow }
Write-Host ""

# --- Upload loop -----------------------------------------------------------
$uploaded = 0; $skipped = 0; $failed = 0; $i = 0
foreach ($clip in $allClips) {
    $i++
    $relpath = "$($clip.folder)/$($clip.file.Name)"

    if ($done.ContainsKey($relpath)) { $skipped++; continue }

    $title = [System.IO.Path]::GetFileNameWithoutExtension($clip.file.Name)
    Write-Host ("[{0}/{1}] {2}" -f $i, $allClips.Count, $relpath)

    try {
        $collectionId = Get-CollectionId $clip.folder

        # 1) Create the video object
        $createBody = @{ title = $title; collectionId = $collectionId } | ConvertTo-Json
        $created = Invoke-RestMethod -Method Post -Uri "$base/videos" -Headers $headers `
                      -ContentType "application/json" -Body $createBody
        $guid = $created.guid

        # 2) Upload the file bytes (streamed from disk via -InFile)
        Invoke-RestMethod -Method Put -Uri "$base/videos/$guid" -Headers $headers `
            -InFile $clip.file.FullName -ContentType "application/octet-stream" | Out-Null

        $records += [pscustomobject]@{
            relpath      = $relpath
            folder       = $clip.folder
            file         = $clip.file.Name
            title        = $title
            guid         = $guid
            collectionId = $collectionId
        }
        $done[$relpath] = $true
        $uploaded++
        Save-Records   # save after each success so a crash never loses progress

        Write-Host ("      -> uploaded (guid {0})" -f $guid) -ForegroundColor Green
    }
    catch {
        $failed++
        $msg = "$relpath  ::  $($_.Exception.Message)"
        Write-Host ("      -> FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Add-Content -Path $errPath -Value ("{0}  {1}" -f (Get-Date -Format s), $msg)
    }

    if ($TestOne -and $uploaded -ge 1) {
        Write-Host ""
        Write-Host "Test upload complete. Check the clip in your Bunny dashboard (it transcodes for a moment)." -ForegroundColor Cyan
        break
    }
}

Save-Records
Write-Host ""
Write-Host "Done.  Uploaded: $uploaded   Skipped (already done): $skipped   Failed: $failed" -ForegroundColor Cyan
Write-Host "Record written to bunny_uploads.json"
if ($failed -gt 0) { Write-Host "See bunny_upload_errors.log for failures." -ForegroundColor Yellow }
Read-Host "Press Enter to exit"
