param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z]{20}$')]
  [string] $ProjectRef
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$linkedRefPath = Join-Path $repoRoot 'supabase\.temp\project-ref'
if (-not (Test-Path -LiteralPath $linkedRefPath)) {
  throw 'Supabase CLI is not linked. Link the disposable project first.'
}
$linkedRef = (Get-Content -LiteralPath $linkedRefPath -Raw).Trim()
if ($linkedRef -ne $ProjectRef) {
  throw "Linked ref differs from requested test ref: $linkedRef"
}

Push-Location $repoRoot
try {
  # --reveal is deliberately omitted. Only the public legacy anon key is used.
  $keyJson = & npx --no-install supabase projects api-keys `
    --project-ref $ProjectRef --output json 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Could not read public API key metadata.' }
  $keyRows = [string]::Join([Environment]::NewLine, $keyJson) | ConvertFrom-Json
  $publicKey = ($keyRows | Where-Object {
      $_.name -eq 'anon' -and $_.type -eq 'legacy'
    } | Select-Object -First 1).api_key
  if ([string]::IsNullOrWhiteSpace($publicKey) -or $publicKey -notmatch '^eyJ') {
    throw 'Public legacy anon key is unavailable.'
  }

  $env:SUPABASE_TEST_PROJECT_REF = $ProjectRef
  $env:SUPABASE_TEST_DISPOSABLE = '1'
  $env:SUPABASE_URL = "https://${ProjectRef}.supabase.co"
  $env:SUPABASE_ANON_KEY = $publicKey
  & node supabase/tests/live_integration.mjs
  $testExitCode = $LASTEXITCODE
} finally {
  Remove-Item Env:SUPABASE_TEST_PROJECT_REF,Env:SUPABASE_TEST_DISPOSABLE,Env:SUPABASE_URL,Env:SUPABASE_ANON_KEY `
    -ErrorAction SilentlyContinue
  Pop-Location
}
exit $testExitCode
