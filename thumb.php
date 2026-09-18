<?php
// ============================================================
//  FilmFeed — clip thumbnail proxy.
//  Serves the Bunny video still from OUR domain so link-preview
//  crawlers (Facebook / Instagram / WhatsApp / Twitter) can always
//  load it — some CDNs block or confuse bot user-agents.
//  Usage: thumb.php?c=<clip id>
// ============================================================

$id = isset($_GET['c']) ? trim($_GET['c']) : '';
$img = '';

if ($id !== '') {
  $raw = @file_get_contents(__DIR__ . '/videos.js');
  if ($raw !== false) {
    $a = strpos($raw, '[');
    $b = strrpos($raw, ']');
    if ($a !== false && $b !== false && $b > $a) {
      $list = json_decode(substr($raw, $a, $b - $a + 1), true);
      if (is_array($list)) {
        foreach ($list as $v) {
          if ((isset($v['id']) && $v['id'] === $id) || (isset($v['file']) && $v['file'] === $id)) {
            if (isset($v['file'])) $img = preg_replace('/playlist\.m3u8.*$/', 'thumbnail.jpg', $v['file']);
            break;
          }
        }
      }
    }
  }
}

if ($img === '') { http_response_code(404); exit('not found'); }

// Fetch the still server-side. Prefer cURL (always on at Hostinger) with a
// real browser user-agent — UA-less requests get rejected by some CDNs, and
// allow_url_fopen may be disabled for plain file_get_contents on URLs.
$ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36';
$debug = isset($_GET['debug']);
$data = false;
if (function_exists('curl_init')) {
  $ch = curl_init($img);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_MAXREDIRS      => 3,
    CURLOPT_TIMEOUT        => 12,
    CURLOPT_USERAGENT      => $ua,
    // If the Bunny zone has hotlink/referer protection, present our own site.
    CURLOPT_REFERER        => 'https://cinematicroll.com/',
    CURLOPT_HTTPHEADER     => ['Accept: image/*,*/*'],
  ]);
  $data = curl_exec($ch);
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  $cerr = curl_error($ch);
  curl_close($ch);
  if ($debug) {
    header('Content-Type: text/plain');
    echo "img url:    $img\n";
    echo "curl:       yes\n";
    echo "http code:  $code\n";
    echo "curl error: " . ($cerr ?: '(none)') . "\n";
    echo "bytes:      " . ($data === false ? 'false' : strlen($data)) . "\n";
    exit;
  }
  if ($code < 200 || $code >= 300) $data = false;
} elseif ($debug) {
  header('Content-Type: text/plain');
  echo "img url: $img\ncurl:    NOT AVAILABLE\n";
  exit;
}
if ($data === false) {
  $ctx = stream_context_create(['http' => [
    'timeout' => 12,
    'follow_location' => 1,
    'header' => "User-Agent: $ua\r\nAccept: image/*,*/*\r\nReferer: https://cinematicroll.com/\r\n",
  ]]);
  $data = @file_get_contents($img, false, $ctx);
}
if ($data === false || strlen($data) < 100) { http_response_code(404); exit('no image'); }

header('Content-Type: image/jpeg');
header('Content-Length: ' . strlen($data));
header('Cache-Control: public, max-age=86400');   // let CDNs/browsers cache it a day
echo $data;
