// MatrixRain screensaver for Mikey. Build: csc /target:winexe /out:MatrixRain.scr MatrixRain.cs
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

class MatrixForm : Form
{
    const int CellW = 20, CellH = 22;
    readonly Timer timer = new Timer();
    readonly Random rnd = new Random();
    readonly Font font = new Font("Consolas", 17, FontStyle.Bold, GraphicsUnit.Pixel);
    readonly Font hudBig = new Font("Consolas", 64, FontStyle.Bold, GraphicsUnit.Pixel);
    readonly Font hudSmall = new Font("Consolas", 20, FontStyle.Regular, GraphicsUnit.Pixel);
    readonly char[] chars;
    Bitmap buffer; Graphics bg;
    float[] drops; float[] speeds; int[] lastRow;
    Point? startMouse;
    int frame;

    public MatrixForm(Rectangle bounds)
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        Bounds = bounds;
        TopMost = true;
        ShowInTaskbar = false;
        BackColor = Color.Black;
        DoubleBuffered = true;

        chars = "01".ToCharArray();   // binary rain

        buffer = new Bitmap(bounds.Width, bounds.Height);
        bg = Graphics.FromImage(buffer);
        bg.Clear(Color.Black);
        bg.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

        int cols = bounds.Width / CellW + 1;
        drops = new float[cols]; speeds = new float[cols]; lastRow = new int[cols];
        for (int i = 0; i < cols; i++) { drops[i] = -rnd.Next(0, 60); speeds[i] = 0.35f + (float)rnd.NextDouble() * 0.6f; lastRow[i] = -1; }

        timer.Interval = 33;
        timer.Tick += (o, e) => Step();
        Load += (o, e) => { Cursor.Hide(); timer.Start(); };
        MouseMove += (o, e) => {
            if (startMouse == null) { startMouse = e.Location; return; }
            if (Math.Abs(e.X - startMouse.Value.X) > 8 || Math.Abs(e.Y - startMouse.Value.Y) > 8) Application.Exit();
        };
        MouseDown += (o, e) => Application.Exit();
        KeyDown += (o, e) => Application.Exit();
    }

    void Step()
    {
        frame++;
        using (var fade = new SolidBrush(Color.FromArgb(28, 0, 0, 0)))
            bg.FillRectangle(fade, 0, 0, buffer.Width, buffer.Height);

        int rows = buffer.Height / CellH + 1;
        for (int i = 0; i < drops.Length; i++)
        {
            drops[i] += speeds[i];
            int row = (int)drops[i];
            if (row != lastRow[i] && row >= 0)
            {
                int x = i * CellW;
                if (lastRow[i] >= 0)
                    using (var g = new SolidBrush(Color.FromArgb(0, 230, 110)))
                        bg.DrawString(chars[rnd.Next(chars.Length)].ToString(), font, g, x, lastRow[i] * CellH);
                using (var head = new SolidBrush(Color.FromArgb(215, 255, 225)))
                    bg.DrawString(chars[rnd.Next(chars.Length)].ToString(), font, head, x, row * CellH);
                lastRow[i] = row;
            }
            if (row > rows && rnd.NextDouble() > 0.97) { drops[i] = -rnd.Next(0, 20); lastRow[i] = -1; speeds[i] = 0.35f + (float)rnd.NextDouble() * 0.6f; }
        }
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.DrawImageUnscaled(buffer, 0, 0);
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;

        // HUD panel in the centre
        string time = DateTime.Now.ToString("HH:mm:ss");
        string line1 = "MIKEY // SYSTEM IDLE";
        string line2 = (frame / 15) % 2 == 0 ? "> move the mouse to log in_" : "> move the mouse to log in ";
        int w = 560, h = 190;
        int x = (Width - w) / 2, y = (Height - h) / 2;
        using (var panel = new SolidBrush(Color.FromArgb(215, 4, 10, 6)))
            g.FillRectangle(panel, x, y, w, h);
        using (var pen = new Pen(Color.FromArgb(0, 255, 120), 2))
            g.DrawRectangle(pen, x, y, w, h);
        using (var green = new SolidBrush(Color.FromArgb(0, 255, 120)))
        using (var dim = new SolidBrush(Color.FromArgb(90, 190, 130)))
        {
            var center = new StringFormat { Alignment = StringAlignment.Center };
            g.DrawString(line1, hudSmall, dim, new RectangleF(x, y + 18, w, 30), center);
            g.DrawString(time, hudBig, green, new RectangleF(x, y + 50, w, 80), center);
            g.DrawString(line2, hudSmall, dim, new RectangleF(x, y + 140, w, 30), center);
        }
    }
}

static class Program
{
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

    [STAThread]
    static void Main(string[] args)
    {
        string mode = args.Length > 0 ? args[0].ToLowerInvariant().Substring(0, Math.Min(2, args[0].Length)) : "/s";
        if (mode == "/p") return;   // no tiny preview
        if (mode == "/c") { MessageBox.Show("MatrixRain by MIKEY-BOT\nNo settings - just enjoy the rain.", "MatrixRain"); return; }

        SetProcessDPIAware();
        Application.EnableVisualStyles();
        foreach (var screen in Screen.AllScreens)
            new MatrixForm(screen.Bounds).Show();
        Application.Run();
    }
}
