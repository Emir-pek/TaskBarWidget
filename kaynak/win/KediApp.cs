// =====================================================================
//  KediApp.cs  -  widget'in kendisi (C# 5, ASCII)
//
//  catbar.ps1 bu kodu bir kez kucuk bir .exe olarak derler
//  (%LOCALAPPDATA%\TaskbarKedileri\TaskbarKedileri-<ozet>.exe) ve onu
//  baslatip kapanir. Boylece arka planda ~110 MB'lik PowerShell yerine
//  yalnizca bu kucuk WinForms sureci calisir. Exe baslatilamazsa ayni
//  Run() PowerShell icinden cagrilir (eski yontem, yedek).
// =====================================================================
using System;
using System.Collections;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;

namespace TaskbarKedileri
{
    public static class KediApp
    {
        static string _logPath;
        static Mutex _single;

        [STAThread]
        public static int Main(string[] args)
        {
            string log = args.Length > 0 ? args[0] : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "catbar-hata.log");
            try
            {
                Application.EnableVisualStyles();
                Run(log);
                return 0;
            }
            catch (Exception ex)
            {
                Fatal(ex);
                return 1;
            }
        }

        public static void Log(string msg)
        {
            if (string.IsNullOrEmpty(_logPath)) return;
            try
            {
                File.AppendAllText(_logPath, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture)
                                   + "] [bilgi] " + msg + "\r\n", System.Text.Encoding.UTF8);
            }
            catch (Exception) { }
        }

        static void Fatal(Exception ex)
        {
            try
            {
                File.AppendAllText(_logPath, "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture) + "] "
                                   + ex.GetType().Name + ": " + ex.Message + "\r\n" + ex.StackTrace + "\r\n", System.Text.Encoding.UTF8);
            }
            catch (Exception) { }
            MessageBox.Show("Kedi widget'i baslatilamadi.\r\n\r\n" + ex.Message + "\r\n\r\nAyrinti: " + _logPath, "Taskbar Kedileri");
        }

        /// <summary>Widget'i kurar ve mesaj dongusunu calistirir (Cikis'a kadar doner).</summary>
        public static void Run(string logPath)
        {
            _logPath = logPath;

            // tek kopya: iki kez cift tiklanirsa ikinci sessizce cikar
            bool created;
            _single = new Mutex(true, "Local\\TaskbarKedileri", out created);
            if (!created) { Log("Zaten calisiyor, ikinci kopya kapatildi"); return; }

            Log("Verimlilik modu: " + KediWidget.EnableEfficiencyMode() + " | surec: " + Process.GetCurrentProcess().ProcessName);

            string modeSetting = Environment.GetEnvironmentVariable("CATBAR_MODE");
            if (string.IsNullOrEmpty(modeSetting)) modeSetting = "Auto";

            bool desktopOk = false;
            try
            {
                DesktopHost.InitDpi();     // Per-Monitor-V2: ilk WorkingArea sorgusundan ve pencereden ONCE
                string info = DesktopHost.Describe();
                desktopOk = true;
                Log("DesktopHost hazir: " + info);
            }
            catch (Exception ex) { Log("DesktopHost kullanilamadi, siradan pencereye donuluyor: " + ex.Message); }

            // ---- pencere
            Form form;
            DesktopForm df = null;
            if (desktopOk)
            {
                df = new DesktopForm();
                try { df.RequestedMode = (DesktopModeRequest)Enum.Parse(typeof(DesktopModeRequest), modeSetting, true); }
                catch (Exception) { Log("Gecersiz CATBAR_MODE '" + modeSetting + "' (Auto/Desktop/Bottom) - Auto kullaniliyor"); }
                form = df;
            }
            else
            {
                form = new Form();
                form.TopMost = false;
            }
            Color key = Color.FromArgb(255, 0, 255);
            form.FormBorderStyle = FormBorderStyle.None;
            form.ShowInTaskbar = false;
            form.StartPosition = FormStartPosition.Manual;
            form.BackColor = key;
            form.TransparencyKey = key;
            form.Text = "Taskbar Kedileri";
            if (df == null)   // DesktopForm kendi tamponunu kullanir; siradan Form'da WinForms tamponu
                typeof(Control).GetProperty("DoubleBuffered", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(form, true, null);

            // ---- sprite'lar + motor + cizici
            KediWidget widget;
            using (MemoryStream ms = new MemoryStream(Convert.FromBase64String(KediAssets.SheetB64)))
            using (Image sheet = Image.FromStream(ms))
            {
                Hashtable frames = new Hashtable();
                for (int i = 0; i < KediAssets.Names.Length; i++)
                    frames[KediAssets.Names[i]] = new object[] { KediAssets.Xs[i], KediAssets.Ys[i] };
                widget = new KediWidget(form, sheet, frames, KediAssets.CellW, KediAssets.CellH);
            }

            int userScale = 2;
            MethodInvoker updateBounds = delegate
            {
                Rectangle wa = desktopOk ? DesktopHost.GetWorkArea() : Screen.PrimaryScreen.WorkingArea;
                int px = desktopOk ? DesktopHost.GetPixelScale() : 1;      // %150+ DPI'da tam sayi carpan
                int scale = userScale * Math.Max(1, px);
                int h = (KediAssets.CellH + Engine.HEADROOM) * scale;
                // Bounds HER ZAMAN ekran koordinati; DesktopForm Progman/WorkerW icindeyken kendisi cevirir.
                form.Bounds = new Rectangle(wa.X, wa.Bottom - h, wa.Width, h);
                widget.SetLayout(scale, (int)Math.Floor((double)wa.Width / scale));
            };
            updateBounds();

            if (df != null)
            {
                // taskbar tasindi / boyut / otomatik gizle, cozunurluk ya da DPI degisti, Explorer yeniden basladi
                df.WorkAreaChanged += delegate { updateBounds(); };
                df.ModeChanged += delegate { Log("Masaustu modu: " + df.Mode + " | " + df.ModeDetail); };
                df.LogMessage += delegate (object s, DesktopLogEventArgs e) { Log("DesktopHost: " + e.Message); };
            }

            // ---- menu (sag tik)
            ContextMenuStrip menu = new ContextMenuStrip();
            ToolStripItem miPause = menu.Items.Add("Duraklat");
            miPause.Click += delegate
            {
                widget.Paused = !widget.Paused;
                miPause.Text = widget.Paused ? "Devam et" : "Duraklat";
            };
            menu.Items.Add("-");
            for (int z = 1; z <= 3; z++)
            {
                int zz = z;
                ToolStripItem mi = menu.Items.Add("Boyut " + z + "x");
                mi.Click += delegate { userScale = zz; updateBounds(); };
            }
            menu.Items.Add("-");
            menu.Items.Add("Sahneyi degistir").Click += delegate { widget.NextScene(); };

            if (df != null)
            {
                menu.Items.Add("-");
                ToolStripMenuItem miMode = new ToolStripMenuItem("Konum");
                ToolStripMenuItem miInfo = new ToolStripMenuItem("Aktif: ?");
                miInfo.Enabled = false;
                miMode.DropDownItems.Add(miInfo);
                string[][] modes = { new string[] { "Otomatik", "Auto" }, new string[] { "Masaustune yerlestir", "Desktop" },
                                     new string[] { "Pencerelerin altinda", "Bottom" } };
                foreach (string[] pair in modes)
                {
                    ToolStripMenuItem it = new ToolStripMenuItem(pair[0]);
                    it.Tag = pair[1];
                    it.Click += delegate (object s, EventArgs e)
                    {
                        df.RequestedMode = (DesktopModeRequest)Enum.Parse(typeof(DesktopModeRequest), (string)((ToolStripItem)s).Tag);
                    };
                    miMode.DropDownItems.Add(it);
                }
                miMode.DropDownOpening += delegate
                {
                    miInfo.Text = "Aktif: " + df.Mode;
                    foreach (ToolStripItem it in miMode.DropDownItems)
                    {
                        ToolStripMenuItem tm = it as ToolStripMenuItem;
                        if (tm != null && tm.Tag != null) tm.Checked = (string)tm.Tag == df.RequestedMode.ToString();
                    }
                };
                menu.Items.Add(miMode);
            }

            menu.Items.Add("-");
            menu.Items.Add("Cikis").Click += delegate { form.Close(); };
            form.ContextMenuStrip = menu;

            // ---- olcum (istege bagli): CATBAR_PERF=1 ise her 30 sn log'a yazar
            if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("CATBAR_PERF")))
            {
                Process me = Process.GetCurrentProcess();
                TimeSpan cpu0 = me.TotalProcessorTime;
                DateTime t0 = DateTime.UtcNow;
                System.Windows.Forms.Timer perf = new System.Windows.Forms.Timer();
                perf.Interval = 30000;
                perf.Tick += delegate
                {
                    me.Refresh();
                    DateTime now = DateTime.UtcNow;
                    double pct = (me.TotalProcessorTime - cpu0).TotalMilliseconds / (now - t0).TotalMilliseconds * 100.0;
                    Log(string.Format(CultureInfo.InvariantCulture,
                        "PERF cpu={0:F2}% (1 cekirdek) ws={1:F1}MB ozel={2:F1}MB | {3}",
                        pct, me.WorkingSet64 / 1048576.0, me.PrivateMemorySize64 / 1048576.0, widget.Stats()));
                    cpu0 = me.TotalProcessorTime; t0 = now;
                };
                perf.Start();
            }

            // ---- dongu
            form.FormClosed += delegate { widget.Dispose(); Application.Exit(); };
            // Run(form) DEGIL: Explorer yeniden baslayinca cocuk pencereyi yok eder; formsuz
            // dongu ayakta kalir, DesktopForm penceresini yeniden kurar. "Cikis" yine Exit cagirir.
            form.Show();
            GC.Collect();
            GC.WaitForPendingFinalizers();
            Application.Run();
            GC.KeepAlive(_single);
        }
    }
}
