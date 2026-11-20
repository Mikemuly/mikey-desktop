<#
.SYNOPSIS
    Removes what install.ps1 set up. Run elevated to also undo the lock-screen changes.
.EXAMPLE
    .\uninstall.ps1                 # undo settings, keep the installed files
    .\uninstall.ps1 -RemoveFiles    # also delete the install folder
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]+$')][string]$Name = 'Mikey',
    [string]$InstallDir = "$env:USERPROFILE\DesktopBot",
    [switch]$RemoveFiles
)
$upper = $Name.ToUpper(); $lower = $Name.ToLower()
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function Step($m) { Write-Host "==> $m" -ForegroundColor Green }

Step 'Stopping the bot'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like "*$InstallDir\*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Step 'Removing autostart entries'
$startup = [Environment]::GetFolderPath('Startup')
Remove-Item "$startup\$upper-BOT.vbs", "$startup\$upper Welcome.vbs" -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "$upper Access Granted" -Confirm:$false -ErrorAction SilentlyContinue

Step 'Screensaver'
$k = 'HKCU:\Control Panel\Desktop'
if ((Get-ItemProperty $k).'SCRNSAVE.EXE' -like "$InstallDir*") { Remove-ItemProperty $k 'SCRNSAVE.EXE'; Set-ItemProperty $k ScreenSaveActive '0' }

Step 'PowerShell prompt'
$prof = "$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if ((Test-Path $prof) -and (Select-String -Path $prof -Pattern 'hacker prompt' -Quiet)) {
    $bak = Get-ChildItem "$prof.bak-*" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if ($bak) { Copy-Item $bak.FullName $prof -Force; Write-Host '    restored previous profile' } else { Remove-Item $prof }
}

Step 'Lock screen'
if ($isAdmin) {
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' NoLockScreen -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' DisableAcrylicBackgroundOnLogon -ErrorAction SilentlyContinue
    $csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
    if ((Get-ItemProperty $csp -ErrorAction SilentlyContinue).LockScreenImagePath -like '*TechWallpaper*') {
        Remove-ItemProperty $csp LockScreenImagePath, LockScreenImageUrl, LockScreenImageStatus -ErrorAction SilentlyContinue
    }
} else { Write-Host '    ! run elevated to undo the lock-screen changes' -ForegroundColor Yellow }

Remove-Item "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\$lower-matrix" -Recurse -Force -ErrorAction SilentlyContinue

if ($RemoveFiles) { Step "Deleting $InstallDir"; Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "`nDone. Not touched: Lively Wallpaper, TranslucentTB, Windows Terminal theme (a .bak of the old settings.json sits next to it), wallpaper image." -ForegroundColor Green
