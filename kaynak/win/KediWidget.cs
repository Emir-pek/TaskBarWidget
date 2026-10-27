// =====================================================================
//  KediWidget.cs  -  Windows cizici + zamanlayici + tiklama (C# 5, ASCII)
//
//  PowerShell yalnizca kurulumu yapar (pencere, menu); her tick'te calisan
//  her sey burada, derlenmis kodda:
//    - Engine.Step()                      (tick basina ~mikrosaniyeler)
//    - yalnizca DEGISEN sprite'larin dikdortgenleri yeniden cizilir
//      (onceden her tick 1920x134 pencerenin tamami temizlenip ciziliyordu)
//    - pencere tamamen ortuluyken (tam ekran uygulama, ekran kilidi, her
//      sprite'in ustunde bir pencere) motor ve cizim DURUR; 320 ms'de bir
//      sadece "gorunur oldum mu?" diye bakilir
//    - surec "verimlilik" moduna alinir: BelowNormal oncelik + EcoQoS
//      (Win10 1709+/Win11). Kullanicinin uygulamalari her zaman once gelir.
// =====================================================================
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace TaskbarKedileri
{
    internal static class KediNative
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT { public int X; public int Y; public POINT(int x, int y) { X = x; Y = y; } }

        [StructLayout(LayoutKind.Sequential)]
        public struct POWER_THROTTLING { public uint Version; public uint ControlMask; public uint StateMask; }

        [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
        [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hwnd, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder name, int max);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetProcessInformation(IntPtr process, int infoClass, ref POWER_THROTTLING info, int size);
        [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();

        public const uint GA_ROOT = 2;
        public const int ProcessPowerThrottling = 4;
    }

    public sealed class KediWidget : IDisposable
    {
        const int CoveredCheckEvery = 4;      // gorunurken: 4 tick'te bir (~320 ms)
        const int CoveredInterval = 320;      // ortuluyken zamanlayici araligi (ms)

        readonly Control _form;
        readonly Bitmap _sheet, _sheetF;      // 32bppPArgb: GDI+'in en hizli kaynak bicimi
        readonly bool[] _opaque;              // tiklama testi icin alfa maskesi
        readonly int _sheetW, _sheetH, _cw, _ch;
        readonly Dictionary<string, Point> _frames = new Dictionary<string, Point>();
        readonly Dictionary<string, Bitmap> _scaledCache = new Dictionary<string, Bitmap>();
        readonly System.Windows.Forms.Timer _timer;
        readonly Random _rand = new Random();
        readonly StringBuilder _cls = new StringBuilder(64);

        Engine _eng;
        int _scale = 2;
        bool _paused, _covered, _disposed;
        int _sinceCheck;

        // istatistik (CATBAR_PERF=1 iken PowerShell log'a yazar)
        long _ticks, _coveredTicks, _paints, _rectsPainted;
        readonly Stopwatch _stepWatch = new Stopwatch(), _paintWatch = new Stopwatch(), _tickWatch = new Stopwatch();

        public KediWidget(Control form, Image sheet, IDictionary frames, int cellW, int cellH)
        {
            _form = form;
            _cw = cellW; _ch = cellH;
            _sheetW = sheet.Width; _sheetH = sheet.Height;
            _sheet = new Bitmap(_sheetW, _sheetH, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(_sheet))
            {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawImage(sheet, new Rectangle(0, 0, _sheetW, _sheetH), 0, 0, _sheetW, _sheetH, GraphicsUnit.Pixel);
            }
            _sheetF = (Bitmap)_sheet.Clone();
            _sheetF.RotateFlip(RotateFlipType.RotateNoneFlipX);

            _opaque = new bool[_sheetW * _sheetH];
            using (Bitmap argb = new Bitmap(sheet))
            {
                BitmapData bd = argb.LockBits(new Rectangle(0, 0, _sheetW, _sheetH), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                try
                {
                    byte[] row = new byte[_sheetW * 4];
                    for (int y = 0; y < _sheetH; y++)
                    {
                        Marshal.Copy(new IntPtr(bd.Scan0.ToInt64() + (long)y * bd.Stride), row, 0, row.Length);
                        for (int x = 0; x < _sheetW; x++) _opaque[y * _sheetW + x] = row[x * 4 + 3] > 0;
                    }
                }
                finally { argb.UnlockBits(bd); }
            }

            foreach (DictionaryEntry de in frames)
            {
                object[] xy = de.Value as object[];
                if (xy == null || xy.Length < 2) continue;
                _frames[(string)de.Key] = new Point(Convert.ToInt32(xy[0]), Convert.ToInt32(xy[1]));
            }

            _timer = new System.Windows.Forms.Timer();
            _timer.Interval = Engine.TICK;
            _timer.Tick += OnTick;
            _form.Paint += OnPaint;
            _form.MouseDown += OnMouseDown;
        }

        // ============================================================ public API (PowerShell)

        /// <summary>Ilk cagrida motoru kurar ve zamanlayiciyi baslatir.</summary>
        public void SetLayout(int scale, int screenW)
        {
            if (Math.Max(1, scale) != _scale) ClearScaled();
            _scale = Math.Max(1, scale);
            if (_eng == null)
            {
                _eng = new Engine(screenW, (double)(Environment.TickCount & 0x7fffffff));
                _timer.Start();
            }
            else _eng.SetScreen(screenW);
            InvalidateAll();
        }

        public bool Paused { get { return _paused; } set { _paused = value; } }

        /// <summary>Testler icin: motorun kendisi.</summary>
        public Engine Engine { get { return _eng; } }

        public void NextScene()
        {
            if (_eng == null) return;
            List<string> others = new List<string>();
            foreach (string n in Engine.ORDER) if (n != _eng.Scene) others.Add(n);
            _eng.ApplyScene(others[_rand.Next(others.Count)]);
        }

        public string Stats()
        {
            double avgStep = _ticks - _coveredTicks > 0 ? _stepWatch.Elapsed.TotalMilliseconds / (_ticks - _coveredTicks) : 0;
            double avgPaint = _paints > 0 ? _paintWatch.Elapsed.TotalMilliseconds / _paints : 0;
            string s = string.Format(System.Globalization.CultureInfo.InvariantCulture,
                "tick={0} ortulu={1} step={2:F4}ms tick_toplam={7:F3}ms/tick boyama={3} ({4:F3}ms/boyama, {5} dikdortgen) olcek={6}",
                _ticks, _coveredTicks, avgStep, _paints, avgPaint, _rectsPainted, _scale,
                _ticks > 0 ? _tickWatch.Elapsed.TotalMilliseconds / _ticks : 0);
            DesktopForm df = _form as DesktopForm;
            if (df != null) s += " | " + df.PerfStats();
            return s;
        }

        /// <summary>BelowNormal oncelik + EcoQoS (Win11 "verimlilik modu"nun CPU tarafi). Hata sessizce yutulur.</summary>
        public static string EnableEfficiencyMode()
        {
            string r = "";
            try { Process.GetCurrentProcess().PriorityClass = ProcessPriorityClass.BelowNormal; r += "oncelik=BelowNormal"; }
            catch (Exception ex) { r += "oncelik hata: " + ex.Message; }
            try
            {
                KediNative.POWER_THROTTLING s = new KediNative.POWER_THROTTLING();
                s.Version = 1; s.ControlMask = 1; s.StateMask = 1;   // EXECUTION_SPEED -> EcoQoS
                bool ok = KediNative.SetProcessInformation(KediNative.GetCurrentProcess(), KediNative.ProcessPowerThrottling,
                                                           ref s, Marshal.SizeOf(typeof(KediNative.POWER_THROTTLING)));
                r += ok ? " EcoQoS=acik" : " EcoQoS=desteklenmiyor";
            }
            catch (Exception) { r += " EcoQoS=yok"; }   // eski Windows: fonksiyon yok
            return r;
        }

        // ============================================================ tick

        void OnTick(object sender, EventArgs e)
        {
            if (_disposed || _eng == null) return;
            _ticks++;
            _tickWatch.Start();
            try { TickBody(); }
            finally { _tickWatch.Stop(); }
        }

        void TickBody()
        {
            if (_covered || ++_sinceCheck >= CoveredCheckEvery)
            {
                _sinceCheck = 0;
                bool cov = !AnyItemVisible();
                if (cov != _covered)
                {
                    _covered = cov;
                    _timer.Interval = cov ? CoveredInterval : Engine.TICK;
                }
            }
            if (_covered) { _coveredTicks++; return; }   // kimse gormuyor: ne motor ne cizim

            if (!_paused)
            {
                _stepWatch.Start();
                _eng.Step();
                _stepWatch.Stop();
            }
            InvalidateChanges();
        }

        string KeyOf(DrawItem d) { return d.K + "|" + d.X + "|" + d.Y + (d.F ? "|f" : "|"); }

        Rectangle RectOf(DrawItem d) { return new Rectangle(d.X * _scale, d.Y * _scale, _cw * _scale, _ch * _scale); }

        /// <summary>Ekranda su an duranlar (anahtar -> alan). Bir sonraki karede farklar bulunur.</summary>
        Dictionary<string, Rectangle> _shown = new Dictionary<string, Rectangle>();

        /// <summary>Onceki kareyle farkli olan sprite'larin alanlarini (eski + yeni yer) yeniden boyatir.</summary>
        void InvalidateChanges()
        {
            Dictionary<string, Rectangle> now = Snapshot();
            List<Rectangle> dirty = new List<Rectangle>();
            foreach (KeyValuePair<string, Rectangle> kv in now)
                if (!_shown.ContainsKey(kv.Key)) dirty.Add(kv.Value);          // yeni / degisen kare
            foreach (KeyValuePair<string, Rectangle> kv in _shown)
                if (!now.ContainsKey(kv.Key)) dirty.Add(kv.Value);             // eski yeri silinmeli
            _shown = now;
            PaintRects(Merge(dirty));
        }

        Dictionary<string, Rectangle> Snapshot()
        {
            Dictionary<string, Rectangle> d = new Dictionary<string, Rectangle>();
            if (_eng == null) return d;
            int n = 0;
            foreach (DrawItem it in _eng.Draw)
            {
                string k = KeyOf(it);
                if (d.ContainsKey(k)) k = k + "#" + (n++);   // ayni yerde iki ayni kare (cok nadir)
                d[k] = RectOf(it);
            }
            return d;
        }

        static List<Rectangle> Merge(List<Rectangle> rs)
        {
            List<Rectangle> o = new List<Rectangle>(rs);
            bool merged = true;
            while (merged)
            {
                merged = false;
                for (int a = 0; a < o.Count && !merged; a++)
                    for (int b = a + 1; b < o.Count; b++)
                    {
                        Rectangle ra = o[a], rb = o[b];
                        Rectangle grown = Rectangle.Inflate(ra, 4, 4);
                        if (grown.IntersectsWith(rb))
                        {
                            o[a] = Rectangle.Union(ra, rb);
                            o.RemoveAt(b);
                            merged = true;
                            break;
                        }
                    }
            }
            return o;
        }

        void PaintRects(List<Rectangle> rs)
        {
            if (rs.Count == 0 || !_form.IsHandleCreated || !_form.Visible) return;
            Rectangle client = _form.ClientRectangle;
            List<Rectangle> parts = new List<Rectangle>(rs.Count);
            foreach (Rectangle r0 in rs)
            {
                Rectangle r = Rectangle.Intersect(r0, client);
                if (r.Width > 0 && r.Height > 0) parts.Add(r);
            }
            if (parts.Count == 0) return;
            DesktopForm df = _form as DesktopForm;
            if (df != null)
            {
                // tek WM_PAINT: tum kucuk alanlar birlikte, ama yalnizca onlar yeniden olusturulur
                df.DirtyHint = parts;
                foreach (Rectangle r in parts) _form.Invalidate(r);
                _form.Update();
                df.DirtyHint = null;
                _rectsPainted += parts.Count;
                return;
            }
            foreach (Rectangle r in parts)
            {
                _form.Invalidate(r);
                _form.Update();          // siradan Form: her dikdortgen ayri ve kucuk bir WM_PAINT
                _rectsPainted++;
            }
        }

        void InvalidateAll()
        {
            _shown = Snapshot();
            if (_form.IsHandleCreated) _form.Invalidate();
        }

        // ============================================================ boyama

        void OnPaint(object sender, PaintEventArgs e)
        {
            if (_eng == null) return;
            _paintWatch.Start();
            Graphics g = e.Graphics;
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.None;
            g.SmoothingMode = SmoothingMode.None;
            g.CompositingQuality = CompositingQuality.HighSpeed;
            g.CompositingMode = CompositingMode.SourceOver;
            Rectangle clip = e.ClipRectangle;
            foreach (DrawItem d in _eng.Draw)
            {
                Rectangle dst = RectOf(d);
                if (!dst.IntersectsWith(clip)) continue;
                Bitmap b = Scaled(d.K, d.F);
                if (b != null) g.DrawImage(b, dst, 0, 0, dst.Width, dst.Height, GraphicsUnit.Pixel);   // olceklemesiz kopya
            }
            _paintWatch.Stop();
            _paints++;
        }

        /// <summary>Karenin bu olcekte onceden buyutulmus kopyasi (ilk kullanimda olusur).</summary>
        Bitmap Scaled(string k, bool flip)
        {
            string key = flip ? k + "|f" : k;
            Bitmap b;
            if (_scaledCache.TryGetValue(key, out b)) return b;
            Point p;
            if (!_frames.TryGetValue(k, out p)) return null;
            int w = _cw * _scale, h = _ch * _scale;
            b = new Bitmap(w, h, PixelFormat.Format32bppPArgb);
            using (Graphics g = Graphics.FromImage(b))
            {
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.PixelOffsetMode = PixelOffsetMode.Half;
                g.CompositingMode = CompositingMode.SourceCopy;
                Rectangle dst = new Rectangle(0, 0, w, h);
                if (flip) g.DrawImage(_sheetF, dst, _sheetW - p.X - _cw, p.Y, _cw, _ch, GraphicsUnit.Pixel);
                else g.DrawImage(_sheet, dst, p.X, p.Y, _cw, _ch, GraphicsUnit.Pixel);
            }
            _scaledCache[key] = b;
            return b;
        }

        void ClearScaled()
        {
            foreach (Bitmap b in _scaledCache.Values) b.Dispose();
            _scaledCache.Clear();
        }

        // ============================================================ tiklama

        bool Hit(string k, int lx, int ly)
        {
            Point p;
            if (!_frames.TryGetValue(k, out p)) return false;
            int x = p.X + lx, y = p.Y + ly;
            if (x < 0 || y < 0 || x >= _sheetW || y >= _sheetH) return false;
            return _opaque[y * _sheetW + x];
        }

        void OnMouseDown(object sender, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left || _eng == null) return;
            int sx = (int)Math.Floor((double)e.X / _scale), sy = (int)Math.Floor((double)e.Y / _scale);
            _eng.ClickAt(sx, sy, _cw, _ch, Hit);   // kedi: zipla, Dogis: sevin / bik
            if (_covered) { _covered = false; _timer.Interval = Engine.TICK; }
        }

        // ============================================================ gorunurluk

        /// <summary>Herhangi bir sprite'in uzerinde masaustu (ya da biz) gorunuyor mu?</summary>
        bool AnyItemVisible()
        {
            try
            {
                if (!_form.IsHandleCreated || !_form.Visible) return false;
                Point o = _form.PointToScreen(Point.Empty);
                IntPtr me = _form.Handle;
                IntPtr myRoot = KediNative.GetAncestor(me, KediNative.GA_ROOT);
                foreach (DrawItem d in _eng.Draw)
                {
                    Rectangle r = RectOf(d);
                    int cx = o.X + r.X + r.Width / 2, y1 = o.Y + r.Y + r.Height * 2 / 3;
                    if (Shows(cx, y1, me, myRoot)) return true;
                    if (Shows(o.X + r.X + r.Width / 4, y1, me, myRoot)) return true;
                    if (Shows(o.X + r.X + r.Width * 3 / 4, y1, me, myRoot)) return true;
                    if (Shows(cx, o.Y + r.Y + r.Height / 3, me, myRoot)) return true;
                }
                return false;
            }
            catch (Exception) { return true; }   // emin degilsek calismaya devam
        }

        bool Shows(int x, int y, IntPtr me, IntPtr myRoot)
        {
            IntPtr h = KediNative.WindowFromPoint(new KediNative.POINT(x, y));
            if (h == IntPtr.Zero) return false;                 // ekran disi / kilit ekrani
            IntPtr root = KediNative.GetAncestor(h, KediNative.GA_ROOT);
            if (root == me || root == myRoot) return true;     // biz ya da bizi tasiyan masaustu
            _cls.Length = 0;
            KediNative.GetClassName(root, _cls, _cls.Capacity);
            string c = _cls.ToString();
            return c == "Progman" || c == "WorkerW";           // masaustu (ikonlar / duvar kagidi)
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            _timer.Stop();
            _timer.Dispose();
            _form.Paint -= OnPaint;
            _form.MouseDown -= OnMouseDown;
            ClearScaled();
            _sheet.Dispose();
            _sheetF.Dispose();
        }
    }
}
