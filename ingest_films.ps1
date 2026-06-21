# ============================================================
#  FilmFeed - TMDB ingestion (PowerShell)
#  Reads the films currently in videos.js, looks each up on TMDB,
#  and writes films.json (poster, director, cast, synopsis, streaming).
#  So: add clips -> bunny_upload_all -> build_feed_bunny -> THIS.
#  Run: double-click ingest_films.bat
# ============================================================
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$cfg = Get-Content (Join-Path $root 'tmdb_config.json') -Raw | ConvertFrom-Json
$KEY = $cfg.apiKey
$IMG = 'https://image.tmdb.org/t/p/'
$REGIONS = @('US','GB','CA','AU')

# Known films -> exact TMDB id (avoids wrong matches on ambiguous titles).
# New films not listed here are matched automatically by title + year.
$OVERRIDES = @{
  'A Haunted House|2013' = 139038; 'Fargo|1996' = 275; 'Paprika|2006' = 4977;
  'Phantom Thread|2017' = 400617; 'Punch Drunk Love|2002' = 8051; 'Snowpiercer|2013' = 110415;
  'The Master|2012' = 68722; 'The Wailing|2016' = 293670; 'Under the Skin|2013' = 97370
}

function Slugify($name, $year) { (($name.ToLower() -replace '[^a-z0-9]+','-').Trim('-')) + '-' + $year }
function ImgUrl($p, $size) { if ($p) { "$IMG$size$p" } else { $null } }
function MapProv($list) { @($list | ForEach-Object { [ordered]@{ name = $_.provider_name; logo = (ImgUrl $_.logo_path 'original') } }) }

# ---- Read the unique films from videos.js ----
$vjs = Get-Content (Join-Path $root 'videos.js') -Raw
$arr = $vjs.Substring($vjs.IndexOf('['))
$arr = $arr.Substring(0, $arr.LastIndexOf(']') + 1)
$vids = $arr | ConvertFrom-Json
$seen = @{}; $FILMS = @()
foreach ($v in $vids) {
  $k = "$($v.film)|$($v.year)"
  if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $FILMS += [pscustomobject]@{ name = $v.film; year = $v.year } }
}
Write-Host ("Found {0} films in videos.js." -f $FILMS.Count) -ForegroundColor Cyan

$out = @()
foreach ($f in $FILMS) {
  Write-Host ("Fetching {0} ({1})... " -f $f.name, $f.year) -NoNewline
  try {
    $key = "$($f.name)|$($f.year)"
    $id = $OVERRIDES[$key]
    if (-not $id) {
      $q = [uri]::EscapeDataString($f.name)
      $search = Invoke-RestMethod -Uri "https://api.themoviedb.org/3/search/movie?api_key=$KEY&query=$q&year=$($f.year)"
      if ($search.results.Count -gt 0) { $id = $search.results[0].id }
    }
    if (-not $id) { Write-Host "no TMDB match" -ForegroundColor Yellow; continue }

    $d = Invoke-RestMethod -Uri "https://api.themoviedb.org/3/movie/$id`?api_key=$KEY&append_to_response=credits,watch/providers"
    $director = (($d.credits.crew | Where-Object { $_.job -eq 'Director' } | ForEach-Object { $_.name }) -join ', ')
    $cast = @($d.credits.cast | Select-Object -First 12 | ForEach-Object {
      [ordered]@{ name = $_.name; character = $_.character; photo_url = (ImgUrl $_.profile_path 'w185') }
    })
    $providers = [ordered]@{}
    foreach ($r in $REGIONS) {
      $reg = $d.'watch/providers'.results.$r
      if ($reg) {
        $entry = [ordered]@{}
        if ($reg.flatrate) { $entry.stream = (MapProv $reg.flatrate) }
        if ($reg.rent)     { $entry.rent  = (MapProv $reg.rent) }
        if ($reg.buy)      { $entry.buy   = (MapProv $reg.buy) }
        if ($entry.Keys.Count -gt 0) { $providers[$r] = $entry }
      }
    }
    $out += [ordered]@{
      tmdb_id = $id; slug = (Slugify $f.name $f.year); feed_key = $key
      title = $d.title; year = $f.year; director = $director
      overview = $d.overview; tagline = $d.tagline; runtime = $d.runtime
      poster_url = (ImgUrl $d.poster_path 'w500'); backdrop_url = (ImgUrl $d.backdrop_path 'w1280')
      genres = @($d.genres | ForEach-Object { $_.name }); cast_list = $cast
      watch_providers = $providers; tmdb_rating = $d.vote_average
    }
    Write-Host "ok" -ForegroundColor Green
    Start-Sleep -Milliseconds 250
  } catch {
    Write-Host ("FAILED: " + $_.Exception.Message) -ForegroundColor Red
  }
}

($out | ConvertTo-Json -Depth 8) | Set-Content -Path (Join-Path $root 'films.json') -Encoding UTF8
Write-Host ""
Write-Host ("Wrote films.json with {0} films." -f $out.Count) -ForegroundColor Cyan
