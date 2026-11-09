param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArguments
)
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$tooling = Join-Path $project '.tooling'
$environmentNames = @('APPDATA','PUB_CACHE','GRADLE_USER_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_NDK_HOME','ANDROID_USER_HOME','DART_SUPPRESS_ANALYTICS','FLUTTER_SUPPRESS_ANALYTICS','CI')
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$env:APPDATA = Join-Path $tooling 'appdata'
$env:PUB_CACHE = Join-Path $tooling 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $tooling 'gradle'
$localAndroidSdk = Join-Path $tooling 'android-sdk'
$configuredAndroidSdk = [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'Process')
if ((Test-Path -LiteralPath (Join-Path $localAndroidSdk 'platforms')) -or
    [string]::IsNullOrWhiteSpace($configuredAndroidSdk)) {
  if (Test-Path -LiteralPath (Join-Path $localAndroidSdk 'platforms')) {
    $env:ANDROID_HOME = $localAndroidSdk
  } elseif (Test-Path -LiteralPath 'C:\Users\Usuario\AppData\Local\Android\Sdk') {
    $env:ANDROID_HOME = 'C:\Users\Usuario\AppData\Local\Android\Sdk'
  } else {
    $env:ANDROID_HOME = $localAndroidSdk
  }
} else {
  $env:ANDROID_HOME = $configuredAndroidSdk
}
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$localNdk = Join-Path $env:ANDROID_HOME 'ndk\28.2.13676358'
if (Test-Path -LiteralPath $localNdk) {
  $env:ANDROID_NDK_HOME = $localNdk
}
$env:ANDROID_USER_HOME = Join-Path $tooling 'android-user'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$flutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand)
$dart = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$snapshot = Join-Path $flutterRoot 'bin\cache\flutter_tools.snapshot'
Push-Location -LiteralPath $project
try {
  & $dart $snapshot --suppress-analytics --no-version-check @FlutterArguments
  exit $LASTEXITCODE
} finally {
  Pop-Location
  foreach ($name in $environmentNames) {
    [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
  }
}
