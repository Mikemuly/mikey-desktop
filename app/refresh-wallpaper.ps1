# Pushes your edits in .\live-wallpaper into Lively and reloads the wallpaper.
# Usage: right-click > Run with PowerShell   (or: powershell -ExecutionPolicy Bypass -File refresh-wallpaper.ps1)
$src    = Join-Path $PSScriptRoot 'live-wallpaper'
$lively = "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe"
$lib    = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers"

if (-not (Test-Path $lively)) { Write-Host 'Lively Wallpaper is not installed.' -ForegroundColor Yellow; return }

# find this wallpaper's folder in Lively's library (the one whose title ends in "Matrix")
$dest = Get-ChildItem $lib -Directory | Where-Object {
    (Test-Path "$($_.FullName)\LivelyInfo.json") -and ((Get-Content "$($_.FullName)\LivelyInfo.json" -Raw) -match '"Title":\s*"[^"]*Matrix"')
} | Select-Object -First 1 -ExpandProperty FullName
if (-not $dest) { $dest = Join-Path $lib 'mikey-matrix'; New-Item -ItemType Directory -Force $dest | Out-Null }

Copy-Item "$src\*" $dest -Recurse -Force
if (-not (Get-Process Lively -ErrorAction SilentlyContinue)) { Start-Process $lively; Start-Sleep 10 }
Start-Process $lively -ArgumentList 'closewp', '--monitor', '-1'      # unload the old page...
Start-Sleep 2
Start-Process $lively -ArgumentList 'setwp', '--file', "`"$dest`""    # ...and load the new one
Write-Host "Wallpaper refreshed from $src" -ForegroundColor Green
