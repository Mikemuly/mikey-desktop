# Generates a green ">_" terminal folder icon and (optionally) applies it to folders.
# Usage: .\make-folder-icon.ps1                                  # just create code-folder.ico
#        .\make-folder-icon.ps1 -Folders C:\code\proj1, C:\code\proj2
param([string[]]$Folders = @())

Add-Type -AssemblyName System.Drawing
$ico = Join-Path $PSScriptRoot 'code-folder.ico'

$S = 256
$bmp = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
function New-RoundRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $r, $r, 180, 90); $p.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $p.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90); $p.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $p.CloseFigure(); $p
}
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0, 90, 45))), (New-RoundRect 16 40 100 50 24))
$body = New-RoundRect 16 64 224 168 32
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 8, 22, 14))), $body)
$g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 0, 255, 120)), 8), $body)
$font = New-Object System.Drawing.Font 'Consolas', 92, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
foreach ($o in 6, 4, 2) {
    $g.DrawString('>_', $font, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 0, 255, 120))),
        (New-Object System.Drawing.RectangleF (16 - $o), (70 - $o), (224 + 2 * $o), (160 + 2 * $o)), $sf)
}
$g.DrawString('>_', $font, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0, 255, 120))),
    (New-Object System.Drawing.RectangleF 16, 70, 224, 160), $sf)
$g.Dispose()

# ICO file with PNG-compressed 256/48/32/16 images
$sizes = 256, 48, 32, 16; $pngs = @()
foreach ($s in $sizes) {
    $b2 = New-Object System.Drawing.Bitmap $s, $s; $g2 = [System.Drawing.Graphics]::FromImage($b2)
    $g2.InterpolationMode = 'HighQualityBicubic'; $g2.DrawImage($bmp, 0, 0, $s, $s); $g2.Dispose()
    $ms = New-Object IO.MemoryStream; $b2.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $pngs += , ($ms.ToArray())
}
$out = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $out
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$off = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $wb = [byte]$(if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] })
    $w.Write($wb); $w.Write($wb); $w.Write([byte]0); $w.Write([byte]0); $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$off); $off += $pngs[$i].Length
}
foreach ($p in $pngs) { $w.Write($p) }; $w.Flush()
[IO.File]::WriteAllBytes($ico, $out.ToArray())

# Apply to folders (desktop.ini); git repos get desktop.ini added to .git/info/exclude
foreach ($d in $Folders) {
    if (-not (Test-Path $d -PathType Container)) { Write-Warning "skip (not a folder): $d"; continue }
    $ini = Join-Path $d 'desktop.ini'
    if (Test-Path $ini) { Write-Warning "skip (already has desktop.ini): $d"; continue }
    "[.ShellClassInfo]`r`nIconResource=$ico,0`r`n" | Set-Content $ini -Encoding Unicode
    (Get-Item $ini -Force).Attributes = 'Hidden,System'
    (Get-Item $d).Attributes = (Get-Item $d).Attributes -bor [IO.FileAttributes]::ReadOnly
    $ex = Join-Path $d '.git\info\exclude'
    if ((Test-Path $ex) -and -not (Select-String -Path $ex -Pattern '^desktop\.ini$' -Quiet)) { Add-Content $ex 'desktop.ini' }
    "icon set: $d"
}
$ico
