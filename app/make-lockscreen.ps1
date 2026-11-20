# Generates the "SYSTEM LOCKED" hacker lock screen and applies it (needs admin).
param([string]$Name = 'MIKEY')

Add-Type -AssemblyName System.Drawing
$out = "$env:USERPROFILE\Pictures\TechWallpaper\lockscreen_$($Name.ToLower()).png"
$W = 1920; $H = 1080
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::FromArgb(3, 7, 5))
$Rgb = { param($a, $r, $gg, $b) [System.Drawing.Color]::FromArgb($a, $r, $gg, $b) }

# dimmer Matrix rain so Windows' clock stays readable
$rnd = New-Object System.Random 4242
$chars = '01'.ToCharArray()   # binary rain
$f = New-Object System.Drawing.Font 'Consolas', 13, ([System.Drawing.FontStyle]::Bold)
for ($x = 0; $x -lt $W; $x += 20) {
    if ($rnd.NextDouble() -lt 0.35) { continue }
    $len = $rnd.Next(6, 40); $start = $rnd.Next(-20, $H / 20)
    for ($i = 0; $i -lt $len; $i++) {
        $y = ($start + $i) * 22; if ($y -lt 0 -or $y -gt $H) { continue }
        $t = $i / $len
        $col = if ($i -eq $len - 1) { & $Rgb 170 190 255 210 } else { & $Rgb ([int](10 + 120 * $t)) 0 ([int](110 + 110 * $t)) 55 }
        $b = New-Object System.Drawing.SolidBrush $col
        $g.DrawString([string]$chars[$rnd.Next($chars.Length)], $f, $b, $x, $y); $b.Dispose()
    }
}

# panel at the top - the sign-in box sits in the middle of the screen
$pw = 760; $ph = 260; $px = ($W - $pw) / 2; $py = 90
$g.FillRectangle((New-Object System.Drawing.SolidBrush (& $Rgb 230 4 10 6)), $px, $py, $pw, $ph)
$g.DrawRectangle((New-Object System.Drawing.Pen (& $Rgb 220 0 255 120), 2), $px, $py, $pw, $ph)
# corner brackets
$pen = New-Object System.Drawing.Pen (& $Rgb 255 0 255 120), 5
foreach ($pt in @(@($px, $py, 1, 1), @(($px + $pw), $py, -1, 1), @($px, ($py + $ph), 1, -1), @(($px + $pw), ($py + $ph), -1, -1))) {
    $g.DrawLine($pen, $pt[0], $pt[1], $pt[0] + 30 * $pt[2], $pt[1]); $g.DrawLine($pen, $pt[0], $pt[1], $pt[0], $pt[1] + 30 * $pt[3])
}

# padlock
$lx = $px + 70; $ly = $py + 70
$lockPen = New-Object System.Drawing.Pen (& $Rgb 255 0 255 120), 9
$g.DrawArc($lockPen, $lx + 12, $ly, 56, 60, 180, 180)
$g.DrawLine($lockPen, $lx + 12, $ly + 30, $lx + 12, $ly + 50); $g.DrawLine($lockPen, $lx + 68, $ly + 30, $lx + 68, $ly + 50)
$g.FillRectangle((New-Object System.Drawing.SolidBrush (& $Rgb 255 0 255 120)), $lx, $ly + 48, 80, 66)
$g.FillEllipse((New-Object System.Drawing.SolidBrush (& $Rgb 255 4 10 6)), $lx + 32, $ly + 66, 16, 16)
$g.FillRectangle((New-Object System.Drawing.SolidBrush (& $Rgb 255 4 10 6)), $lx + 37, $ly + 78, 6, 20)

$green = New-Object System.Drawing.SolidBrush (& $Rgb 255 0 255 120)
$dim   = New-Object System.Drawing.SolidBrush (& $Rgb 255 90 190 130)
$white = New-Object System.Drawing.SolidBrush (& $Rgb 255 210 235 220)
$tx = $px + 200
$g.DrawString("$Name // SECURE TERMINAL", (New-Object System.Drawing.Font 'Consolas', 16), $dim, $tx, $py + 50)
$g.DrawString('SYSTEM LOCKED', (New-Object System.Drawing.Font 'Consolas', 44, ([System.Drawing.FontStyle]::Bold)), $green, $tx - 6, $py + 80)
$g.DrawString('> authentication required', (New-Object System.Drawing.Font 'Consolas', 17), $white, $tx, $py + 160)
$g.DrawString('> enter password below_', (New-Object System.Drawing.Font 'Consolas', 17), $white, $tx, $py + 192)
$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
New-Item $csp -Force | Out-Null
Set-ItemProperty $csp LockScreenImagePath $out
Set-ItemProperty $csp LockScreenImageUrl $out
Set-ItemProperty $csp LockScreenImageStatus 1 -Type DWord
$out
