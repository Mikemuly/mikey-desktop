<#
.SYNOPSIS
    Installs the MIKEY hacker desktop: talking robot (MIKEY-BOT), binary-rain wallpapers,
    screensaver, ACCESS GRANTED unlock screen, lock screen, hacker PowerShell prompt and
    Windows Terminal theme.

.EXAMPLE
    .\install.ps1                       # everything, bot named "Mikey"
    .\install.ps1 -Name Neo             # rename the bot/user to "Neo"
    .\install.ps1 -NoLockClock          # also skip the lock-screen clock (admin)
    .\install.ps1 -DesktopTweaks        # also dark mode + green accent + hide desktop icons
    .\install.ps1 -IconFolders C:\code\app1, C:\code\app2

    Run from an elevated PowerShell to also set the lock screen image.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]+$')][string]$Name = 'Mikey',
    [string]$InstallDir = "$env:USERPROFILE\DesktopBot",
    [switch]$SkipVoice,          # don't create the Python venv / record the Aria voice clips
    [switch]$SkipScreensaver,
    [switch]$SkipWallpaper,
    [switch]$SkipLockScreen,
    [switch]$SkipProfile,        # don't install the hacker PowerShell prompt
    [switch]$SkipTerminalTheme,
    [switch]$SkipAutostart,      # don't start the bot / ACCESS GRANTED screen automatically
    [switch]$NoLockClock,        # skip the clock screen; go straight to the password box (admin)
    [switch]$DesktopTweaks,      # dark mode, neon-green accent, hide desktop icons
    [string[]]$IconFolders = @()
)
$ErrorActionPreference = 'Stop'
$repo  = $PSScriptRoot
$upper = $Name.ToUpper(); $lower = $Name.ToLower()
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Green }
function Note($m) { Write-Host "    $m" -ForegroundColor DarkGray }
function Warn($m) { Write-Host "    ! $m" -ForegroundColor Yellow }
function Set-Name([string]$path) {   # replace Mikey/MIKEY/mikey with the chosen name
    if ($Name -ceq 'Mikey') { return }
    $t = [IO.File]::ReadAllText($path)
    $t = $t.Replace('MIKEY', $upper).Replace('Mikey', $Name).Replace('mikey', $lower)
    [IO.File]::WriteAllText($path, $t, (New-Object Text.UTF8Encoding $false))
}

# ---------------------------------------------------------------- copy app
Step "Installing to $InstallDir"
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like "*$InstallDir\*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Note 'stopped running bot / watcher' }
New-Item -ItemType Directory -Force $InstallDir | Out-Null
Copy-Item "$repo\app\*" $InstallDir -Recurse -Force
Get-ChildItem $InstallDir -Recurse -File -Include *.ps1, *.cs, *.json, *.html |
    Where-Object { $_.FullName -notlike '*\tts-venv\*' } | ForEach-Object { Set-Name $_.FullName }

