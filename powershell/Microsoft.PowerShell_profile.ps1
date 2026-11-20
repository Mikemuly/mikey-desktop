# ===== Mikey's hacker prompt (made with MIKEY-BOT) =====
# Remove or rename this file to go back to the normal PowerShell prompt.

$script:MikeyEsc = [char]27
function global:Get-MikeyColor([int]$r, [int]$g, [int]$b) { "$([char]27)[38;2;${r};${g};${b}m" }

# Banner - only in a real interactive window
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected -and [Environment]::UserInteractive) {
    $G  = Get-MikeyColor 0 255 120
    $D  = Get-MikeyColor 90 190 130
    $W  = Get-MikeyColor 220 240 228
    $R0 = "$([char]27)[0m"

    $cpu = (Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction SilentlyContinue).ProcessorNameString
    $cpu = ($cpu -replace '\(R\)|\(TM\)|CPU ', '' -replace '\s+', ' ').Trim()
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $ci = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
        $ramTotal = [Math]::Round($ci.TotalPhysicalMemory / 1GB, 1)
        $ramUsed  = [Math]::Round(($ci.TotalPhysicalMemory - $ci.AvailablePhysicalMemory) / 1GB, 1)
        $ram = "$ramUsed / $ramTotal GB"
    } catch { $ram = '?' }
    $up = [TimeSpan]::FromSeconds([System.Diagnostics.Stopwatch]::GetTimestamp() / [System.Diagnostics.Stopwatch]::Frequency)
    $uptime = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes

    $taglines = @(
        'There is no place like 127.0.0.1',
        'Talk is cheap. Show me the code.',
        'It works on my machine.',
        'Wake up, Mikey... the Matrix has you.',
        'sudo make me a sandwich',
        'First, solve the problem. Then, write the code.'
    )

    $art = @(
        ' __  __ ___ _  _______   __  ',
        '|  \/  |_ _| |/ / ____\ \ / /',
        '| |\/| || || '' /|  _|  \ V / ',
        '| |  | || || . \| |___  | |  ',
        '|_|  |_|___|_|\_\_____| |_|  '
    )
    $info = @(
        "${D}user   ${W}Mikey@$env:COMPUTERNAME",
        "${D}os     ${W}Windows 11 Pro",
        "${D}cpu    ${W}$cpu",
        "${D}ram    ${W}$ram",
        "${D}uptime ${W}$uptime"
    )
    Write-Host ''
    for ($i = 0; $i -lt $art.Count; $i++) { Write-Host ("  $G" + $art[$i] + "    " + $info[$i] + $R0) }
    Write-Host ''
    Write-Host ("  ${D}// " + ($taglines | Get-Random) + $R0)
    Write-Host ''
}

function global:prompt {
    $ok = $?
    $e  = [char]27
    $G  = "$e[38;2;0;255;120m"; $D = "$e[38;2;0;170;90m"; $W = "$e[38;2;200;235;215m"; $Rd = "$e[38;2;255;95;87m"; $R0 = "$e[0m"
    $path = $PWD.Path
    if ($path.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $path = '~' + $path.Substring($HOME.Length) }
    $top = [char]0x250C + [char]0x2500; $bot = [char]0x2514 + [char]0x2500; $dash = [char]0x2500
    $mark = if ($ok) { "$G>" } else { "$Rd>" }
    "${D}$top[${G}Mikey${D}@$env:COMPUTERNAME]$dash[${W}$path${D}]$dash[$(Get-Date -Format HH:mm:ss)]`n${D}$bot$mark$R0 "
}
