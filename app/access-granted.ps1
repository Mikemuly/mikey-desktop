# Full-screen "ACCESS GRANTED" splash.
# Runs in the background from sign-in: the window is built once and kept hidden, and Windows
# notifies us the instant the session is unlocked, so the splash appears immediately.
#   -Logon   also show the splash (with chime + greeting) right away at start-up
#   -Once    show it once and exit (for testing)
# Click or press any key to skip the splash.
param([switch]$Logon, [switch]$Once)

# one background instance per user session
$mutex = New-Object System.Threading.Mutex($false, "Local\MIKEY_AccessGranted")
if (-not $Once -and -not $mutex.WaitOne(0)) { exit }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -ReferencedAssemblies System.Windows.Forms @'
using System; using System.Runtime.InteropServices; using System.Windows.Forms;
public class SessionWatcher : NativeWindow, IDisposable {
    [DllImport("wtsapi32.dll")] static extern bool WTSRegisterSessionNotification(IntPtr hWnd, int flags);
    [DllImport("wtsapi32.dll")] static extern bool WTSUnRegisterSessionNotification(IntPtr hWnd);
    public event EventHandler Unlocked;
    public SessionWatcher() { CreateHandle(new CreateParams()); WTSRegisterSessionNotification(Handle, 0); }
    protected override void WndProc(ref Message m) {
        // WM_WTSSESSION_CHANGE + WTS_SESSION_UNLOCK
        if (m.Msg == 0x02B1 && m.WParam.ToInt32() == 8 && Unlocked != null) Unlocked(this, EventArgs.Empty);
        base.WndProc(ref m);
    }
    public void Dispose() { WTSUnRegisterSessionNotification(Handle); DestroyHandle(); }
}
'@

$voiceDir = Join-Path $PSScriptRoot 'voice'

function New-ChimeWav {
    $rate = 44100
    $notes = @(@{f=523.25; d=0.10}, @{f=783.99; d=0.10}, @{f=1046.5; d=0.30})
    $samples = New-Object System.Collections.Generic.List[int16]
    foreach ($nt in $notes) {
        $count = [int]($rate * $nt.d)
        for ($i = 0; $i -lt $count; $i++) {
            $t = $i / $rate
            $env = [Math]::Exp(-4 * $t / $nt.d) * [Math]::Min(1, $i / 200.0)
            $v = [Math]::Sin(2 * [Math]::PI * $nt.f * $t) * 0.6 + [Math]::Sin(4 * [Math]::PI * $nt.f * $t) * 0.15
            $samples.Add([int16]([Math]::Max(-1, [Math]::Min(1, $v * $env)) * 18000))
        }
    }
    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
    $len = $samples.Count * 2
    $w.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $w.Write([int](36 + $len)); $w.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1); $w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
    $w.Write([Text.Encoding]::ASCII.GetBytes('data')); $w.Write([int]$len)
    foreach ($s in $samples) { $w.Write($s) }
    $w.Flush(); $ms.Position = 0; $ms
}
# generate the chime once and cache it as a .wav (saves ~1-2 s at every sign-in)
$chimeFile = Join-Path $voiceDir 'chime.wav'
if (-not (Test-Path $chimeFile)) { $ms = New-ChimeWav; [IO.File]::WriteAllBytes($chimeFile, $ms.ToArray()) }
$chime = New-Object System.Media.SoundPlayer $chimeFile; $chime.Load()

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" ResizeMode="NoResize" WindowState="Maximized" Topmost="True"
        ShowInTaskbar="False" ShowActivated="True" Background="#020604" AllowsTransparency="True">
  <Grid>
    <Rectangle Opacity="0.25">
      <Rectangle.Fill>
        <DrawingBrush TileMode="Tile" Viewport="0,0,4,4" ViewportUnits="Absolute">
          <DrawingBrush.Drawing>
            <GeometryDrawing Brush="#0B2416"><GeometryDrawing.Geometry><RectangleGeometry Rect="0,0,4,1"/></GeometryDrawing.Geometry></GeometryDrawing>
          </DrawingBrush.Drawing>
        </DrawingBrush>
      </Rectangle.Fill>
    </Rectangle>
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" Width="900">
      <TextBlock x:Name="Line1" FontFamily="Consolas" FontSize="24" Foreground="#5AE09A" HorizontalAlignment="Center"/>
      <Border Margin="0,22,0,0" Width="600" Height="14" BorderBrush="#00C864" BorderThickness="1" HorizontalAlignment="Center">
        <Rectangle x:Name="Bar" Width="0" HorizontalAlignment="Left" Fill="#00FF78">
          <Rectangle.Effect><DropShadowEffect Color="#00FF78" BlurRadius="12" ShadowDepth="0"/></Rectangle.Effect>
        </Rectangle>
      </Border>
      <TextBlock x:Name="Pct" Margin="0,8,0,0" FontFamily="Consolas" FontSize="16" Foreground="#2E8A5A" HorizontalAlignment="Center"/>
      <TextBlock x:Name="Granted" Margin="0,30,0,0" Text="ACCESS GRANTED" FontFamily="Consolas" FontWeight="Bold" FontSize="96"
                 Foreground="#00FF78" HorizontalAlignment="Center" Opacity="0">
        <TextBlock.Effect><DropShadowEffect Color="#00FF78" BlurRadius="40" ShadowDepth="0" Opacity="1"/></TextBlock.Effect>
        <TextBlock.RenderTransform><TranslateTransform x:Name="Glitch" X="0"/></TextBlock.RenderTransform>
      </TextBlock>
      <TextBlock x:Name="Sub" Margin="0,10,0,0" FontFamily="Consolas" FontSize="28" Foreground="#B4F0C8" HorizontalAlignment="Center" Opacity="0"/>
    </StackPanel>
  </Grid>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$n = @{}; foreach ($k in 'Line1','Bar','Pct','Granted','Sub','Glitch') { $n[$k] = $win.FindName($k) }
