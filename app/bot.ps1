# MIKEY-BOT - a desktop robot whose eyes follow your cursor.
# Moods, system monitor (CPU / battery), clock, break reminders, Aria voice.
# Left-drag: move | Double-click: say something | Right-click: menu
param(
    [string]$Mood    # optional: force a mood (normal/happy/sleepy/worried/stressed/sleeping) for testing
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class IdleTime {
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO p);
    public static double Seconds() {
        var l = new LASTINPUTINFO(); l.cbSize = (uint)Marshal.SizeOf(l);
        GetLastInputInfo(ref l);
        return unchecked((uint)Environment.TickCount - l.dwTime) / 1000.0;
    }
}
'@

$posFile = Join-Path $PSScriptRoot 'position.txt'
$cfgFile = Join-Path $PSScriptRoot 'config.txt'
$script:voiceOn = $true
if (Test-Path $cfgFile) { $script:voiceOn = (Get-Content $cfgFile -Raw) -notmatch 'voice=0' }
function Save-Config { "voice=$([int]$script:voiceOn)" | Set-Content $cfgFile }

# Eye template (L/R) - socket, pupil, eyelid, happy arc, closed line, ring
function EyeXaml($s, $left) { @"
    <Canvas x:Name="Eye$s" Canvas.Left="$left" Canvas.Top="82" Width="54" Height="54" RenderTransformOrigin="0.5,0.5">
      <Canvas.Clip><EllipseGeometry Center="27,27" RadiusX="27" RadiusY="27"/></Canvas.Clip>
      <Canvas.RenderTransform><ScaleTransform x:Name="Blink$s" ScaleY="1"/></Canvas.RenderTransform>
      <Ellipse Width="54" Height="54" Fill="#06180E"/>
      <Ellipse x:Name="Pupil$s" Width="22" Height="22" Canvas.Left="16" Canvas.Top="16" Fill="#00FF78">
        <Ellipse.Effect><DropShadowEffect Color="#00FF78" BlurRadius="14" ShadowDepth="0" Opacity="1"/></Ellipse.Effect>
      </Ellipse>
      <Rectangle x:Name="Lid$s" Width="54" Height="0" Fill="#0B2416"/>
      <Path x:Name="Happy$s" Data="M 12,34 Q 27,12 42,34" Stroke="#00FF78" StrokeThickness="5" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Visibility="Collapsed"/>
      <Path x:Name="Closed$s" Data="M 12,30 Q 27,40 42,30" Stroke="#00C864" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Visibility="Collapsed"/>
      <Ellipse Width="54" Height="54" Stroke="#00C864" StrokeThickness="2"/>
    </Canvas>
"@ }

$mouthXaml = (0..4 | ForEach-Object { "<Rectangle x:Name=`"M$_`" Canvas.Left=`"$(84 + $_*14)`" Canvas.Top=`"156`" Width=`"10`" Height=`"8`" Fill=`"#00C864`"/>" }) -join "`n"
$zzzXaml   = (0..2 | ForEach-Object { "<TextBlock x:Name=`"Z$_`" Text=`"Z`" FontFamily=`"Consolas`" FontWeight=`"Bold`" FontSize=`"$(12 + $_*5)`" Foreground=`"#00FF78`" Visibility=`"Collapsed`"/>" }) -join "`n"

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MIKEY-BOT" Width="240" Height="330" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ShowInTaskbar="False" ResizeMode="NoResize" Topmost="False">
  <Window.ContextMenu>
    <ContextMenu>
      <MenuItem x:Name="MenuTop" Header="Always on top" IsCheckable="True"/>
      <MenuItem x:Name="MenuVoice" Header="Voice" IsCheckable="True"/>
      <MenuItem x:Name="MenuSay" Header="Say something"/>
      <MenuItem x:Name="MenuDemo" Header="Show all moods"/>
      <Separator/>
      <MenuItem x:Name="MenuExit" Header="Exit MIKEY-BOT"/>
    </ContextMenu>
  </Window.ContextMenu>
  <Canvas>
    $zzzXaml
    <Line X1="120" Y1="18" X2="120" Y2="50" Stroke="#00C864" StrokeThickness="4"/>
    <Ellipse x:Name="Bulb" Canvas.Left="110" Canvas.Top="4" Width="20" Height="20" Fill="#00FF78">
      <Ellipse.Effect><DropShadowEffect x:Name="BulbGlow" Color="#00FF78" BlurRadius="20" ShadowDepth="0" Opacity="1"/></Ellipse.Effect>
    </Ellipse>
    <Rectangle Canvas.Left="12" Canvas.Top="100" Width="18" Height="56" RadiusX="6" RadiusY="6" Fill="#0B2416" Stroke="#00C864" StrokeThickness="2"/>
    <Rectangle Canvas.Left="210" Canvas.Top="100" Width="18" Height="56" RadiusX="6" RadiusY="6" Fill="#0B2416" Stroke="#00C864" StrokeThickness="2"/>
    <Rectangle Canvas.Left="26" Canvas.Top="48" Width="188" Height="160" RadiusX="34" RadiusY="34" Fill="#0B1A12" Stroke="#00FF78" StrokeThickness="3">
      <Rectangle.Effect><DropShadowEffect Color="#00FF78" BlurRadius="25" ShadowDepth="0" Opacity="0.7"/></Rectangle.Effect>
    </Rectangle>
    <Rectangle Canvas.Left="42" Canvas.Top="64" Width="156" Height="128" RadiusX="24" RadiusY="24" Fill="#020604" Stroke="#0E5A32" StrokeThickness="2"/>
    $(EyeXaml 'L' 58)
    $(EyeXaml 'R' 128)
    <Rectangle x:Name="BrowL" Canvas.Left="63" Canvas.Top="70" Width="44" Height="5" RadiusX="2" RadiusY="2" Fill="#00FF78" RenderTransformOrigin="0.5,0.5" Visibility="Collapsed">
      <Rectangle.RenderTransform><RotateTransform x:Name="BrowLRot" Angle="0"/></Rectangle.RenderTransform>
    </Rectangle>
    <Rectangle x:Name="BrowR" Canvas.Left="133" Canvas.Top="70" Width="44" Height="5" RadiusX="2" RadiusY="2" Fill="#00FF78" RenderTransformOrigin="0.5,0.5" Visibility="Collapsed">
      <Rectangle.RenderTransform><RotateTransform x:Name="BrowRRot" Angle="0"/></Rectangle.RenderTransform>
    </Rectangle>
    $mouthXaml
    <Path x:Name="Sweat" Canvas.Left="190" Canvas.Top="60" Data="M 7,0 Q 14,11 14,16 A 7,7 0 1 1 0,16 Q 0,11 7,0 Z" Fill="#7FD4FF" Visibility="Collapsed"/>
    <Border Canvas.Left="60" Canvas.Top="218" Width="120" Height="24" CornerRadius="6" Background="#0B1A12" BorderBrush="#00C864" BorderThickness="1">
      <TextBlock x:Name="Tag" Text="MIKEY-BOT" FontFamily="Consolas" FontSize="12" Foreground="#00FF78" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <TextBlock x:Name="Status" Canvas.Left="0" Canvas.Top="248" Width="240" TextAlignment="Center" FontFamily="Consolas" FontSize="11" Foreground="#5AE09A">
      <TextBlock.Effect><DropShadowEffect Color="Black" BlurRadius="6" ShadowDepth="0" Opacity="1"/></TextBlock.Effect>
    </TextBlock>
    <TextBlock x:Name="Speech" Canvas.Left="0" Canvas.Top="268" Width="240" TextAlignment="Center" TextWrapping="Wrap"
               FontFamily="Consolas" FontSize="13" Foreground="#B4F0C8" Text="">
      <TextBlock.Effect><DropShadowEffect Color="Black" BlurRadius="6" ShadowDepth="0" Opacity="1"/></TextBlock.Effect>
    </TextBlock>
  </Canvas>
</Window>
"@

$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$n = @{}
$names = 'EyeL','EyeR','PupilL','PupilR','BlinkL','BlinkR','LidL','LidR','HappyL','HappyR','ClosedL','ClosedR',
         'BrowL','BrowR','BrowLRot','BrowRRot','Sweat','Bulb','BulbGlow','Tag','Status','Speech',
         'M0','M1','M2','M3','M4','Z0','Z1','Z2','MenuTop','MenuVoice','MenuSay','MenuDemo','MenuExit'
foreach ($name in $names) { $n[$name] = $win.FindName($name) }

$bc = New-Object System.Windows.Media.BrushConverter
$col = @{ green='#00FF78'; amber='#FFC83C'; red='#FF5F57'; dim='#2E5A3E' }
$br  = @{}; foreach ($k in $col.Keys) { $br[$k] = $bc.ConvertFromString($col[$k]) }

# Voice: pre-recorded Aria clips in .\voice (see voice\record.py)
$voiceDir = Join-Path $PSScriptRoot 'voice'
$player = New-Object System.Windows.Media.MediaPlayer
$n.MenuVoice.IsChecked = $script:voiceOn

# Position: restore last spot, else bottom-right of the work area
$wa = [System.Windows.SystemParameters]::WorkArea
$win.Left = $wa.Right - 280; $win.Top = $wa.Bottom - 360
if (Test-Path $posFile) {
    $p = (Get-Content $posFile -Raw).Trim() -split ','
    if ($p.Count -eq 2) { $win.Left = [double]$p[0]; $win.Top = [double]$p[1] }
}

# Each quip: text shown on screen + the Aria clip that is spoken
$quips = @(
    @{t='Hello, Mikey.'; c='hello'}, @{t='There is no place like 127.0.0.1'; c='q01'}, @{t='sudo make me a sandwich'; c='q02'},
    @{t='It works on my machine.'; c='q03'}, @{t='Have you tried turning it off and on again?'; c='q04'},
    @{t='01001000 01101001'; c='q05'}, @{t='git commit -m "fixed it"'; c='q06'}, @{t='I see you.'; c='q07'},
    @{t='Wake up, Mikey...'; c='q08'}, @{t='Compiling... just kidding.'; c='q09'}, @{t='Coffee level: critical'; c='q10'},
    @{t='Ship it!'; c='q11'}, @{t='Debugging: removing the needles from the haystack.'; c='q12'},
    @{t='Talk is cheap. Show me the code.'; c='q13'}
)

$script:speechUntil = [DateTime]::MinValue
function Say([string]$text, [string]$Clip) {
    $n.Speech.Text = $text
    $script:speechUntil = (Get-Date).AddSeconds([Math]::Max(4, $text.Length / 10))
    $file = Join-Path $voiceDir "$Clip.mp3"
    if ($Clip -and $script:voiceOn -and (Test-Path $file)) {
        try { $player.Stop(); $player.Open([uri]$file); $player.Play() } catch { }
    }
}
function Say-Quip { $q = $quips | Get-Random; Say $q.t -Clip $q.c }


# ---------- Faces ----------
$mouthShapes = @{
    normal   = @{ top = 156,156,156,156,156; h = 8 }
    happy    = @{ top = 150,154,156,154,150; h = 6 }
    worried  = @{ top = 158,154,152,154,158; h = 6 }
    stressed = @{ top = 152,158,152,158,152; h = 6 }
    sleepy   = @{ top = 157,157,157,157,157; h = 5 }
    sleeping = @{ top = 159,159,159,159,159; h = 3 }
}
$lids = @{ normal = 0; happy = 0; sleepy = 24; worried = 8; stressed = 0; sleeping = 54 }
$script:face = ''

function Set-Face([string]$m) {
    $script:face = $m
    foreach ($s in 'L','R') {
        $n["Lid$s"].Height        = $lids[$m]
        $n["Happy$s"].Visibility  = $(if ($m -eq 'happy') { 'Visible' } else { 'Collapsed' })
        $n["Closed$s"].Visibility = $(if ($m -eq 'sleeping') { 'Visible' } else { 'Collapsed' })
        $n["Pupil$s"].Visibility  = $(if ($m -eq 'happy' -or $m -eq 'sleeping') { 'Hidden' } else { 'Visible' })
        $n["Pupil$s"].Fill        = $(if ($m -eq 'stressed') { $br.amber } else { $br.green })
    }
    $browVis = $(if ($m -eq 'worried' -or $m -eq 'stressed') { 'Visible' } else { 'Collapsed' })
    $n.BrowL.Visibility = $browVis; $n.BrowR.Visibility = $browVis
    if ($m -eq 'worried')  { $n.BrowLRot.Angle = -16; $n.BrowRRot.Angle = 16 }
    if ($m -eq 'stressed') { $n.BrowLRot.Angle = 16;  $n.BrowRRot.Angle = -16 }
    $n.Sweat.Visibility = $(if ($m -eq 'stressed') { 'Visible' } else { 'Collapsed' })
    foreach ($i in 0..2) { $n["Z$i"].Visibility = $(if ($m -eq 'sleeping') { 'Visible' } else { 'Collapsed' }) }
    $bulbColor = switch ($m) { 'worried' { 'red' } 'stressed' { 'amber' } 'sleeping' { 'dim' } default { 'green' } }
    $n.Bulb.Fill = $br[$bulbColor]
    $n.BulbGlow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($col[$bulbColor])
    $n.BlinkL.ScaleY = 1; $n.BlinkR.ScaleY = 1
}

# ---------- Events ----------
$win.Add_MouseLeftButtonDown({
    param($s, $e)
    if ($e.ClickCount -eq 2) {
        $script:happyUntil = (Get-Date).AddSeconds(3)
        Say-Quip
    } else { $win.DragMove() }
})
$win.Add_LocationChanged({ "$([int]$win.Left),$([int]$win.Top)" | Set-Content $posFile })
$n.MenuTop.Add_Click({ $win.Topmost = $n.MenuTop.IsChecked })
$n.MenuVoice.Add_Click({
    $script:voiceOn = $n.MenuVoice.IsChecked
    Save-Config
    if ($script:voiceOn) { Say 'Voice online.' -Clip 'voiceon' } else { Say 'Going quiet.' }
})
$n.MenuSay.Add_Click({ $script:happyUntil = (Get-Date).AddSeconds(3); Say-Quip })
$n.MenuDemo.Add_Click({ $script:demoStart = Get-Date })
$n.MenuExit.Add_Click({ $win.Close() })

# ---------- State ----------
$state = @{ L = @{x=0.0;y=0.0}; R = @{x=0.0;y=0.0} }
$maxOff = 15.0
$script:nextBlink = (Get-Date).AddSeconds(3); $script:blinkStart = $null
$script:tick = 0; $script:lastSlow = [DateTime]::MinValue
$script:happyUntil = [DateTime]::MinValue; $script:demoStart = $null
$script:asleep = $false; $script:stressed = $false; $script:hiCount = 0; $script:loCount = 0
$script:activeSec = 0; $script:lastPlugged = $null
$script:lowAnnounced = $false; $script:critAnnounced = $false; $script:lateAnnounced = $false
$script:cpu = 0; $script:low = $false
$demoMoods = 'happy','sleepy','worried','stressed','sleeping','normal'

$cpuCounter = $null
try { $cpuCounter = New-Object System.Diagnostics.PerformanceCounter('Processor Information','% Processor Utility','_Total'); [void]$cpuCounter.NextValue() }
catch { try { $cpuCounter = New-Object System.Diagnostics.PerformanceCounter('Processor','% Processor Time','_Total'); [void]$cpuCounter.NextValue() } catch { } }

function Update-Slow {
    $now = Get-Date
    $idle = [IdleTime]::Seconds()

    # CPU (needs ~3 s above 85% to stress, ~3 s below 60% to calm down)
    if ($cpuCounter) { $script:cpu = [int][Math]::Min(100, [Math]::Round($cpuCounter.NextValue())) }
    if ($script:cpu -gt 85) { $script:hiCount++ } else { $script:hiCount = 0 }
    if ($script:cpu -lt 60) { $script:loCount++ } else { $script:loCount = 0 }
    if (-not $script:stressed -and $script:hiCount -ge 3) { $script:stressed = $true; Say "CPU at $($script:cpu)%! I'm sweating..." -Clip 'cpuhigh' }
    if ($script:stressed -and $script:loCount -ge 3) { $script:stressed = $false; Say 'Phew. CPU back to normal.' -Clip 'cpuok' }

    # Battery
    $ps = [System.Windows.Forms.SystemInformation]::PowerStatus
    $hasBat = -not $ps.BatteryChargeStatus.HasFlag([System.Windows.Forms.BatteryChargeStatus]::NoSystemBattery) -and $ps.BatteryLifePercent -le 1
    $bat = [int]($ps.BatteryLifePercent * 100)
    $plugged = $ps.PowerLineStatus -eq 'Online'
    if ($hasBat -and $null -ne $script:lastPlugged -and $plugged -ne $script:lastPlugged) {
        if ($plugged) { Say 'Ahh, power. Thank you!' -Clip 'plugin' } else { Say "Running on battery now ($bat%)." -Clip 'unplug' }
    }
    $script:lastPlugged = $plugged
    $script:low = $hasBat -and -not $plugged -and $bat -le 20
    if ($script:low -and -not $script:lowAnnounced) { Say "Battery at $bat%! Plug me in, Mikey!" -Clip 'batlow'; $script:lowAnnounced = $true }
    if ($hasBat -and -not $plugged -and $bat -le 10 -and -not $script:critAnnounced) { Say "Battery critical: $bat%! Save your work!" -Clip 'batcrit'; $script:critAnnounced = $true }
    if (-not $script:low) { $script:lowAnnounced = $false; $script:critAnnounced = $false }

    # Sleep when idle 3 min, wake on any input
    if (-not $script:asleep -and $idle -ge 180) { $script:asleep = $true; $n.Speech.Text = '' }
    if ($script:asleep -and $idle -lt 2) {
        $script:asleep = $false; $script:happyUntil = $now.AddSeconds(3)
        Say 'Oh! Welcome back, Mikey.'
    }

    # Break reminder: 2 hours of continuous activity (a 5-min break resets it)
    if ($idle -lt 120) { $script:activeSec++ } elseif ($idle -ge 300) { $script:activeSec = 0 }
    if ($script:activeSec -ge 7200) {
        Say "Mikey, you've been at it for 2 hours. Take a break!" -Clip 'break'
        $script:activeSec = 0
    }

    # Late night
    $late = $now.Hour -ge 23 -or $now.Hour -lt 5
    if ($late -and -not $script:lateAnnounced -and -not $script:asleep) { Say "It's late, Mikey. Get some sleep."; $script:lateAnnounced = $true }
    if (-not $late) { $script:lateAnnounced = $false }

    # Status line: clock | CPU | battery
    $s = '{0:HH:mm}  CPU {1}%' -f $now, $script:cpu
    if ($hasBat) { $s += "  BAT $bat%" + $(if ($plugged) { ' ' + [char]0x26A1 } else { '' }) }
    $n.Status.Text = $s

    # Pick a mood
    $m = 'normal'
    if ($Mood) { $m = $Mood }
    elseif ($script:demoStart) {
        $idx = [int][Math]::Floor(($now - $script:demoStart).TotalSeconds / 2.5)
        if ($idx -lt $demoMoods.Count) { $m = $demoMoods[$idx]; $n.Speech.Text = "mood: $m"; $script:speechUntil = $now.AddSeconds(3) }
        else { $script:demoStart = $null }
    }
    elseif ($script:asleep) { $m = 'sleeping' }
    elseif ($now -lt $script:happyUntil) { $m = 'happy' }
    elseif ($script:low) { $m = 'worried' }
    elseif ($script:stressed) { $m = 'stressed' }
    elseif ($late) { $m = 'sleepy' }
    if ($m -ne $script:face) { Set-Face $m }
}

# ---------- Animation loop (~60 fps) ----------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(16)
$timer.Add_Tick({
    try {
        $now = Get-Date
        $script:tick++
        $t = $script:tick
        if (($now - $script:lastSlow).TotalMilliseconds -ge 1000) { $script:lastSlow = $now; Update-Slow }
        $face = $script:face

        # Eyes follow the cursor
        $cur = [System.Windows.Forms.Cursor]::Position
        foreach ($side in 'L','R') {
            $c = $n["Eye$side"].PointToScreen((New-Object System.Windows.Point 27, 27))
            $dx = $cur.X - $c.X; $dy = $cur.Y - $c.Y
            $d = [Math]::Sqrt($dx*$dx + $dy*$dy)
            $tx = 0.0; $ty = 0.0
            if ($d -gt 0.5) { $mag = [Math]::Min($maxOff, $d / 12.0); $tx = $dx / $d * $mag; $ty = $dy / $d * $mag }
            if ($face -eq 'sleepy') { $ty = [Math]::Max($ty, 2) }   # droopy gaze
            $st = $state[$side]
            $st.x += ($tx - $st.x) * 0.25; $st.y += ($ty - $st.y) * 0.25
            [System.Windows.Controls.Canvas]::SetLeft($n["Pupil$side"], 16 + $st.x)
            [System.Windows.Controls.Canvas]::SetTop($n["Pupil$side"], 16 + $st.y)
        }

        # Blinking (not while asleep / happy)
        if ($face -ne 'sleeping' -and $face -ne 'happy') {
            if ($null -eq $script:blinkStart -and $now -ge $script:nextBlink) { $script:blinkStart = $now }
            if ($null -ne $script:blinkStart) {
                $p = ($now - $script:blinkStart).TotalMilliseconds / 180.0
                if ($p -ge 1) { $sy = 1.0; $script:blinkStart = $null; $script:nextBlink = $now.AddMilliseconds((Get-Random -Minimum 2500 -Maximum 6500)) }
                else { $sy = [Math]::Max(0.08, [Math]::Abs(1 - 2*$p)) }
                $n.BlinkL.ScaleY = $sy; $n.BlinkR.ScaleY = $sy
            }
        }

        # Antenna
        $n.Bulb.Opacity = switch ($face) {
            'sleeping' { 0.3 + 0.2 * [Math]::Abs([Math]::Sin($t / 90.0)) }
            'worried'  { $(if (($t % 40) -lt 20) { 1.0 } else { 0.2 }) }
            'stressed' { 0.5 + 0.5 * [Math]::Abs([Math]::Sin($t / 8.0)) }
            default    { 0.55 + 0.45 * [Math]::Abs([Math]::Sin($t / 30.0)) }
        }

        # Mouth (animated while talking)
        $shape = $mouthShapes[$face]
        $talking = $now -lt $script:speechUntil -and $n.Speech.Text -and -not $script:demoStart
        for ($i = 0; $i -lt 5; $i++) {
            $bar = $n["M$i"]; $h = $shape.h; $top = $shape.top[$i]
            if ($talking -and $face -ne 'sleeping') { $extra = 10 * [Math]::Abs([Math]::Sin($t / 4.0 + $i)); $h += $extra; $top -= $extra / 2 }
            $bar.Height = $h; [System.Windows.Controls.Canvas]::SetTop($bar, $top)
        }
        if (-not $talking -and $n.Speech.Text -and $now -ge $script:speechUntil) { $n.Speech.Text = '' }

        # Zzz while sleeping
        if ($face -eq 'sleeping') {
            for ($i = 0; $i -lt 3; $i++) {
                $ph = (($t + $i * 50) % 150) / 150.0
                [System.Windows.Controls.Canvas]::SetLeft($n["Z$i"], 170 + $ph * 35)
                [System.Windows.Controls.Canvas]::SetTop($n["Z$i"], 45 - $ph * 45)
                $n["Z$i"].Opacity = 1 - $ph
            }
        }

        # Sweat drop while stressed
        if ($face -eq 'stressed') {
            $ph = ($t % 90) / 90.0
            [System.Windows.Controls.Canvas]::SetTop($n.Sweat, 58 + $ph * 40)
            $n.Sweat.Opacity = 1 - $ph * 0.8
        }
    } catch { }
})

$win.Add_Loaded({ Set-Face 'normal'; Update-Slow; $timer.Start(); Say 'MIKEY-BOT online. Hello, Mikey.' })
$win.Add_Closed({ $timer.Stop(); $player.Close() })
$null = $win.ShowDialog()
