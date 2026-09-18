<?php
// Cinematic Roll — server-side TMDB search proxy.
// The key is supplied at runtime and is never committed to Git.

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: public, max-age=3600');

$API_KEY = getenv('TMDB_API_KEY') ?: '';
$runtimeConfig = __DIR__ . '/.runtime-config.php';
if ($API_KEY === '' && is_file($runtimeConfig)) {
  $config = require $runtimeConfig;
  if (is_array($config)) $API_KEY = (string)($config['tmdb_api_key'] ?? '');
}

if ($API_KEY === '') {
  http_response_code(503);
  echo '[]';
  exit;
}

$q = isset($_GET['q']) ? trim($_GET['q']) : '';
if (mb_strlen($q) < 2) { echo '[]'; exit; }
if (mb_strlen($q) > 80) $q = mb_substr($q, 0, 80);

$url = 'https://api.themoviedb.org/3/search/movie?api_key=' . rawurlencode($API_KEY)
     . '&query=' . rawurlencode($q) . '&include_adult=false&language=en-US&page=1';

$data = false;
if (function_exists('curl_init')) {
  $ch = curl_init($url);
  curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 8,
    CURLOPT_USERAGENT => 'CinematicRoll/1.0',
  ]);
  $data = curl_exec($ch);
  curl_close($ch);
}
if ($data === false) {
  $ctx = stream_context_create(['http' => ['timeout' => 8, 'header' => "User-Agent: CinematicRoll/1.0\r\n"]]);
  $data = @file_get_contents($url, false, $ctx);
}
if ($data === false) { http_response_code(502); echo '[]'; exit; }

$json = json_decode($data, true);
$out = [];
foreach (($json['results'] ?? []) as $m) {
  $out[] = [
    'id' => $m['id'],
    'title' => $m['title'] ?? '',
    'year' => !empty($m['release_date']) ? substr($m['release_date'], 0, 4) : '',
    'poster' => !empty($m['poster_path']) ? 'https://image.tmdb.org/t/p/w92' . $m['poster_path'] : '',
  ];
  if (count($out) >= 8) break;
}
echo json_encode($out);