$player = New-Object System.Windows.Media.MediaPlayer
$script:showing = $false; $script:spoken = $false; $script:start = Get-Date; $script:clipFile = $null

function Show-Splash([bool]$isLogon) {
    $h = (Get-Date).Hour
    $part = if ($h -lt 12) { 'morning' } elseif ($h -lt 18) { 'afternoon' } else { 'evening' }
    $clip = if ($isLogon) { "login_$part" } else { 'granted' }
    $sub  = if ($isLogon) { "Good $part, Mikey." } else { 'Welcome back, Mikey.' }
    $n.Line1.Text = '> AUTHENTICATING USER: MIKEY'
    $n.Bar.Width = 0; $n.Pct.Text = '0%'
    $n.Granted.Opacity = 0; $n.Sub.Opacity = 0
    $n.Sub.Text = "$sub  //  $((Get-Date).ToString('dddd, HH:mm'))"
    $win.Opacity = 1
    $script:clipFile = Join-Path $voiceDir "$clip.mp3"
    if (Test-Path $script:clipFile) { $player.Open([uri]$script:clipFile) } else { $script:clipFile = $null }
    $script:spoken = $false; $script:start = Get-Date; $script:showing = $true
    $win.Show(); $win.Topmost = $true; [void]$win.Activate()
    if ($isLogon) { try { $chime.Play() } catch { } }
    $timer.Start()
}
function Hide-Splash {
    $timer.Stop(); $script:showing = $false
    $win.Hide()
    if ($Once) {
        # let the voice finish, then exit
        $deadline = (Get-Date).AddSeconds(4)
        try { while ($script:spoken -and $player.NaturalDuration.HasTimeSpan -and $player.Position -lt $player.NaturalDuration.TimeSpan -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 } } catch { }
        $win.Dispatcher.InvokeShutdown()
    }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(16)
$timer.Add_Tick({
    $t = ((Get-Date) - $script:start).TotalMilliseconds
    if ($t -lt 1100) {                                   # progress bar
        $p = [Math]::Min(1, $t / 1000)
        $n.Bar.Width = 598 * $p; $n.Pct.Text = "$([int]($p * 100))%"
    } elseif ($t -lt 4200) {                             # ACCESS GRANTED
        if (-not $script:spoken) {
            $script:spoken = $true
            $n.Line1.Text = '> IDENTITY VERIFIED'; $n.Pct.Text = '100%'; $n.Bar.Width = 598
            if ($script:clipFile) { $player.Play() }
        }
        $g = $t - 1100
        $n.Granted.Opacity = $(if ($g -lt 300) { $(if ((([int]($g / 50)) % 2) -eq 0) { 1 } else { 0.2 }) } else { 1 })
        $n.Glitch.X = $(if ($g -lt 300) { (Get-Random -Minimum -12 -Maximum 12) } else { 0 })
        $n.Sub.Opacity = [Math]::Min(1, [Math]::Max(0, ($g - 300) / 400))
    } elseif ($t -lt 4700) {                             # fade out
        $win.Opacity = 1 - ($t - 4200) / 500
    } else { Hide-Splash }
})

$win.Add_KeyDown({ if ($script:showing) { Hide-Splash } })
$win.Add_MouseDown({ if ($script:showing) { Hide-Splash } })
$win.Add_Closing({ param($s, $e) if (-not $Once) { $e.Cancel = $true; Hide-Splash } })   # never really close the background window

# Pre-build the window off-screen so later Show() calls are instant
$win.Opacity = 0; $win.Show(); $win.Hide()

$watcher = $null
if (-not $Once) {
    $watcher = New-Object SessionWatcher
    $watcher.Add_Unlocked({ Show-Splash $false })
}
if ($Logon -or $Once) { Show-Splash ([bool]$Logon) }

[System.Windows.Threading.Dispatcher]::Run()
if ($watcher) { $watcher.Dispose() }
