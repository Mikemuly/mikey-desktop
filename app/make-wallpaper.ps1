# Generates the static "binary rain + terminal" wallpaper and (optionally) applies it.
# Usage: .\make-wallpaper.ps1 -Name Mikey            # generate + set as wallpaper
#        .\make-wallpaper.ps1 -Name Mikey -NoApply   # generate only
param([string]$Name = 'Mikey', [switch]$NoApply)

Add-Type -AssemblyName System.Drawing
$outDir = "$env:USERPROFILE\Pictures\TechWallpaper"; New-Item -ItemType Directory -Force $outDir | Out-Null
$out = "$outDir\matrix_terminal.png"

# System info shown in the terminal panel (detected on this PC)
$hostName = $env:COMPUTERNAME
$os  = (Get-CimInstance Win32_OperatingSystem).Caption -replace '^Microsoft ', ''
$cpu = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\(R\)|\(TM\)|CPU ', '' -replace '\s+', ' ').Trim()
$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
$ram = '{0} GB' -f [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

$W = 1920; $H = 1080
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::FromArgb(5, 10, 7))

# Binary Matrix rain
$rnd = New-Object System.Random 1337
$chars = '01'.ToCharArray()
$f = New-Object System.Drawing.Font 'Consolas', 13, ([System.Drawing.FontStyle]::Bold)
for ($x = 0; $x -lt $W; $x += 20) {
    if ($rnd.NextDouble() -lt 0.25) { continue }
    $len = $rnd.Next(8, 45); $start = $rnd.Next(-20, $H / 20)
    for ($i = 0; $i -lt $len; $i++) {
        $y = ($start + $i) * 22; if ($y -lt 0 -or $y -gt $H) { continue }
        $t = $i / $len
        if ($i -eq $len - 1) { $col = [System.Drawing.Color]::FromArgb(230, 210, 255, 220) }
        else { $col = [System.Drawing.Color]::FromArgb([int](20 + 200 * $t), 0, [int](120 + 120 * $t), 60) }
        $b = New-Object System.Drawing.SolidBrush $col
        $g.DrawString([string]$chars[$rnd.Next($chars.Length)], $f, $b, $x, $y); $b.Dispose()
    }
}

# Terminal panel
$px = 560; $py = 300; $pw = 800; $ph = 440
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225, 8, 14, 10))), $px, $py, $pw, $ph)
$g.DrawRectangle((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, 0, 255, 120)), 2), $px, $py, $pw, $ph)
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0, 60, 30))), $px, $py, $pw, 30)
$dots = [System.Drawing.Color]::FromArgb(255, 95, 87), [System.Drawing.Color]::FromArgb(255, 189, 46), [System.Drawing.Color]::FromArgb(39, 201, 63)
for ($k = 0; $k -lt 3; $k++) { $g.FillEllipse((New-Object System.Drawing.SolidBrush $dots[$k]), $px + 12 + $k * 22, $py + 9, 12, 12) }
$tf = New-Object System.Drawing.Font 'Consolas', 11
$title = "$env:USERNAME@${hostName}: ~"
$tw = $g.MeasureString($title, $tf).Width
$g.DrawString($title, $tf, [System.Drawing.Brushes]::LightGreen, $px + ($pw - $tw) / 2, $py + 6)
$mf = New-Object System.Drawing.Font 'Consolas', 17
$green = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 255, 120))
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 235, 225))
$dim   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 170, 120))
$lines = @(
    @($green, 'C:\> whoami'), @($white, "  $Name"), @($green, 'C:\> sysinfo --short'),
    @($dim, "  HOST   $hostName"), @($dim, "  OS     $os"), @($dim, "  CPU    $cpu"),
    @($dim, "  GPU    $gpu"), @($dim, "  RAM    $ram"),
    @($green, 'C:\> echo $MOTTO'), @($white, '  "There is no place like 127.0.0.1"'), @($green, 'C:\> _'))
$yy = $py + 48
foreach ($l in $lines) { $g.DrawString($l[1], $mf, $l[0], $px + 28, $yy); $yy += 34 }
$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

if (-not $NoApply) {
    Add-Type @'
using System.Runtime.InteropServices;
public class WPSet { [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int SystemParametersInfo(int a, int b, string c, int d); }
'@
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle 10
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper 0
    [void][WPSet]::SystemParametersInfo(20, 0, $out, 3)
}
$out