# Live wallpaper: fill in this PC's details
$os  = (Get-CimInstance Win32_OperatingSystem).Caption -replace '^Microsoft ', ''
$cpu = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\(R\)|\(TM\)|CPU ', '' -replace '\s+', ' ').Trim()
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
$ram = '{0} GB' -f [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$html = "$InstallDir\live-wallpaper\index.html"
$t = [IO.File]::ReadAllText($html)
foreach ($kv in @{ '{{NAME}}' = $Name; '{{USER}}' = $env:USERNAME; '{{HOST}}' = $env:COMPUTERNAME; '{{OS}}' = $os; '{{CPU}}' = $cpu; '{{GPU}}' = $gpu; '{{RAM}}' = $ram }.GetEnumerator()) {
    $t = $t.Replace($kv.Key, $kv.Value)
}
[IO.File]::WriteAllText($html, $t, (New-Object Text.UTF8Encoding $false))
$info = "$InstallDir\live-wallpaper\LivelyInfo.json"
[IO.File]::WriteAllText($info, ([IO.File]::ReadAllText($info).Replace('Mikey Matrix', "$Name Matrix")), (New-Object Text.UTF8Encoding $false))

# ---------------------------------------------------------------- voice (Aria)
if (-not $SkipVoice) {
    Step 'Recording the Aria voice clips (edge-tts, needs internet once)'
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
    if (-not $py) { Warn 'Python not found - the bot will work but stay silent. Install Python 3 and re-run.' }
    else {
        $venv = "$InstallDir\tts-venv"
        if (-not (Test-Path "$venv\Scripts\python.exe")) { & $py.Source -m venv $venv }
        & "$venv\Scripts\python.exe" -m pip install --quiet --disable-pip-version-check -r "$InstallDir\voice\requirements.txt"
        & "$venv\Scripts\python.exe" -I "$InstallDir\voice\record.py" --force
        Note "$((Get-ChildItem "$InstallDir\voice\*.mp3").Count) clips recorded"
    }
}

# ---------------------------------------------------------------- screensaver
if (-not $SkipScreensaver) {
    Step 'Building the binary-rain screensaver'
    $csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    $scr = "$InstallDir\screensaver\MatrixRain.scr"
    & $csc /nologo /target:winexe "/out:$scr" /r:System.Windows.Forms.dll /r:System.Drawing.dll "$InstallDir\screensaver\MatrixRain.cs"
    if ($LASTEXITCODE -ne 0) { Warn 'screensaver build failed' }
    else {
        $k = 'HKCU:\Control Panel\Desktop'
        Set-ItemProperty $k 'SCRNSAVE.EXE' $scr
        Set-ItemProperty $k ScreenSaveActive '1'
        Set-ItemProperty $k ScreenSaveTimeOut '300'
        Note 'starts after 5 minutes idle'
    }
}

# ---------------------------------------------------------------- wallpapers
if (-not $SkipWallpaper) {
    Step 'Wallpaper'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\make-wallpaper.ps1" -Name $Name | Out-Null
    Note 'static wallpaper set (fallback)'
    $lively = "$env:LOCALAPPDATA\Programs\Lively Wallpaper\Lively.exe"
    if (Test-Path $lively) {
        $lib = "$env:LOCALAPPDATA\Lively Wallpaper\Library\wallpapers\$lower-matrix"
        New-Item -ItemType Directory -Force $lib | Out-Null
        Copy-Item "$InstallDir\live-wallpaper\*" $lib -Force
        if (-not (Get-Process Lively -ErrorAction SilentlyContinue)) { Start-Process $lively; Start-Sleep 12 }
        else { Get-Process Lively* | Stop-Process -Force; Start-Sleep 2; Start-Process $lively; Start-Sleep 12 }   # reload library
        Start-Process $lively -ArgumentList 'setwp', '--file', "`"$lib`""
        Note 'live binary-rain wallpaper set in Lively'
    } else {
        Warn 'Lively Wallpaper not installed - for the animated wallpaper run:'
        Note '  winget install rocksdanister.LivelyWallpaper   then re-run this script'
    }
}

# ---------------------------------------------------------------- lock screen
if (-not $SkipLockScreen) {
    Step 'Lock screen'
    if ($isAdmin) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\make-lockscreen.ps1" -Name $upper | Out-Null
        Note 'SYSTEM LOCKED image set'
    } else { Warn 'needs an elevated PowerShell - skipped' }
}
if ($NoLockClock) {
    Step 'Skipping the lock-screen clock'
    if ($isAdmin) {
        $p1 = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; New-Item $p1 -Force | Out-Null
        Set-ItemProperty $p1 NoLockScreen 1 -Type DWord
        $p2 = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; if (-not (Test-Path $p2)) { New-Item $p2 -Force | Out-Null }
        Set-ItemProperty $p2 DisableAcrylicBackgroundOnLogon 1 -Type DWord
        Note 'lock/wake now goes straight to the password box'
    } else { Warn 'needs an elevated PowerShell - skipped' }
}

# ---------------------------------------------------------------- PowerShell prompt
if (-not $SkipProfile) {
    Step 'Hacker PowerShell prompt'
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $prof = "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    New-Item -ItemType Directory -Force (Split-Path $prof) | Out-Null
    if ((Test-Path $prof) -and -not (Select-String -Path $prof -Pattern 'hacker prompt' -Quiet)) {
        Copy-Item $prof "$prof.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"; Note 'existing profile backed up'
    }
    Copy-Item "$repo\powershell\Microsoft.PowerShell_profile.ps1" $prof -Force
    Set-Name $prof
    if ((Get-ExecutionPolicy -Scope CurrentUser) -in 'Undefined', 'Restricted') { Warn 'profile scripts are blocked; run: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned' }
}

# ---------------------------------------------------------------- Windows Terminal
if (-not $SkipTerminalTheme) {
    Step 'Windows Terminal Matrix theme'
    $wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $wt)) { Warn 'Windows Terminal settings not found (open Terminal once, then re-run)' }
    else {
        $s = [IO.File]::ReadAllText($wt)
        if ($s -match '"name"\s*:\s*"Matrix"') { Note 'Matrix scheme already present' }
        else {
            Copy-Item $wt "$wt.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            $scheme = [IO.File]::ReadAllText("$repo\terminal\matrix-scheme.json").Trim()
            if ($s -match '"schemes"\s*:\s*\[\s*\]') { $s = $s -replace '"schemes"\s*:\s*\[\s*\]', ('"schemes": [ ' + $scheme + ' ]') }
            elseif ($s -match '"schemes"\s*:\s*\[') { $s = $s -replace '"schemes"\s*:\s*\[', ('"schemes": [ ' + $scheme + ',') }
            else { $s = $s -replace '^\s*\{', ('{ "schemes": [ ' + $scheme + ' ],') }
            if ($s -match '"defaults"\s*:\s*\{\s*\}') {
                $s = $s -replace '"defaults"\s*:\s*\{\s*\}', '"defaults": { "colorScheme": "Matrix", "font": { "face": "Cascadia Mono", "size": 12 }, "cursorShape": "filledBox", "opacity": 90, "useAcrylic": true, "padding": "12" }'
            } elseif ($s -notmatch '"colorScheme"') {
                $s = $s -replace '"defaults"\s*:\s*\{', '"defaults": { "colorScheme": "Matrix",'
            }
            [IO.File]::WriteAllText($wt, $s, (New-Object Text.UTF8Encoding $false))
            Note 'theme added (old settings backed up next to settings.json)'
        }
        # make Windows Terminal the default console host
        $k = 'HKCU:\Console\%%Startup'; New-Item $k -Force | Out-Null
        Set-ItemProperty $k DelegationConsole '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
        Set-ItemProperty $k DelegationTerminal '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
    }
}

# ---------------------------------------------------------------- folder icons
if ($IconFolders.Count) {
    Step 'Folder icons'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$InstallDir\make-folder-icon.ps1" -Folders $IconFolders
}

# ---------------------------------------------------------------- desktop tweaks
if ($DesktopTweaks) {
    Step 'Desktop tweaks: dark mode, green accent, hidden desktop icons'
    $per = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty $per AppsUseLightTheme 0 -Type DWord; Set-ItemProperty $per SystemUsesLightTheme 0 -Type DWord
    Set-ItemProperty $per ColorPrevalence 1 -Type DWord
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' AccentColor -10172416 -Type DWord   # #00C864
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' ColorPrevalence 1 -Type DWord
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' HideIcons 1 -Type DWord
    Stop-Process -Name explorer -Force
    Note 'right-click desktop > View > Show desktop icons to bring icons back'
}

# ---------------------------------------------------------------- autostart
$startup = [Environment]::GetFolderPath('Startup')
$psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
function New-Launcher([string]$path, [string]$script, [string]$extra = '') {
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """"$script"""" $extra".Trim()
    "' Generated by install.ps1`r`nCreateObject(""WScript.Shell"").Run ""$cmd"", 0, False`r`n" | Set-Content $path -Encoding ASCII
}
New-Launcher "$InstallDir\Start $upper-BOT.vbs" "$InstallDir\bot.ps1"
New-Launcher "$InstallDir\AccessGranted.vbs" "$InstallDir\access-granted.ps1" '-Logon'

if (-not $SkipAutostart) {
    Step 'Autostart'
    New-Launcher "$startup\$upper-BOT.vbs" "$InstallDir\bot.ps1"
    Note 'bot added to Startup'

    # ACCESS GRANTED: a logon task (not delayed like the Startup folder) starts a background watcher
    # that shows the sign-in splash, then reacts instantly to every unlock.
    Remove-Item "$startup\$upper Welcome.vbs" -ErrorAction SilentlyContinue   # older versions used this
    $me = "$env:USERDOMAIN\$env:USERNAME"
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $me
    $action    = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\wscript.exe" -Argument "`"$InstallDir\AccessGranted.vbs`""
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $me -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName "$upper Access Granted" -Description 'ACCESS GRANTED splash at sign-in and on every unlock' -Trigger $trigger -Action $action -Settings $settings -Principal $principal -Force | Out-Null
    Note "scheduled task '$upper Access Granted' starts the unlock watcher at sign-in"

    # start the watcher now too (no splash - you're already signed in)
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$InstallDir\access-granted.ps1`""
}

# ---------------------------------------------------------------- launch
Step "Starting $upper-BOT"
Start-Process wscript.exe -ArgumentList "`"$InstallDir\Start $upper-BOT.vbs`""
Write-Host "`nDone. Double-click $upper-BOT to make it talk; right-click it for the menu." -ForegroundColor Green
