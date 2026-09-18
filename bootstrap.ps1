$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$stash = Join-Path $env:TEMP ("smartstock_flutter_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $stash | Out-Null
Copy-Item (Join-Path $root "lib") $stash -Recurse
Copy-Item (Join-Path $root "test") $stash -Recurse
Copy-Item (Join-Path $root "pubspec.yaml") $stash
Copy-Item (Join-Path $root "analysis_options.yaml") $stash
Copy-Item (Join-Path $root "README.md") $stash

Push-Location $root
try {
  flutter create --platforms=android,ios,windows,macos,linux,web --org com.smartstock --project-name smartstock_flutter .
  Remove-Item (Join-Path $root "lib") -Recurse -Force
  Remove-Item (Join-Path $root "test") -Recurse -Force
  Copy-Item (Join-Path $stash "lib") $root -Recurse
  Copy-Item (Join-Path $stash "test") $root -Recurse
  Copy-Item (Join-Path $stash "pubspec.yaml") $root -Force
  Copy-Item (Join-Path $stash "analysis_options.yaml") $root -Force
  Copy-Item (Join-Path $stash "README.md") $root -Force
  flutter pub get
  dart run sqflite_common_ffi_web:setup
  Write-Host "SmartStock Flutter platform runners are ready."
} finally {
  Pop-Location
  Remove-Item $stash -Recurse -Force -ErrorAction SilentlyContinue
}
