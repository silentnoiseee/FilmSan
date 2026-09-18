<?php
// ============================================================
//  FilmFeed — shareable clip link with a rich preview.
//  WhatsApp / iMessage / Twitter / Facebook scrapers don't run
//  JavaScript, so feed.html#clip=… gives them a blank card.
//  This page serves them proper Open Graph tags (title + video
//  still from Bunny), then instantly forwards real visitors to
//  feed.html#clip=<id>.
//  Link format:  share.php?c=<clip id>
// ============================================================

$id = isset($_GET['c']) ? trim($_GET['c']) : '';

// --- find the clip in videos.js (JSON array after "const VIDEOS=") ---
$clip = null;
if ($id !== '') {
  $raw = @file_get_contents(__DIR__ . '/videos.js');
  if ($raw !== false) {
    $a = strpos($raw, '[');
    $b = strrpos($raw, ']');
    if ($a !== false && $b !== false && $b > $a) {
      $list = json_decode(substr($raw, $a, $b - $a + 1), true);
      if (is_array($list)) {
        foreach ($list as $v) {
          if ((isset($v['id']) && $v['id'] === $id) || (isset($v['file']) && $v['file'] === $id)) { $clip = $v; break; }
        }
      }
    }
  }
}

// --- title, description, still image ---
$title = 'FilmFeed';
$desc  = 'Curated cinema, one clip at a time.';
$img   = '';
if ($clip) {
  $title = $clip['film'] . ' (' . $clip['year'] . ') — FilmFeed';
  $desc  = $clip['start'] . '–' . $clip['end'];
  // Bunny serves a poster frame next to every playlist.
  if (isset($clip['file'])) $img = preg_replace('/playlist\.m3u8.*$/', 'thumbnail.jpg', $clip['file']);
  // Prefer the film synopsis from films.json when we have it.
  $fraw = @file_get_contents(__DIR__ . '/films.json');
  if ($fraw !== false) {
    // strip a UTF-8 BOM if present, or json_decode fails silently
    $fraw = preg_replace('/^\xEF\xBB\xBF/', '', $fraw);
    $films = json_decode($fraw, true);
    if (is_array($films)) {
      foreach ($films as $f) {
        if (isset($f['feed_key']) && $f['feed_key'] === $clip['film'] . '|' . $clip['year']) {
          if (!empty($f['overview'])) $desc = $f['overview'];
          break;
        }
      }
    }
  }
}

// --- absolute URLs (og tags require them) ---
$scheme  = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host    = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '';
$dir     = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'])), '/');
$base    = $scheme . '://' . $host . $dir . '/';
$pageUrl = $base . 'share.php?c=' . rawurlencode($id);
$target  = $base . 'feed.html#clip=' . rawurlencode($id);

// Serve the preview still from OUR domain (thumb.php proxies Bunny) —
// Meta's crawler sometimes fails to load images straight off the CDN.
if ($img !== '') $img = $base . 'thumb.php?c=' . rawurlencode($id);

function h($s) { return htmlspecialchars($s, ENT_QUOTES, 'UTF-8'); }
?><!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= h($title) ?></title>
<meta name="description" content="<?= h($desc) ?>">

<meta property="og:type" content="video.other">
<meta property="og:site_name" content="FilmFeed">
<meta property="og:title" content="<?= h($title) ?>">
<meta property="og:description" content="<?= h($desc) ?>">
<meta property="og:url" content="<?= h($pageUrl) ?>">
<?php if ($img): ?>
<meta property="og:image" content="<?= h($img) ?>">
<meta property="og:image:type" content="image/jpeg">
<meta property="og:image:width" content="1280">
<meta property="og:image:height" content="720">
<?php endif; ?>

<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="<?= h($title) ?>">
<meta name="twitter:description" content="<?= h($desc) ?>">
<?php if ($img): ?>
<meta name="twitter:image" content="<?= h($img) ?>">
<?php endif; ?>

<style>
  body { margin: 0; min-height: 100vh; display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 18px; background: #000; color: #fff;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; text-align: center; }
  img { max-width: min(90vw, 480px); border-radius: 14px; }
  a { color: #fff; font-weight: 700; }
  .sub { color: rgba(255,255,255,.55); font-size: 14px; }
</style>
</head>
<body>
<?php if ($img): ?><img src="<?= h($img) ?>" alt=""><?php endif; ?>
<div><?= h($title) ?></div>
<div class="sub">Opening FilmFeed&hellip; <a href="<?= h($target) ?>">tap here if nothing happens</a></div>
<script>location.replace(<?= json_encode($target) ?>);</script>
</body>
</html>
