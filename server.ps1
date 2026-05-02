param(
  [int]$Port = 5173,
  [string]$Root = (Get-Location).Path
)

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add(("http://localhost:{0}/" -f $Port))
$listener.Start()

Write-Host ("Serving '{0}' at http://localhost:{1}/  (Ctrl+C to stop)" -f $Root, $Port)

function Get-ContentType([string]$path) {
  switch -Regex ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
    '\.html?$' { 'text/html; charset=utf-8' }
    '\.css$'   { 'text/css; charset=utf-8' }
    '\.js$'    { 'text/javascript; charset=utf-8' }
    '\.json$'  { 'application/json; charset=utf-8' }
    '\.svg$'   { 'image/svg+xml' }
    '\.png$'   { 'image/png' }
    '\.jpe?g$' { 'image/jpeg' }
    '\.gif$'   { 'image/gif' }
    '\.webp$'  { 'image/webp' }
    '\.ico$'   { 'image/x-icon' }
    '\.woff2$' { 'font/woff2' }
    '\.woff$'  { 'font/woff' }
    '\.ttf$'   { 'font/ttf' }
    default    { 'application/octet-stream' }
  }
}

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    try {
      $relative = [Uri]::UnescapeDataString($request.Url.AbsolutePath.TrimStart('/'))
      if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }

      $candidate = Join-Path $Root $relative
      $full = [IO.Path]::GetFullPath($candidate)
      $rootFull = [IO.Path]::GetFullPath($Root)

      if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $response.StatusCode = 403
        $bytes = [Text.Encoding]::UTF8.GetBytes('Forbidden')
        $response.ContentType = 'text/plain; charset=utf-8'
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        continue
      }

      if (Test-Path $full -PathType Container) {
        $full = Join-Path $full 'index.html'
      }

      if (-not (Test-Path $full -PathType Leaf)) {
        $response.StatusCode = 404
        $bytes = [Text.Encoding]::UTF8.GetBytes('Not Found')
        $response.ContentType = 'text/plain; charset=utf-8'
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        continue
      }

      $response.StatusCode = 200
      $response.ContentType = Get-ContentType $full
      $fileBytes = [IO.File]::ReadAllBytes($full)
      $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
    } catch {
      $response.StatusCode = 500
      $bytes = [Text.Encoding]::UTF8.GetBytes(("Server error: {0}" -f $_.Exception.Message))
      $response.ContentType = 'text/plain; charset=utf-8'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } finally {
      $response.OutputStream.Close()
    }
  }
} finally {
  $listener.Stop()
  $listener.Close()
}

