# Backup and patch flutter_inappwebview AndroidManifest in local pub cache
# Usage: Open PowerShell as the same user, then run:
#   .\scripts\patch_flutter_inappwebview_manifest.ps1

$userHome = [Environment]::GetFolderPath('UserProfile')
$paths = @(
    (Join-Path $userHome "AppData\Local\Pub\Cache\hosted\pub.dev"),
    (Join-Path $userHome ".pub-cache\hosted\pub.dev")
)
$found = $false
foreach ($base in $paths) {
    if (Test-Path $base) {
        Get-ChildItem -Path $base -Directory -Filter "flutter_inappwebview-*" -ErrorAction SilentlyContinue | ForEach-Object {
            $dir = $_.FullName
            $manifest = Join-Path $dir "android\src\main\AndroidManifest.xml"
            if (Test-Path $manifest) {
                $found = $true
                $backup = "$manifest.bak"
                if (-not (Test-Path $backup)) {
                    Copy-Item -Path $manifest -Destination $backup -Force
                    Write-Host "Backed up: $manifest -> $backup"
                } else {
                    Write-Host "Backup already exists: $backup"
                }
                (Get-Content $manifest) -replace '(\s*package\s*=\s*"[^"]*")', '' | Set-Content $manifest -Force
                Write-Host "Patched: $manifest"
            }
        }
    }
}
if (-not $found) {
    Write-Warning "No flutter_inappwebview plugin found in local pub cache. Make sure dependencies have been fetched (run 'fvm flutter pub get')."
} else {
    Write-Host "Done. Now run: fvm flutter clean; fvm flutter pub get; fvm flutter run"
}
