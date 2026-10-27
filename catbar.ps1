# =====================================================================
#  Taskbar Kedileri  -  pixel art masaustu widget'i
#  Bagimliligi yok: Windows'ta hazir gelen PowerShell + WinForms yeterli.
#  Baslatmak icin "Kedileri Baslat.bat" dosyasina cift tikla.
#
#  BU DOSYA URETILIR: kaynak/catbar_tpl.ps1 + kaynak/engine.ps1 +
#  kaynak/win/DesktopHost.cs + sprite sheet -> python kaynak/mkdist.py
# =====================================================================
$ErrorActionPreference = 'Stop'
$LogPath = Join-Path $PSScriptRoot 'catbar-hata.log'

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- masaustu penceresi
# Kurulum gerekmez: C# kaynagi Windows'taki .NET Framework derleyicisiyle
# (Add-Type -> csc.exe) acilista bellege derlenir. Pencere masaustu
# katmanina yerlesir: acilan her pencere kedilerin ONUNE gecer.
$DesktopHostCs = @'
// =====================================================================
//  DesktopHost.cs  -  Taskbar Kedileri: "true desktop widget" window
//
//  Compiled at runtime by Windows PowerShell 5.1 Add-Type (legacy CodeDom
//  csc.exe of .NET Framework 4.x)  ->  C# 5 syntax ONLY:
//    no $"..", no ?. , no nameof, no => members, no auto-property
//    initialisers, no out var, no unsafe code.  Keep this file ASCII.
//
//  References: System.Windows.Forms, System.Drawing
//
//  Modes (DesktopForm.Mode):
//    "Desktop" - PRIMARY. The form is created as a WS_CHILD + WS_EX_LAYERED
//                window of the top-level window that hosts SHELLDLL_DefView
//                (Progman on Win11 24H2+ "raised desktop" and on a plain
//                Win10/11 desktop; a WorkerW on older trees after 0x052C).
//                It sits above the icon view, below every app window, and
//                rides along with the desktop during Show Desktop.
//    "Bottom"  - FALLBACK. Unowned top-level tool window (WS_EX_NOACTIVATE)
//                kept directly above the desktop host in the z-order; any
//                attempt to change its z-order is vetoed in
//                WM_WINDOWPOSCHANGING; a watchdog + WinEvent hook re-place
//                it (this is also what makes it visible during Show Desktop).
//
//  Click-through: transparent (TransparencyKey) pixels let clicks through
//  natively (layered colour-key hit testing) AND the form toggles
//  WS_EX_TRANSPARENT from a 30 ms cursor poll against its own back buffer,
//  so pass-through works even where native hit testing would not.
// =====================================================================
using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace TaskbarKedileri
{
    public enum DesktopModeRequest
    {
        Auto = 0,     // Desktop if possible, else Bottom
        Desktop = 1,  // same as Auto, but also clears an earlier hard failure
        Bottom = 2    // never reparent into Explorer
    }

    public class DesktopLogEventArgs : EventArgs
    {
        private readonly string _message;
        public DesktopLogEventArgs(string message) { _message = message; }
        public string Message { get { return _message; } }
    }

    // -----------------------------------------------------------------
    //  Win32
    // -----------------------------------------------------------------
    internal static class Native
    {
        public const int GWL_STYLE = -16;
        public const int GWL_EXSTYLE = -20;

        public const int WS_CHILD = 0x40000000;
        public const int WS_POPUP = unchecked((int)0x80000000);
        public const int WS_CLIPSIBLINGS = 0x04000000;
        public const int WS_CAPTION = 0x00C00000;
        public const int WS_SYSMENU = 0x00080000;
        public const int WS_THICKFRAME = 0x00040000;
        public const int WS_MINIMIZEBOX = 0x00020000;
        public const int WS_MAXIMIZEBOX = 0x00010000;

        public const int WS_EX_TOPMOST = 0x00000008;
        public const int WS_EX_TRANSPARENT = 0x00000020;
        public const int WS_EX_TOOLWINDOW = 0x00000080;
        public const int WS_EX_APPWINDOW = 0x00040000;
        public const int WS_EX_LAYERED = 0x00080000;
        public const int WS_EX_NOREDIRECTIONBITMAP = 0x00200000;
        public const int WS_EX_NOACTIVATE = 0x08000000;

        public const uint SWP_NOSIZE = 0x0001;
        public const uint SWP_NOMOVE = 0x0002;
        public const uint SWP_NOZORDER = 0x0004;
        public const uint SWP_NOACTIVATE = 0x0010;
        public const uint SWP_NOOWNERZORDER = 0x0200;

        public static readonly IntPtr HWND_TOP = IntPtr.Zero;
        public static readonly IntPtr HWND_BOTTOM = new IntPtr(1);
        public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);

        public const uint GW_HWNDNEXT = 2;
        public const uint GW_HWNDPREV = 3;
        public const uint GW_CHILD = 5;

        public const int WM_DESTROY = 0x0002;
        public const int WM_SETTINGCHANGE = 0x001A;
        public const int WM_MOUSEACTIVATE = 0x0021;
        public const int WM_WINDOWPOSCHANGING = 0x0046;
        public const int WM_CONTEXTMENU = 0x007B;
        public const int WM_DISPLAYCHANGE = 0x007E;
        public const int WM_DPICHANGED = 0x02E0;
        public const int WM_DPICHANGED_AFTERPARENT = 0x02E3;

        public const int MA_NOACTIVATE = 3;
        public const uint LWA_COLORKEY = 0x1;
        public const uint LWA_ALPHA = 0x2;
        public const int SW_SHOWNOACTIVATE = 4;
        public const int VK_LBUTTON = 0x01;
        public const int VK_RBUTTON = 0x02;
        public const int SPI_GETWORKAREA = 0x0030;
        public const int LOGPIXELSX = 88;
        public const uint MONITOR_DEFAULTTOPRIMARY = 1;
        public const int DWMWA_CLOAKED = 14;
        public const int DWMWA_EXCLUDED_FROM_PEEK = 12;

        public const uint EVENT_SYSTEM_FOREGROUND = 0x0003;
        public const uint EVENT_SYSTEM_MINIMIZESTART = 0x0016;
        public const uint EVENT_SYSTEM_MINIMIZEEND = 0x0017;
        public const uint WINEVENT_OUTOFCONTEXT = 0x0000;

        // DPI_AWARENESS_CONTEXT pseudo handles
        public static readonly IntPtr DPI_CTX_PER_MONITOR_V2 = new IntPtr(-4);

        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
            public POINT(int x, int y) { X = x; Y = y; }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct WINDOWPOS
        {
            public IntPtr hwnd;
            public IntPtr hwndInsertAfter;
            public int x;
            public int y;
            public int cx;
            public int cy;
            public uint flags;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OSVERSIONINFOEX
        {
            public int dwOSVersionInfoSize;
            public int dwMajorVersion;
            public int dwMinorVersion;
            public int dwBuildNumber;
            public int dwPlatformId;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string szCSDVersion;
            public ushort wServicePackMajor;
            public ushort wServicePackMinor;
            public ushort wSuiteMask;
            public byte wProductType;
            public byte wReserved;
        }

        public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd,
            int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr childAfter, string lpClassName, string lpWindowName);
        [DllImport("user32.dll")]
        public static extern IntPtr GetShellWindow();
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetParent(IntPtr hWnd);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongW", SetLastError = true)]
        private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW", SetLastError = true)]
        private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongW", SetLastError = true)]
        private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
        private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

        public static int GetWindowLongInt(IntPtr hWnd, int index)
        {
            if (IntPtr.Size == 8) return unchecked((int)GetWindowLongPtr64(hWnd, index).ToInt64());
            return GetWindowLong32(hWnd, index);
        }

        public static void SetWindowLongInt(IntPtr hWnd, int index, int value)
        {
            if (IntPtr.Size == 8) SetWindowLongPtr64(hWnd, index, new IntPtr(value));
            else SetWindowLong32(hWnd, index, value);
        }

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll", SetLastError = true)]
        public static extern int MapWindowPoints(IntPtr hWndFrom, IntPtr hWndTo, ref POINT pt, uint cPoints);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool ScreenToClient(IntPtr hWnd, ref POINT pt);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetCursorPos(out POINT pt);
        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, byte bAlpha, uint dwFlags);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SystemParametersInfo(int uiAction, int uiParam, ref RECT pvParam, int fWinIni);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern uint RegisterWindowMessage(string lpString);

        [DllImport("user32.dll")]
        public static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr hmodWinEventProc,
            WinEventDelegate lpfnWinEventProc, uint idProcess, uint idThread, uint dwFlags);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool UnhookWinEvent(IntPtr hWinEventHook);

        // ---- DPI (each wrapped in try/catch by callers: EntryPointNotFound on older builds)
        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")]
        public static extern IntPtr GetThreadDpiAwarenessContext();
        [DllImport("user32.dll")]
        public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr hwnd);
        [DllImport("user32.dll")]
        public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr value);
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool AreDpiAwarenessContextsEqual(IntPtr a, IntPtr b);
        [DllImport("user32.dll")]
        public static extern uint GetDpiForSystem();
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetProcessDPIAware();
        [DllImport("shcore.dll")]
        public static extern int SetProcessDpiAwareness(int value);
        [DllImport("shcore.dll")]
        public static extern int GetDpiForMonitor(IntPtr hmonitor, int dpiType, out uint dpiX, out uint dpiY);
        [DllImport("user32.dll")]
        public static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);
        [DllImport("user32.dll")]
        public static extern IntPtr GetDC(IntPtr hWnd);
        [DllImport("user32.dll")]
        public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
        [DllImport("gdi32.dll")]
        public static extern int GetDeviceCaps(IntPtr hdc, int index);

        [DllImport("dwmapi.dll")]
        public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out int value, int size);
        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetVersionEx(ref OSVERSIONINFOEX info);
        [DllImport("ntdll.dll", CharSet = CharSet.Unicode)]
        public static extern int RtlGetVersion(ref OSVERSIONINFOEX info);
    }

    // -----------------------------------------------------------------
    //  Static helpers usable from PowerShell:  [TaskbarKedileri.DesktopHost]::...
    // -----------------------------------------------------------------
    public static class DesktopHost
    {
        private static bool _dpiDone;
        private static string _dpiResult = "not-initialised";

        /// <summary>Result of InitDpi (for the log).</summary>
        public static string DpiResult { get { return _dpiResult; } }

        /// <summary>
        /// Make this process/thread Per-Monitor-V2 DPI aware BEFORE any window
        /// or WorkingArea query: real pixels (no DWM bitmap stretching, so pixel
        /// art stays crisp) and the same awareness as explorer.exe, which is
        /// required for a cross-process parent/child relationship.
        /// Idempotent; safe to call repeatedly.
        /// </summary>
        public static string InitDpi()
        {
            if (_dpiDone) return _dpiResult;
            _dpiDone = true;
            try
            {
                if (Native.SetProcessDpiAwarenessContext(Native.DPI_CTX_PER_MONITOR_V2))
                {
                    _dpiResult = "process:PerMonitorV2";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            try
            {
                if (Native.AreDpiAwarenessContextsEqual(Native.GetThreadDpiAwarenessContext(), Native.DPI_CTX_PER_MONITOR_V2))
                {
                    _dpiResult = "already:PerMonitorV2";
                    return _dpiResult;
                }
                IntPtr old = Native.SetThreadDpiAwarenessContext(Native.DPI_CTX_PER_MONITOR_V2);
                if (old != IntPtr.Zero)
                {
                    _dpiResult = "thread:PerMonitorV2";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            try
            {
                if (Native.SetProcessDpiAwareness(2) == 0)
                {
                    _dpiResult = "process:PerMonitorV1(shcore)";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            try
            {
                if (Native.SetProcessDPIAware())
                {
                    _dpiResult = "process:SystemAware";
                    return _dpiResult;
                }
            }
            catch (Exception) { }
            _dpiResult = "unaware(DWM will bitmap-stretch)";
            return _dpiResult;
        }

        /// <summary>Effective DPI of the primary monitor, as seen by this thread.</summary>
        public static int GetPrimaryDpi()
        {
            try
            {
                IntPtr mon = Native.MonitorFromPoint(new Native.POINT(0, 0), Native.MONITOR_DEFAULTTOPRIMARY);
                uint dx, dy;
                if (mon != IntPtr.Zero && Native.GetDpiForMonitor(mon, 0, out dx, out dy) == 0 && dx > 0) return (int)dx;
            }
            catch (Exception) { }
            try
            {
                uint d = Native.GetDpiForSystem();
                if (d > 0) return (int)d;
            }
            catch (Exception) { }
            IntPtr hdc = Native.GetDC(IntPtr.Zero);
            try
            {
                int v = Native.GetDeviceCaps(hdc, Native.LOGPIXELSX);
                return v > 0 ? v : 96;
            }
            finally { Native.ReleaseDC(IntPtr.Zero, hdc); }
        }

        /// <summary>Integer pixel multiplier for crisp pixel art: 100-125% -> 1, 150-225% -> 2, ...</summary>
        public static int GetPixelScale()
        {
            int s = (int)Math.Floor(GetPrimaryDpi() / 96.0 + 0.5);
            return s < 1 ? 1 : s;
        }

        /// <summary>Primary monitor work area in this thread's DPI units (physical px when PMv2).</summary>
        public static Rectangle GetWorkArea()
        {
            Native.RECT r = new Native.RECT();
            if (Native.SystemParametersInfo(Native.SPI_GETWORKAREA, 0, ref r, 0) && r.Right > r.Left && r.Bottom > r.Top)
                return Rectangle.FromLTRB(r.Left, r.Top, r.Right, r.Bottom);
            return Screen.PrimaryScreen.WorkingArea;
        }

        public static string GetClass(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero) return "";
            StringBuilder sb = new StringBuilder(256);
            Native.GetClassName(hwnd, sb, sb.Capacity);
            return sb.ToString();
        }

        public static bool ClassIs(IntPtr hwnd, string cls)
        {
            return string.Equals(GetClass(hwnd), cls, StringComparison.OrdinalIgnoreCase);
        }

        public static bool IsCloaked(IntPtr hwnd)
        {
            try
            {
                int v;
                return Native.DwmGetWindowAttribute(hwnd, Native.DWMWA_CLOAKED, out v, 4) == 0 && v != 0;
            }
            catch (Exception) { return false; }
        }

        /// <summary>
        /// Top-level window that currently hosts SHELLDLL_DefView (the desktop icons):
        ///   Progman with WS_EX_NOREDIRECTIONBITMAP -> Windows 11 24H2+ "raised desktop"
        ///   Progman                                -> plain Win10 / Win11 desktop
        ///   WorkerW                                -> older tree after 0x052C / slideshow
        /// Returns IntPtr.Zero when Explorer is not running (yet).
        /// </summary>
        public static IntPtr FindIconHost(out string layout)
        {
            layout = "none";
            IntPtr shell = Native.GetShellWindow();
            uint shellPid = 0;
            if (shell != IntPtr.Zero) Native.GetWindowThreadProcessId(shell, out shellPid);

            IntPtr progman = Native.FindWindow("Progman", null);
            if (progman != IntPtr.Zero && Native.FindWindowEx(progman, IntPtr.Zero, "SHELLDLL_DefView", null) != IntPtr.Zero)
            {
                int ex = Native.GetWindowLongInt(progman, Native.GWL_EXSTYLE);
                layout = (ex & Native.WS_EX_NOREDIRECTIONBITMAP) != 0 ? "Progman/raised(24H2+)" : "Progman/classic";
                return progman;
            }
            IntPtr w = IntPtr.Zero;
            for (int guard = 0; guard < 256; guard++)
            {
                w = Native.FindWindowEx(IntPtr.Zero, w, "WorkerW", null);
                if (w == IntPtr.Zero) break;
                if (Native.FindWindowEx(w, IntPtr.Zero, "SHELLDLL_DefView", null) == IntPtr.Zero) continue;
                if (shellPid != 0)
                {
                    uint pid;
                    Native.GetWindowThreadProcessId(w, out pid);
                    if (pid != shellPid) continue;
                }
                layout = "WorkerW/classic";
                return w;
            }
            return IntPtr.Zero;
        }

        /// <summary>null when our thread and the host window have the same DPI awareness, else the reason.</summary>
        public static string CheckDpiCompat(IntPtr host)
        {
            try
            {
                int ha = Native.GetAwarenessFromDpiAwarenessContext(Native.GetWindowDpiAwarenessContext(host));
                int ta = Native.GetAwarenessFromDpiAwarenessContext(Native.GetThreadDpiAwarenessContext());
                if (ha < 0 || ta < 0) return null; // unknown -> let creation/verification decide
                if (ha != ta)
                    return string.Format("DPI awareness mismatch (explorer={0}, widget={1})", AwarenessName(ha), AwarenessName(ta));
            }
            catch (Exception) { }
            return null;
        }

        public static string ThreadAwareness()
        {
            try
            {
                IntPtr ctx = Native.GetThreadDpiAwarenessContext();
                if (Native.AreDpiAwarenessContextsEqual(ctx, Native.DPI_CTX_PER_MONITOR_V2)) return "PerMonitorV2";
                return AwarenessName(Native.GetAwarenessFromDpiAwarenessContext(ctx));
            }
            catch (Exception) { return "n/a"; }
        }

        private static string AwarenessName(int a)
        {
            if (a == 0) return "Unaware";
            if (a == 1) return "System";
            if (a == 2) return "PerMonitor";
            return "Invalid";
        }

        /// <summary>Real OS version (RtlGetVersion).</summary>
        public static string OsVersion
        {
            get
            {
                try
                {
                    Native.OSVERSIONINFOEX v = new Native.OSVERSIONINFOEX();
                    v.dwOSVersionInfoSize = Marshal.SizeOf(typeof(Native.OSVERSIONINFOEX));
                    if (Native.RtlGetVersion(ref v) == 0)
                        return string.Format("{0}.{1}.{2}", v.dwMajorVersion, v.dwMinorVersion, v.dwBuildNumber);
                }
                catch (Exception) { }
                return Environment.OSVersion.Version.ToString();
            }
        }

        /// <summary>
        /// Version as reported by GetVersionEx, which is capped by the host EXE's
        /// manifest (supportedOS).  "10.0.x" => powershell.exe declares Windows 10
        /// compatibility, which also satisfies the Win8+ requirement for layered
        /// CHILD windows.  "6.2.x" => not manifested for 8.1+.
        /// </summary>
        public static string ManifestOsVersion
        {
            get
            {
                try
                {
                    Native.OSVERSIONINFOEX v = new Native.OSVERSIONINFOEX();
                    v.dwOSVersionInfoSize = Marshal.SizeOf(typeof(Native.OSVERSIONINFOEX));
                    if (Native.GetVersionEx(ref v))
                        return string.Format("{0}.{1}.{2}", v.dwMajorVersion, v.dwMinorVersion, v.dwBuildNumber);
                }
                catch (Exception) { }
                return "n/a";
            }
        }

        /// <summary>One line describing the desktop window tree (for catbar-hata.log).</summary>
        public static string Describe()
        {
            StringBuilder sb = new StringBuilder();
            string layout;
            IntPtr host = FindIconHost(out layout);
            sb.AppendFormat("os={0} exeManifestOs={1} dpiInit={2} thread={3} primaryDpi={4} workArea={5} host=0x{6:X}({7}) layout={8}",
                OsVersion, ManifestOsVersion, _dpiResult, ThreadAwareness(), GetPrimaryDpi(), GetWorkArea(),
                host.ToInt64(), GetClass(host), layout);
            if (host != IntPtr.Zero)
            {
                sb.Append(" children=[");
                IntPtr c = Native.GetWindow(host, Native.GW_CHILD);
                for (int i = 0; c != IntPtr.Zero && i < 16; i++)
                {
                    if (i > 0) sb.Append(", ");
                    sb.AppendFormat("{0}{1}", GetClass(c),
                        (Native.GetWindowLongInt(c, Native.GWL_EXSTYLE) & Native.WS_EX_LAYERED) != 0 ? "(layered)" : "");
                    c = Native.GetWindow(c, Native.GW_HWNDNEXT);
                }
                sb.Append("]");
            }
            return sb.ToString();
        }
    }

    // -----------------------------------------------------------------
    //  Hidden top-level window: receives the broadcasts a WS_CHILD never
    //  gets (WM_SETTINGCHANGE / WM_DISPLAYCHANGE / "TaskbarCreated") and is
    //  the foreground anchor while the context menu is open.
    // -----------------------------------------------------------------
    internal sealed class SinkWindow : NativeWindow
    {
        private readonly DesktopForm _owner;
        private readonly int _taskbarCreated;

        public SinkWindow(DesktopForm owner)
        {
            _owner = owner;
            _taskbarCreated = (int)Native.RegisterWindowMessage("TaskbarCreated");
            CreateParams cp = new CreateParams();
            cp.Caption = "TaskbarKedileriSink";
            cp.Style = Native.WS_POPUP;
            cp.ExStyle = Native.WS_EX_TOOLWINDOW;
            cp.X = 0; cp.Y = 0; cp.Width = 0; cp.Height = 0;
            CreateHandle(cp);
        }

        protected override void WndProc(ref Message m)
        {
            try
            {
                if (m.Msg == Native.WM_SETTINGCHANGE || m.Msg == Native.WM_DISPLAYCHANGE || m.Msg == Native.WM_DPICHANGED)
                    _owner.NotifySystemChange();
                else if (_taskbarCreated != 0 && m.Msg == _taskbarCreated)
                    _owner.NotifyExplorerRestarted();
            }
            catch (Exception) { }
            base.WndProc(ref m);
        }
    }

    // -----------------------------------------------------------------
    //  The widget form.  Use instead of System.Windows.Forms.Form:
    //     $form = New-Object TaskbarKedileri.DesktopForm
    //  Bounds/Location stay in SCREEN coordinates in every mode.
    // -----------------------------------------------------------------
    public class DesktopForm : Form
    {
        private const int ActiveNone = 0;
        private const int ActiveDesktop = 1;
        private const int ActiveBottom = 2;
        private const int WatchIntervalMs = 250;
        private const int HitIntervalMs = 30;
        private const int HostLostGiveUpMs = 15000;
        private const int BottomRetryDesktopMs = 4000;
        private const int MaxLogChars = 16000;

        private DesktopModeRequest _requested = DesktopModeRequest.Auto;
        private int _active = ActiveNone;
        private string _mode = "None";
        private string _modeDetail = "";
        private IntPtr _host = IntPtr.Zero;      // Desktop mode: our parent
        private string _layout = "";
        private bool _wantChild;                 // decided right before CreateHandle
        private string _desktopBlocked;          // hard failure -> stay in Bottom
        private bool _hostLost;
        private int _hostLostSince;
        private int _parentRepairs;
        private int _bottomSince;
        private bool _allowZ;
        private bool _selfDestroy;
        private bool _closing;
        private bool _hitTestByMask = true;
        private bool _clickThrough = true;
        private int _hitSlop = 2;
        private Rectangle _desiredBounds = Rectangle.Empty;   // screen coordinates
        private Bitmap _buffer;
        private readonly System.Windows.Forms.Timer _watch;
        private readonly System.Windows.Forms.Timer _hit;
        private SinkWindow _sink;
        private readonly Native.WinEventDelegate _winEventProc;   // kept alive (GC!)
        private IntPtr _hookFg = IntPtr.Zero;
        private IntPtr _hookMin = IntPtr.Zero;
        private int _zBurstUntil;
        private int _zFixes;
        private int _zFixWindowStart;
        private Rectangle _lastWorkArea = Rectangle.Empty;
        private int _lastDpi;
        private IntPtr _prevForeground = IntPtr.Zero;
        private ContextMenuStrip _hookedMenu;
        private readonly StringBuilder _log = new StringBuilder();

        public event EventHandler WorkAreaChanged;
        public event EventHandler ModeChanged;
        public event EventHandler<DesktopLogEventArgs> LogMessage;

        static DesktopForm()
        {
            DesktopHost.InitDpi();
        }

        public DesktopForm()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            AutoScaleMode = AutoScaleMode.None;
            Text = "Taskbar Kedileri";
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);

            _winEventProc = new Native.WinEventDelegate(OnWinEvent);
            _watch = new System.Windows.Forms.Timer();
            _watch.Interval = WatchIntervalMs;
            _watch.Tick += OnWatchTick;
            _hit = new System.Windows.Forms.Timer();
            _hit.Interval = HitIntervalMs;
            _hit.Tick += OnHitTick;
        }

        // ============================================================ public API

        /// <summary>Auto (default) / Desktop / Bottom. Changing it at runtime re-creates the window.</summary>
        [Browsable(false)]
        public DesktopModeRequest RequestedMode
        {
            get { return _requested; }
            set
            {
                bool unblocked = false;
                if (value == DesktopModeRequest.Desktop && _desktopBlocked != null)
                {
                    _desktopBlocked = null;   // explicit user override: try again
                    unblocked = true;
                }
                if (_requested == value && !unblocked) return;
                _requested = value;
                Log("requested mode -> " + value);
                if (IsHandleCreated) BeginInvoke(new MethodInvoker(SafeRecreate));
            }
        }

        /// <summary>Active mode: "Desktop", "Bottom" or "None" (no window right now).</summary>
        public string Mode { get { return _mode; } }

        /// <summary>Host window, layout, DPI, OS and manifest details of the active mode.</summary>
        public string ModeDetail { get { return _modeDetail; } }

        /// <summary>Why Desktop mode was abandoned for this session (null if it was not).</summary>
        public string DesktopFailure { get { return _desktopBlocked; } }

        /// <summary>Accumulated diagnostic log (also raised line by line via LogMessage).</summary>
        public string Diagnostics { get { return _log.ToString(); } }

        /// <summary>Toggle WS_EX_TRANSPARENT from the back buffer so key-colour pixels never catch clicks.</summary>
        public bool HitTestByMask
        {
            get { return _hitTestByMask; }
            set { _hitTestByMask = value; if (IsHandleCreated) UpdateClickThrough(true); }
        }

        /// <summary>Extra pixels around opaque pixels that still count as a hit (default 2).</summary>
        public int HitSlop
        {
            get { return _hitSlop; }
            set { _hitSlop = value < 0 ? 0 : value; }
        }

        public int Dpi { get { return DesktopHost.GetPrimaryDpi(); } }
        public int PixelScale { get { return DesktopHost.GetPixelScale(); } }
        public IntPtr HostWindow { get { return _host; } }

        /// <summary>Re-run host discovery and re-create the window (keeps state).</summary>
        public void Reattach()
        {
            if (_requested != DesktopModeRequest.Bottom) _desktopBlocked = null;
            if (IsHandleCreated) BeginInvoke(new MethodInvoker(SafeRecreate));
        }

        /// <summary>True when the last painted frame has a non-key pixel at client (x, y) (+/- HitSlop).</summary>
        public bool IsOpaqueAt(int x, int y)
        {
            Bitmap b = _buffer;
            if (b == null) return false;
            Color key = TransparencyKey;
            if (key.IsEmpty) return x >= 0 && y >= 0 && x < b.Width && y < b.Height;
            int k = key.ToArgb();
            int s = _hitSlop;
            if (PixelOpaque(b, x, y, k)) return true;
            if (s <= 0) return false;
            return PixelOpaque(b, x - s, y, k) || PixelOpaque(b, x + s, y, k)
                || PixelOpaque(b, x, y - s, k) || PixelOpaque(b, x, y + s, k);
        }

        private static bool PixelOpaque(Bitmap b, int x, int y, int keyArgb)
        {
            if (x < 0 || y < 0 || x >= b.Width || y >= b.Height) return false;
            return b.GetPixel(x, y).ToArgb() != keyArgb;
        }

        // ============================================================ window creation

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle &= ~(Native.WS_EX_TOPMOST | Native.WS_EX_APPWINDOW);
                cp.ExStyle |= Native.WS_EX_LAYERED | Native.WS_EX_NOACTIVATE;
                if (_hitTestByMask && _clickThrough) cp.ExStyle |= Native.WS_EX_TRANSPARENT;
                else cp.ExStyle &= ~Native.WS_EX_TRANSPARENT;

                if (_wantChild && _host != IntPtr.Zero)
                {
                    cp.Parent = _host;
                    cp.Style &= ~(Native.WS_POPUP | Native.WS_CAPTION | Native.WS_THICKFRAME | Native.WS_SYSMENU
                                  | Native.WS_MINIMIZEBOX | Native.WS_MAXIMIZEBOX);
                    cp.Style |= Native.WS_CHILD | Native.WS_CLIPSIBLINGS;
                    cp.ExStyle &= ~Native.WS_EX_TOOLWINDOW;
                    Rectangle r = _desiredBounds.IsEmpty ? new Rectangle(cp.X, cp.Y, cp.Width, cp.Height) : _desiredBounds;
                    Native.POINT p = new Native.POINT(r.X, r.Y);
                    Native.MapWindowPoints(IntPtr.Zero, _host, ref p, 1);   // screen -> host client
                    cp.X = p.X; cp.Y = p.Y; cp.Width = r.Width; cp.Height = r.Height;
                }
                else
                {
                    // Unowned popup: WinForms would make it owned by a hidden "taskbar owner"
                    // window (ShowInTaskbar=false), which complicates z-order handling.
                    cp.Parent = IntPtr.Zero;
                    cp.Style = (cp.Style & ~Native.WS_CHILD) | Native.WS_POPUP;
                    cp.ExStyle |= Native.WS_EX_TOOLWINDOW;
                }
                return cp;
            }
        }

        protected override void CreateHandle()
        {
            if (_closing) { base.CreateHandle(); return; }
            DecideMode();
            if (_wantChild)
            {
                try
                {
                    base.CreateHandle();
                    return;
                }
                catch (Exception ex)
                {
                    BlockDesktop("CreateWindowEx(WS_CHILD of " + _layout + ") failed: " + ex.Message);
                    _wantChild = false;
                    _host = IntPtr.Zero;
                }
            }
            base.CreateHandle();
        }

        private void DecideMode()
        {
            _wantChild = false;
            _host = IntPtr.Zero;
            _layout = "";
            if (_requested == DesktopModeRequest.Bottom) return;
            if (_desktopBlocked != null) return;
            string layout;
            IntPtr host = DesktopHost.FindIconHost(out layout);
            if (host == IntPtr.Zero)
            {
                Log("no SHELLDLL_DefView host found (Explorer not ready?) -> Bottom for now");
                return;
            }
            string why = DesktopHost.CheckDpiCompat(host);
            if (why != null) { BlockDesktop(why); return; }
            _host = host;
            _layout = layout;
            _wantChild = true;
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            bool layeredOk = ApplyLayered();

            if (_wantChild)
            {
                string fail = null;
                int ex = Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE);
                if (Native.GetParent(Handle) != _host) fail = "window did not become a child of " + _layout;
                else if ((ex & Native.WS_EX_LAYERED) == 0) fail = "WS_EX_LAYERED was dropped on the child (layered child windows need a Win8+ manifest)";
                else if (!layeredOk) fail = "SetLayeredWindowAttributes failed on the child";

                if (fail != null)
                {
                    BlockDesktop(fail);
                    _wantChild = false;
                    _active = ActiveNone;
                    BeginInvoke(new MethodInvoker(SafeRecreate));
                }
                else
                {
                    _active = ActiveDesktop;
                    _parentRepairs = 0;
                    UnhookEvents();
                    RaiseInHost();
                    SetMode("Desktop", BuildDetail());
                    // OnHandleCreated runs inside WM_CREATE; Form.CreateHandle still has code to
                    // run after it, so verify the parent again once creation has fully finished.
                    BeginInvoke(new MethodInvoker(VerifyParent));
                }
            }
            else
            {
                _active = ActiveBottom;
                _bottomSince = Environment.TickCount;
                HookEvents();
                ExcludeFromPeek();
                EnsureAboveDesktop(true);
                SetMode("Bottom", BuildDetail());
            }

            if (_sink == null)
            {
                try { _sink = new SinkWindow(this); }
                catch (Exception ex2) { Log("sink window failed: " + ex2.Message); }
            }
            if (_lastWorkArea.IsEmpty)
            {
                _lastWorkArea = DesktopHost.GetWorkArea();
                _lastDpi = DesktopHost.GetPrimaryDpi();
            }
            _watch.Start();
            _hit.Start();
            UpdateClickThrough(true);
        }

        private bool ApplyLayered()
        {
            int ex = Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE);
            if ((ex & Native.WS_EX_LAYERED) == 0) Native.SetWindowLongInt(Handle, Native.GWL_EXSTYLE, ex | Native.WS_EX_LAYERED);
            uint flags = Native.LWA_ALPHA;
            uint key = 0;
            Color k = TransparencyKey;
            if (!k.IsEmpty)
            {
                flags |= Native.LWA_COLORKEY;
                key = (uint)(k.R | (k.G << 8) | (k.B << 16));
            }
            double op = Opacity;
            byte alpha = (byte)Math.Max(0, Math.Min(255, (int)Math.Round(op * 255.0)));
            bool ok = Native.SetLayeredWindowAttributes(Handle, key, alpha, flags);
            if (!ok) Log("SetLayeredWindowAttributes failed, win32 error " + Marshal.GetLastWin32Error());
            return ok;
        }

        protected override void DestroyHandle()
        {
            _selfDestroy = true;
            try { base.DestroyHandle(); }
            finally { _selfDestroy = false; }
        }

        private void SafeRecreate()
        {
            try
            {
                if (_closing || IsDisposed) return;
                if (IsHandleCreated) RecreateHandle();
                else { CreateControl(); if (!IsHandleCreated) CreateHandle(); }
                ScheduleWorkAreaCheck(true);
            }
            catch (Exception ex) { Log("recreate failed: " + ex.Message); }
        }

        private void BlockDesktop(string reason)
        {
            _desktopBlocked = reason;
            Log("Desktop mode unavailable: " + reason + " -> Bottom");
        }

        private string BuildDetail()
        {
            return string.Format("host=0x{0:X}({1}) layout={2} dpi={3} pixelScale={4} dpiInit={5} os={6} exeManifestOs={7}{8}",
                _host.ToInt64(), DesktopHost.GetClass(_host), _layout == "" ? "-" : _layout,
                DesktopHost.GetPrimaryDpi(), DesktopHost.GetPixelScale(), DesktopHost.DpiResult,
                DesktopHost.OsVersion, DesktopHost.ManifestOsVersion,
                _desktopBlocked == null ? "" : " fallbackReason=\"" + _desktopBlocked + "\"");
        }

        private void SetMode(string mode, string detail)
        {
            bool changed = mode != _mode || detail != _modeDetail;
            _mode = mode;
            _modeDetail = detail;
            if (!changed) return;
            AppendLog("mode=" + mode + " " + detail);
            EventHandler h = ModeChanged;
            if (h != null)
            {
                try { h(this, EventArgs.Empty); }
                catch (Exception ex) { AppendLog("ModeChanged handler: " + ex.Message); }
            }
        }

        // ============================================================ bounds (screen coordinates)

        protected override void SetBoundsCore(int x, int y, int width, int height, BoundsSpecified specified)
        {
            _desiredBounds = new Rectangle(x, y, width, height);
            if (IsHandleCreated && _active == ActiveDesktop && _host != IntPtr.Zero)
            {
                MoveChild();
                return;
            }
            base.SetBoundsCore(x, y, width, height, specified);
        }

        private void MoveChild()
        {
            Rectangle r = _desiredBounds.IsEmpty ? Bounds : _desiredBounds;
            Native.POINT p = new Native.POINT(r.X, r.Y);
            Native.MapWindowPoints(IntPtr.Zero, _host, ref p, 1);
            Native.SetWindowPos(Handle, IntPtr.Zero, p.X, p.Y, r.Width, r.Height, Native.SWP_NOZORDER | Native.SWP_NOACTIVATE);
            // WM_WINDOWPOSCHANGED -> WinForms reads GetWindowRect (screen) because the
            // form is still TopLevel for WinForms, so Bounds stays in screen coordinates.
        }

        // ============================================================ messages

        protected override void WndProc(ref Message m)
        {
            switch (m.Msg)
            {
                case Native.WM_MOUSEACTIVATE:
                    m.Result = new IntPtr(Native.MA_NOACTIVATE);   // clicks never activate / raise us
                    return;

                case Native.WM_WINDOWPOSCHANGING:
                    if (_active == ActiveBottom && !_allowZ && m.LParam != IntPtr.Zero)
                    {
                        Native.WINDOWPOS wp = (Native.WINDOWPOS)Marshal.PtrToStructure(m.LParam, typeof(Native.WINDOWPOS));
                        if ((wp.flags & Native.SWP_NOZORDER) == 0)
                        {
                            wp.flags |= Native.SWP_NOZORDER;           // only our own code moves us in z
                            Marshal.StructureToPtr(wp, m.LParam, false);
                        }
                    }
                    break;

                case Native.WM_CONTEXTMENU:
                    PrepareMenuForeground();
                    break;

                case Native.WM_DPICHANGED:
                case Native.WM_DPICHANGED_AFTERPARENT:
                    base.WndProc(ref m);
                    ScheduleWorkAreaCheck(true);
                    return;

                case Native.WM_SETTINGCHANGE:
                case Native.WM_DISPLAYCHANGE:
                    base.WndProc(ref m);
                    ScheduleWorkAreaCheck(false);
                    return;

                case Native.WM_DESTROY:
                    if (!_selfDestroy && !_closing && !RecreatingHandle && _active == ActiveDesktop)
                    {
                        // Explorer died: the system destroys its windows' children, us included.
                        _hostLost = true;
                        _hostLostSince = Environment.TickCount;
                        _active = ActiveNone;
                        _host = IntPtr.Zero;
                        SetMode("None", "desktop host destroyed (Explorer restart?) - waiting to re-attach");
                    }
                    break;
            }
            base.WndProc(ref m);
        }

        // ============================================================ painting + mask

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            // everything (including the key colour) is painted in OnPaint
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Size cs = ClientSize;
            if (cs.Width <= 0 || cs.Height <= 0) { base.OnPaint(e); return; }
            if (_buffer == null || _buffer.Width != cs.Width || _buffer.Height != cs.Height)
            {
                if (_buffer != null) _buffer.Dispose();
                _buffer = new Bitmap(cs.Width, cs.Height, PixelFormat.Format32bppArgb);
            }
            Color bg = TransparencyKey.IsEmpty ? BackColor : TransparencyKey;
            using (Graphics g = Graphics.FromImage(_buffer))
            {
                g.Clear(bg);
                base.OnPaint(new PaintEventArgs(g, new Rectangle(0, 0, cs.Width, cs.Height)));  // script's Paint handler
            }
            Graphics sg = e.Graphics;
            sg.CompositingMode = CompositingMode.SourceCopy;
            sg.InterpolationMode = InterpolationMode.NearestNeighbor;
            sg.PixelOffsetMode = PixelOffsetMode.Half;
            sg.DrawImage(_buffer, new Rectangle(0, 0, cs.Width, cs.Height), 0, 0, cs.Width, cs.Height, GraphicsUnit.Pixel);
        }

        private void UpdateClickThrough(bool force)
        {
            if (!IsHandleCreated) return;
            if (!_hitTestByMask) { SetClickThrough(false, force); return; }
            if (!force)
            {
                if ((Native.GetAsyncKeyState(Native.VK_LBUTTON) & 0x8000) != 0) return;
                if ((Native.GetAsyncKeyState(Native.VK_RBUTTON) & 0x8000) != 0) return;
                ContextMenuStrip cms = ContextMenuStrip;
                if (cms != null && cms.Visible) return;
            }
            bool opaque = false;
            Native.POINT p;
            Native.RECT r;
            if (Native.GetCursorPos(out p) && Native.GetWindowRect(Handle, out r)
                && p.X >= r.Left && p.X < r.Right && p.Y >= r.Top && p.Y < r.Bottom)
            {
                Native.ScreenToClient(Handle, ref p);
                opaque = IsOpaqueAt(p.X, p.Y);
            }
            SetClickThrough(!opaque, force);
        }

        private void SetClickThrough(bool on, bool force)
        {
            if (!force && on == _clickThrough) return;
            _clickThrough = on;
            int ex = Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE);
            int nex = on ? (ex | Native.WS_EX_TRANSPARENT) : (ex & ~Native.WS_EX_TRANSPARENT);
            if (nex != ex) Native.SetWindowLongInt(Handle, Native.GWL_EXSTYLE, nex);
        }

        // ============================================================ context menu foreground

        private void PrepareMenuForeground()
        {
            // Like NotifyIcon: make one of OUR top-level windows foreground so the
            // ContextMenuStrip closes when the user clicks anywhere else.  Allowed
            // because our thread just received the input event (the right click).
            try
            {
                _prevForeground = Native.GetForegroundWindow();
                if (_sink != null && _sink.Handle != IntPtr.Zero) Native.SetForegroundWindow(_sink.Handle);
            }
            catch (Exception) { }
        }

        protected override void OnContextMenuStripChanged(EventArgs e)
        {
            if (_hookedMenu != null) _hookedMenu.Closed -= OnMenuClosed;
            _hookedMenu = ContextMenuStrip;
            if (_hookedMenu != null) _hookedMenu.Closed += OnMenuClosed;
            base.OnContextMenuStripChanged(e);
        }

        private void OnMenuClosed(object sender, ToolStripDropDownClosedEventArgs e)
        {
            try
            {
                if (_sink != null && Native.GetForegroundWindow() == _sink.Handle
                    && _prevForeground != IntPtr.Zero && Native.IsWindow(_prevForeground))
                    Native.SetForegroundWindow(_prevForeground);
            }
            catch (Exception) { }
            _prevForeground = IntPtr.Zero;
        }

        // ============================================================ Desktop mode upkeep

        private void RaiseInHost()
        {
            Native.SetWindowPos(Handle, Native.HWND_TOP, 0, 0, 0, 0,
                Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE);
        }

        private void VerifyParent()
        {
            try
            {
                if (_closing || !IsHandleCreated || _active != ActiveDesktop) return;
                if (Native.IsWindow(_host) && Native.GetParent(Handle) != _host) RepairParent();
            }
            catch (Exception ex) { Log("verify parent: " + ex.Message); }
        }

        /// <summary>Something (WinForms owner logic, a shell quirk) changed our parent: put it back.</summary>
        private void RepairParent()
        {
            _parentRepairs++;
            if (_parentRepairs > 3)
            {
                BlockDesktop("parent keeps changing (repaired 3 times)");
                SafeRecreate();
                return;
            }
            Log("parent changed to 0x" + Native.GetParent(Handle).ToInt64().ToString("X") + " -> SetParent back to host");
            Native.SetParent(Handle, _host);
            if (Native.GetParent(Handle) != _host)
            {
                BlockDesktop("SetParent back to the desktop host failed, win32 error " + Marshal.GetLastWin32Error());
                SafeRecreate();
                return;
            }
            ApplyLayered();
            MoveChild();
            RaiseInHost();
        }

        private void WatchDesktop()
        {
            if (!Native.IsWindow(_host))
            {
                Log("desktop host vanished -> re-attach");
                SafeRecreate();
                return;
            }
            if (Native.GetParent(Handle) != _host)
            {
                RepairParent();
                return;
            }
            string layout;
            IntPtr cur = DesktopHost.FindIconHost(out layout);
            if (cur != IntPtr.Zero && cur != _host)
            {
                Reparent(cur, layout);
                return;
            }
            // stay above SHELLDLL_DefView (only fight the icon view, not other widgets)
            IntPtr w = Native.GetWindow(Handle, Native.GW_HWNDPREV);
            for (int i = 0; w != IntPtr.Zero && i < 64; i++)
            {
                if (DesktopHost.ClassIs(w, "SHELLDLL_DefView")) { RaiseInHost(); break; }
                w = Native.GetWindow(w, Native.GW_HWNDPREV);
            }
        }

        private void Reparent(IntPtr newHost, string layout)
        {
            string why = DesktopHost.CheckDpiCompat(newHost);
            if (why != null) { BlockDesktop(why); SafeRecreate(); return; }
            Log("SHELLDLL_DefView moved to 0x" + newHost.ToInt64().ToString("X") + " (" + layout + ") -> SetParent");
            Native.SetParent(Handle, newHost);
            int err = Marshal.GetLastWin32Error();
            if (Native.GetParent(Handle) != newHost)
            {
                BlockDesktop("SetParent to the new desktop host failed, win32 error " + err);
                SafeRecreate();
                return;
            }
            _host = newHost;
            _layout = layout;
            _parentRepairs = 0;
            ApplyLayered();
            MoveChild();
            RaiseInHost();
            SetMode("Desktop", BuildDetail());
        }

        // ============================================================ Bottom mode upkeep

        private void HookEvents()
        {
            try
            {
                if (_hookFg == IntPtr.Zero)
                    _hookFg = Native.SetWinEventHook(Native.EVENT_SYSTEM_FOREGROUND, Native.EVENT_SYSTEM_FOREGROUND,
                        IntPtr.Zero, _winEventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
                if (_hookMin == IntPtr.Zero)
                    _hookMin = Native.SetWinEventHook(Native.EVENT_SYSTEM_MINIMIZESTART, Native.EVENT_SYSTEM_MINIMIZEEND,
                        IntPtr.Zero, _winEventProc, 0, 0, Native.WINEVENT_OUTOFCONTEXT);
            }
            catch (Exception ex) { Log("SetWinEventHook failed: " + ex.Message); }
        }

        private void UnhookEvents()
        {
            if (_hookFg != IntPtr.Zero) { Native.UnhookWinEvent(_hookFg); _hookFg = IntPtr.Zero; }
            if (_hookMin != IntPtr.Zero) { Native.UnhookWinEvent(_hookMin); _hookMin = IntPtr.Zero; }
        }

        private void OnWinEvent(IntPtr hook, uint evt, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
        {
            try
            {
                if (_active != ActiveBottom || !IsHandleCreated) return;
                EnsureAboveDesktop(false);
                _zBurstUntil = unchecked(Environment.TickCount + 800);  // Show Desktop settles over a few frames
            }
            catch (Exception) { }
        }

        /// <summary>Keep the popup directly above the desktop host, i.e. below every app window.</summary>
        private void EnsureAboveDesktop(bool force)
        {
            if (!IsHandleCreated || _active != ActiveBottom) return;
            string layout;
            IntPtr anchor = DesktopHost.FindIconHost(out layout);
            if (anchor == IntPtr.Zero) anchor = Native.GetShellWindow();

            if ((Native.GetWindowLongInt(Handle, Native.GWL_EXSTYLE) & Native.WS_EX_TOPMOST) != 0)
                ZMove(Native.HWND_NOTOPMOST);

            if (anchor == IntPtr.Zero)
            {
                if (force) ZMove(Native.HWND_BOTTOM);
                return;
            }
            if (!force && IsDirectlyAbove(anchor)) return;
            IntPtr prev = Native.GetWindow(anchor, Native.GW_HWNDPREV);
            if (prev == Handle) return;
            if (!force && !CountZFix()) return;
            // insert-after = window just above the host  =>  we land between it and the host
            ZMove(prev == IntPtr.Zero ? Native.HWND_TOP : prev);
        }

        /// <summary>Aero Peek (hovering the show-desktop corner) hides top-level windows; stay visible.</summary>
        private void ExcludeFromPeek()
        {
            try
            {
                int on = 1;
                Native.DwmSetWindowAttribute(Handle, Native.DWMWA_EXCLUDED_FROM_PEEK, ref on, 4);
            }
            catch (Exception) { }
        }

        private void ZMove(IntPtr insertAfter)
        {
            _allowZ = true;
            try
            {
                Native.SetWindowPos(Handle, insertAfter, 0, 0, 0, 0,
                    Native.SWP_NOMOVE | Native.SWP_NOSIZE | Native.SWP_NOACTIVATE | Native.SWP_NOOWNERZORDER);
            }
            finally { _allowZ = false; }
        }

        /// <summary>Back off if something else keeps fighting for the same z slot.</summary>
        private bool CountZFix()
        {
            int now = Environment.TickCount;
            if (unchecked(now - _zFixWindowStart) > 10000) { _zFixWindowStart = now; _zFixes = 0; }
            _zFixes++;
            if (_zFixes == 40) Log("z-order fight detected (another 'on desktop' window?) - backing off");
            return _zFixes < 40 || (_zFixes % 8) == 0;
        }

        private bool IsDirectlyAbove(IntPtr anchor)
        {
            Native.RECT me;
            if (!Native.GetWindowRect(Handle, out me)) return true;
            IntPtr w = Native.GetWindow(Handle, Native.GW_HWNDNEXT);
            for (int i = 0; w != IntPtr.Zero && i < 4096; i++)
            {
                if (w == anchor) return true;
                if (Native.IsWindowVisible(w) && !DesktopHost.IsCloaked(w))
                {
                    int ex = Native.GetWindowLongInt(w, Native.GWL_EXSTYLE);
                    bool toolLike = (ex & (Native.WS_EX_TOOLWINDOW | Native.WS_EX_NOACTIVATE)) != 0;
                    Native.RECT r;
                    if (!toolLike && Native.GetWindowRect(w, out r)
                        && r.Left < me.Right && r.Right > me.Left && r.Top < me.Bottom && r.Bottom > me.Top)
                        return false;   // an app window is BELOW us -> we would cover it
                }
                w = Native.GetWindow(w, Native.GW_HWNDNEXT);
            }
            return false;   // host is above us (Show Desktop) or not found below
        }

        // ============================================================ timers + notifications

        private void OnHitTick(object sender, EventArgs e)
        {
            try
            {
                if (_closing || !IsHandleCreated) return;
                UpdateClickThrough(false);
                if (_active == ActiveBottom && unchecked(Environment.TickCount - _zBurstUntil) < 0)
                    EnsureAboveDesktop(false);
            }
            catch (Exception ex) { Log("hit timer: " + ex.Message); }
        }

        private void OnWatchTick(object sender, EventArgs e)
        {
            try
            {
                if (_closing) return;
                if (!IsHandleCreated)
                {
                    if (!_hostLost) return;
                    int waited = unchecked(Environment.TickCount - _hostLostSince);
                    string layout;
                    IntPtr h = DesktopHost.FindIconHost(out layout);
                    if ((h != IntPtr.Zero && waited > 1200) || waited > HostLostGiveUpMs)
                    {
                        _hostLost = false;
                        Log(h != IntPtr.Zero ? "Explorer is back -> re-creating the widget" : "Explorer still missing -> re-creating as Bottom");
                        CreateControl();
                        if (!IsHandleCreated) CreateHandle();
                        if (IsHandleCreated && !Native.IsWindowVisible(Handle)) Native.ShowWindow(Handle, Native.SW_SHOWNOACTIVATE);
                        ScheduleWorkAreaCheck(true);
                    }
                    return;
                }
                if (_active == ActiveDesktop) WatchDesktop();
                else if (_active == ActiveBottom)
                {
                    EnsureAboveDesktop(false);
                    // Bottom only because Explorer was not ready? try Desktop again now and then
                    if (_requested != DesktopModeRequest.Bottom && _desktopBlocked == null
                        && unchecked(Environment.TickCount - _bottomSince) > BottomRetryDesktopMs)
                    {
                        _bottomSince = Environment.TickCount;
                        string layout;
                        if (DesktopHost.FindIconHost(out layout) != IntPtr.Zero)
                        {
                            Log("desktop host available now -> switching to Desktop");
                            SafeRecreate();
                            return;
                        }
                    }
                }
                CheckWorkArea(false);
            }
            catch (Exception ex) { Log("watchdog: " + ex.Message); }
        }

        internal void NotifySystemChange()
        {
            ScheduleWorkAreaCheck(false);
            if (_active == ActiveBottom) _zBurstUntil = unchecked(Environment.TickCount + 800);
        }

        internal void NotifyExplorerRestarted()
        {
            Log("TaskbarCreated (Explorer (re)started)");
            if (_active == ActiveBottom) _bottomSince = unchecked(Environment.TickCount - BottomRetryDesktopMs + 1500);
            ScheduleWorkAreaCheck(true);
        }

        private void ScheduleWorkAreaCheck(bool force)
        {
            if (!IsHandleCreated || _closing) return;
            try
            {
                if (force) BeginInvoke(new MethodInvoker(ForceWorkAreaCheck));
                else BeginInvoke(new MethodInvoker(SoftWorkAreaCheck));
            }
            catch (Exception) { }
        }

        private void ForceWorkAreaCheck() { CheckWorkArea(true); }
        private void SoftWorkAreaCheck() { CheckWorkArea(false); }

        private void CheckWorkArea(bool force)
        {
            if (_closing) return;
            Rectangle wa = DesktopHost.GetWorkArea();
            int dpi = DesktopHost.GetPrimaryDpi();
            if (!force && wa == _lastWorkArea && dpi == _lastDpi) return;
            _lastWorkArea = wa;
            _lastDpi = dpi;
            Log("work area " + wa + " dpi " + dpi + (force ? " (refresh)" : " (changed)"));
            EventHandler h = WorkAreaChanged;
            if (h != null)
            {
                try { h(this, EventArgs.Empty); }
                catch (Exception ex) { AppendLog("WorkAreaChanged handler: " + ex.Message); }
            }
        }

        // ============================================================ log

        private void Log(string msg)
        {
            AppendLog(msg);
            EventHandler<DesktopLogEventArgs> h = LogMessage;
            if (h != null)
            {
                try { h(this, new DesktopLogEventArgs(msg)); }
                catch (Exception) { }
            }
        }

        private void AppendLog(string msg)
        {
            if (_log.Length > MaxLogChars) _log.Remove(0, _log.Length - MaxLogChars / 2);
            _log.Append(DateTime.Now.ToString("HH:mm:ss.fff")).Append(' ').Append(msg).Append("\r\n");
        }

        // ============================================================ teardown

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            base.OnFormClosing(e);
            if (!e.Cancel) _closing = true;
        }

        protected override void Dispose(bool disposing)
        {
            _closing = true;
            if (disposing)
            {
                try
                {
                    _watch.Stop(); _watch.Dispose();
                    _hit.Stop(); _hit.Dispose();
                    UnhookEvents();
                    if (_hookedMenu != null) { _hookedMenu.Closed -= OnMenuClosed; _hookedMenu = null; }
                    if (_sink != null) { _sink.DestroyHandle(); _sink = null; }
                    if (_buffer != null) { _buffer.Dispose(); _buffer = null; }
                }
                catch (Exception) { }
            }
            base.Dispose(disposing);
        }
    }
}
'@

function Write-CatLog([string]$Message) {
  try {
    Add-Content -Path $LogPath -Encoding UTF8 -Value ("[{0}] [bilgi] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
  } catch { }
}

# Auto (onerilen) | Desktop | Bottom.  Test icin konsolda:  set CATBAR_MODE=Bottom
$DesktopModeSetting = 'Auto'
if ($env:CATBAR_MODE) { $DesktopModeSetting = $env:CATBAR_MODE }

$script:DesktopOk = $false
try {
  if (-not ('TaskbarKedileri.DesktopForm' -as [type])) {
    Add-Type -TypeDefinition $DesktopHostCs -Language CSharp `
             -ReferencedAssemblies System.Windows.Forms, System.Drawing `
             -IgnoreWarnings -ErrorAction Stop
  }
  # Per-Monitor-V2 DPI: ilk WorkingArea sorgusundan ve pencereden ONCE.
  [void][TaskbarKedileri.DesktopHost]::InitDpi()
  $script:DesktopOk = $true
  Write-CatLog ('DesktopHost hazir: ' + [TaskbarKedileri.DesktopHost]::Describe())
}
catch {
  Write-CatLog ('DesktopHost kullanilamadi, eski TopMost pencereye donuluyor: ' + $_.Exception.Message)
}

function Get-WorkArea {
  if ($script:DesktopOk) { return [TaskbarKedileri.DesktopHost]::GetWorkArea() }
  return [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
}
function Get-PixelScale {
  if ($script:DesktopOk) { return [int][TaskbarKedileri.DesktopHost]::GetPixelScale() }
  return 1
}

# ---------------------------------------------------------------- sprite
$CELL_W = 34
$CELL_H = 33
$SHEET_W = 340
$FRAMES = @{
  'dogis_angry_1' = @(0,0)
  'dogis_angry_2' = @(34,0)
  'dogis_crouch_1' = @(68,0)
  'dogis_crouch_2' = @(102,0)
  'dogis_pet_1' = @(136,0)
  'dogis_pet_2' = @(170,0)
  'dogis_stand' = @(204,0)
  'dogis_walk_1' = @(238,0)
  'dogis_walk_2' = @(272,0)
  'dogis_walk_3' = @(306,0)
  'dogis_walk_4' = @(0,33)
  'dogis_wave_1' = @(34,33)
  'dogis_wave_2' = @(68,33)
  'dogis_wave_3' = @(102,33)
  'flower_1' = @(136,33)
  'flower_2' = @(170,33)
  'flower_3' = @(204,33)
  'fx_anger_1' = @(238,33)
  'fx_anger_2' = @(272,33)
  'fx_heart' = @(306,33)
  'fx_heart_s' = @(0,66)
  'fx_huff' = @(34,66)
  'fx_spark' = @(68,66)
  'fx_zzz_1' = @(102,66)
  'fx_zzz_2' = @(136,66)
  'fx_zzz_3' = @(170,66)
  'giraffe_blink' = @(204,66)
  'giraffe_idle_1' = @(238,66)
  'giraffe_idle_2' = @(272,66)
  'giraffe_lean' = @(306,66)
  'giraffe_sniff_1' = @(0,99)
  'giraffe_sniff_2' = @(34,99)
  'maya_jump_1' = @(68,99)
  'maya_jump_2' = @(102,99)
  'maya_jump_3' = @(136,99)
  'maya_lookup' = @(170,99)
  'maya_rub_a' = @(204,99)
  'maya_rub_b' = @(238,99)
  'maya_sit_a' = @(272,99)
  'maya_sit_b' = @(306,99)
  'maya_sit_blink' = @(0,132)
  'maya_sit_happy' = @(34,132)
  'maya_sleep_a' = @(68,132)
  'maya_sleep_b' = @(102,132)
  'maya_stand' = @(136,132)
  'maya_stretch' = @(170,132)
  'maya_walk_1' = @(204,132)
  'maya_walk_2' = @(238,132)
  'maya_walk_3' = @(272,132)
  'maya_walk_4' = @(306,132)
  'maya_yawn' = @(0,165)
  'sun_1' = @(34,165)
  'sun_2' = @(68,165)
  'sun_3' = @(102,165)
  'sun_4' = @(136,165)
  'tarcin_jump_1' = @(170,165)
  'tarcin_jump_2' = @(204,165)
  'tarcin_jump_3' = @(238,165)
  'tarcin_lookup' = @(272,165)
  'tarcin_rub_a' = @(306,165)
  'tarcin_rub_b' = @(0,198)
  'tarcin_sit_a' = @(34,198)
  'tarcin_sit_b' = @(68,198)
  'tarcin_sit_blink' = @(102,198)
  'tarcin_sit_happy' = @(136,198)
  'tarcin_sleep_a' = @(170,198)
  'tarcin_sleep_b' = @(204,198)
  'tarcin_stand' = @(238,198)
  'tarcin_stretch' = @(272,198)
  'tarcin_walk_1' = @(306,198)
  'tarcin_walk_2' = @(0,231)
  'tarcin_walk_3' = @(34,231)
  'tarcin_walk_4' = @(68,231)
  'tarcin_yawn' = @(102,231)
  'zilli_jump_1' = @(136,231)
  'zilli_jump_2' = @(170,231)
  'zilli_jump_3' = @(204,231)
  'zilli_lookup' = @(238,231)
  'zilli_rub_a' = @(272,231)
  'zilli_rub_b' = @(306,231)
  'zilli_sit_a' = @(0,264)
  'zilli_sit_b' = @(34,264)
  'zilli_sit_blink' = @(68,264)
  'zilli_sit_happy' = @(102,264)
  'zilli_sleep_a' = @(136,264)
  'zilli_sleep_b' = @(170,264)
  'zilli_stand' = @(204,264)
  'zilli_stretch' = @(238,264)
  'zilli_walk_1' = @(272,264)
  'zilli_walk_2' = @(306,264)
  'zilli_walk_3' = @(0,297)
  'zilli_walk_4' = @(34,297)
  'zilli_yawn' = @(68,297)
}

$sheetBytes = [Convert]::FromBase64String(@'
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
'@)
$ms       = New-Object System.IO.MemoryStream(,$sheetBytes)
$Sheet    = [System.Drawing.Image]::FromStream($ms)
$SheetBmp = New-Object System.Drawing.Bitmap $Sheet       # tiklama testi (GetPixel)
$SheetF   = New-Object System.Drawing.Bitmap $Sheet       # aynali kopya
$SheetF.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)

# ---------------------------------------------------------------- sahne motoru
# (kaynak/engine.ps1 - kaynak/scene.js ile birebir ayni)
# =====================================================================
#  ORTAK SAHNE MOTORU - PowerShell portu
#  kaynak/scene.js'in BIREBIR karsiligidir. Birini degistirirsen digerini
#  de degistir ve kaynak/test/parity.sh ile karsilastir (ayni tohum, ayni
#  tiklamalar -> her tick ayni ozet satiri).
#  Dikkat: [int] yuvarlar (banker's), JS Math.floor gibi davranmaz;
#  her yerde [Math]::Floor kullaniliyor.
# =====================================================================

$STAGE_W      = 200
$TICK         = 80
$HEADROOM     = 34
$SUN_TOP      = 0
$SUN_CX       = 16
$DECOR_W      = 37
$DECOR_MARGIN = 6
$FLOWER_DX    = 19

# ---- tohumlu rastgele sayi (Park-Miller MINSTD) -----------------------
$script:RNG = [long]1
function Rng-Seed([double]$s) { $script:RNG = [long](([Math]::Floor([double][Math]::Abs($s)) % 2147483646) + 1) }
function Rnd { $script:RNG = ($script:RNG * [long]48271) % [long]2147483647; return ([double]($script:RNG - 1)) / 2147483646 }
function RandInt($a, $b) { return $a + [Math]::Floor([double](Rnd) * ($b - $a + 1)) }
function Shuffle3 {
  $p = @(0, 1, 2)
  for ($i = 2; $i -gt 0; $i--) {
    $j = [int][Math]::Floor([double](Rnd) * ($i + 1))
    $t = $p[$i]; $p[$i] = $p[$j]; $p[$j] = $t
  }
  return ,$p
}

# ---- animasyonlar -------------------------------------------------------
$ANIM = @{
  walk   = @{ f = @('walk_1','walk_2','walk_3','walk_4'); hold = 2 }
  stand  = @{ f = @('stand'); hold = 8 }
  sit    = @{ f = @('sit_a','sit_a','sit_a','sit_blink'); hold = 8 }
  sitwag = @{ f = @('sit_a','sit_b'); hold = 6 }
  lookup = @{ f = @('lookup','lookup','lookup','sit_blink'); hold = 8 }
  jump   = @{ f = @('jump_1','jump_2','jump_3','jump_2','jump_1'); hold = 2 }
  sleep  = @{ f = @('sleep_a','sleep_b'); hold = 14; bob = @(0, -1) }
  yawn   = @{ f = @('sleep_a','yawn','yawn','stretch','stretch','sleep_a'); hold = 5 }
  rub    = @{ f = @('rub_a','rub_b'); hold = 5 }
  happy  = @{ f = @('sit_happy','sit_b'); hold = 5 }
}
$HANIM = @{
  hwalk  = @{ f = @('dogis_walk_1','dogis_walk_2','dogis_walk_3','dogis_walk_4'); hold = 3 }
  hstand = @{ f = @('dogis_stand'); hold = 10 }
  hwave  = @{ f = @('dogis_wave_1','dogis_wave_2','dogis_wave_3','dogis_wave_2'); hold = 3 }
  hpet   = @{ f = @('dogis_crouch_1','dogis_crouch_2'); hold = 6 }
  hjoy   = @{ f = @('dogis_pet_1','dogis_pet_2'); hold = 4 }
  hangry = @{ f = @('dogis_angry_1','dogis_angry_2'); hold = 5 }
}

# ---- sahneler -----------------------------------------------------------
$SCENES = @{
  parade = @{ dur = @(180, 300); follow = $true;  sun = 0.6; flipDogis = $false
              dogis = @{ x = 150; a = 'hwalk' }
              cats  = @(@{ x = 108; a = 'walk' }, @{ x = 68; a = 'walk' }, @{ x = 28; a = 'walk' }) }
  play   = @{ dur = @(200, 320); follow = $false; sun = 0.1; flipDogis = $true
              dogis = @{ x = 152; a = 'hwave' }
              cats  = @(@{ x = 112; a = 'jump' }, @{ x = 74; a = 'lookup' }, @{ x = 34; a = 'sit' }) }
  pet    = @{ dur = @(200, 320); follow = $false; sun = 0.1; flipDogis = $true
              dogis = @{ x = 146; a = 'hpet' }
              cats  = @(@{ x = 116; a = 'rub' }, @{ x = 76; a = 'happy' }, @{ x = 36; a = 'sitwag' }) }
  nap    = @{ dur = @(250, 400); follow = $false; sun = 0.1; flipDogis = $false
              dogis = @{ x = 150; a = 'hstand' }
              cats  = @(@{ x = 104; a = 'sleep' }, @{ x = 66; a = 'yawn' }, @{ x = 26; a = 'sleep' }) }
}
$ORDER = @('parade', 'play', 'pet', 'nap')

$SNIFF = @(@('giraffe_lean', 4), @('giraffe_sniff_1', 6), @('giraffe_sniff_2', 6),
           @('giraffe_sniff_1', 6), @('giraffe_sniff_2', 6), @('giraffe_sniff_1', 5),
           @('giraffe_lean', 4))
$FLWIG = @('flower_1', 'flower_2', 'flower_1', 'flower_3')

# ---- durum --------------------------------------------------------------
function New-Actor($name, $x, $anim) {
  return @{ name = $name; x = $x; tx = $x; anim = $anim; nextAnim = $anim; fi = 0; fh = 0
            flip = $false; nextFlip = $false; y = 0; ov = ''; ovT = 0 }
}

function New-State($screenW) {
  $st = @{
    scene = 'parade'; t = 0; clock = 0; dur = 200; phase = 'run'; screenW = $screenW
    groupX = 0; vel = 0; lead = 60
    sun = @{ x = 0; dir = 1 }
    dg  = @{ pets = 0; need = 3; last = -1000 }
    dc  = @{ wait = 0; seq = -1; seqT = 0; blink = 0; blinkWait = 0 }
    actors = @((New-Actor 'dogis' 150 'hwalk'), (New-Actor 'tarcin' 108 'walk'),
               (New-Actor 'maya' 68 'walk'), (New-Actor 'zilli' 28 'walk'))
    fx = (New-Object System.Collections.ArrayList)
    draw = (New-Object System.Collections.ArrayList)
  }
  $st.groupX = [Math]::Floor([double]$screenW / 2 - $STAGE_W / 2)
  $st.sun.x = $st.groupX + $STAGE_W / 2 + 60
  $st.dg.need = RandInt 2 3
  $st.dc.wait = RandInt 150 300
  $st.dc.blinkWait = RandInt 40 120
  Clamp-World $st
  Build-Draw $st
  return $st
}

# ---- yerlesim --------------------------------------------------------------
function Get-DecorX($st)   { return $st.screenW - $DECOR_MARGIN - $DECOR_W }
function Get-GroupMax($st) { return [Math]::Max([double]8, [double]((Get-DecorX $st) - 8 - $STAGE_W)) }
function Get-SunMin($st)   { return 24 }
function Get-SunMax($st)   { return [Math]::Max([double]25, [double]((Get-DecorX $st) - 24)) }

function Clamp-World($st) {
  $gm = Get-GroupMax $st
  if ($st.groupX -gt $gm) { $st.groupX = $gm }
  if ($st.groupX -lt 8) { $st.groupX = 8 }
  $sm = Get-SunMax $st
  if ($st.sun.x -gt $sm) { $st.sun.x = $sm }
  if ($st.sun.x -lt (Get-SunMin $st)) { $st.sun.x = Get-SunMin $st }
}
function Set-ScreenW($st, $w) { $st.screenW = $w; Clamp-World $st; Build-Draw $st }

function Get-FollowTarget($st) {
  $t = $st.sun.x - $STAGE_W / 2 - $st.lead
  $gm = Get-GroupMax $st
  if ($t -gt $gm) { $t = $gm }
  if ($t -lt 8) { $t = 8 }
  return $t
}

# ---- sahne gecisi ------------------------------------------------------------
function Apply-Scene($st, $name) {
  $s = $SCENES[$name]
  $st.scene = $name; $st.t = 0; $st.phase = 'move'; $st.vel = 0
  $st.dur = $s.dur[0] + [Math]::Floor([double](Rnd) * ($s.dur[1] - $s.dur[0]))
  $d = $st.actors[0]
  $d.tx = $s.dogis.x; $d.nextAnim = $s.dogis.a; $d.nextFlip = [bool]$s.flipDogis
  $perm = Shuffle3
  for ($i = 0; $i -lt 3; $i++) {
    $slot = $perm[$i]
    $c = $st.actors[$i + 1]
    $c.tx = $s.cats[$slot].x
    $c.nextAnim = $s.cats[$slot].a
    $c.nextFlip = $false
  }
}

function Get-NextScene($st) {
  if ($st.scene -ne 'parade' -and [Math]::Abs((Get-FollowTarget $st) - $st.groupX) -gt 40) { return 'parade' }
  $others = @($ORDER | Where-Object { $_ -ne $st.scene })
  return $others[[int][Math]::Floor([double](Rnd) * $others.Count)]
}

# ---- etkilesim ------------------------------------------------------------------
function Set-Ov($a, $anim, $ticks) { $a.ov = $anim; $a.ovT = $ticks; $a.fi = 0; $a.fh = 0 }

function Find-Actor($st, $id) {
  foreach ($a in $st.actors) { if ($a.name -eq $id) { return $a } }
  return $null
}

# Donus: 'joy' | 'angry' | 'jump' | ''
function Invoke-Poke($st, $id) {
  $a = Find-Actor $st $id
  if ($null -eq $a) { return '' }
  if ($id -eq 'dogis') {
    $d = $st.dg
    if ($a.ov -eq 'hangry') {
      if ($a.ovT -lt 25) { $a.ovT = 25 }
      return 'angry'
    }
    if (($st.clock - $d.last) -gt 150) { $d.pets = 0 }
    $d.pets++; $d.last = $st.clock
    if ($d.pets -ge $d.need) {
      Set-Ov $a 'hangry' 64
      $d.pets = 0; $d.need = RandInt 2 3
      $keep = New-Object System.Collections.ArrayList
      foreach ($f in $st.fx) { if ($f.own -ne 'dogis') { [void]$keep.Add($f) } }
      $st.fx = $keep
      return 'angry'
    }
    Set-Ov $a 'hjoy' 24
    [void]$st.fx.Add(@{ kind = 'fx_heart'; x = $st.groupX + $a.x; y = -6; life = 24; own = 'dogis' })
    return 'joy'
  }
  Set-Ov $a 'jump' 26
  [void]$st.fx.Add(@{ kind = 'fx_heart'; x = $st.groupX + $a.x + 6; y = -4; life = 24 })
  return 'jump'
}

# Sprite pikseli koordinatina tiklama. $hit: { param($k, $lx, $ly) -> opak mi }
function Click-At($st, $sx, $sy, $cw, $ch, $hit) {
  for ($i = $st.draw.Count - 1; $i -ge 0; $i--) {
    $d = $st.draw[$i]
    if (-not $d.id) { continue }
    $lx = $sx - $d.x; $ly = $sy - $d.y
    if ($lx -lt 0 -or $ly -lt 0 -or $lx -ge $cw -or $ly -ge $ch) { continue }
    $hx = if ($d.f) { $cw - 1 - $lx } else { $lx }
    if (& $hit $d.k $hx $ly) { [void](Invoke-Poke $st $d.id); return $d.id }
  }
  return ''
}

# ---- kare adi ---------------------------------------------------------------------
function Get-AnimSet($a) {
  $an = if ($a.ov) { $a.ov } else { $a.anim }
  if ($a.name -eq 'dogis') { return $HANIM[$an] } else { return $ANIM[$an] }
}
function Get-FrameName($a) {
  $set = Get-AnimSet $a
  $f = $set.f[$a.fi % $set.f.Count]
  if ($a.name -eq 'dogis') { return $f } else { return $a.name + '_' + $f }
}

# ---- tick -------------------------------------------------------------------------
function Step-State($st) {
  $st.t++; $st.clock++
  $s = $SCENES[$st.scene]
  $dog = $st.actors[0]
  $hold = ($dog.ov -eq 'hangry')

  # gunes suzulur, kenarlarda doner
  $st.sun.x = $st.sun.x + $s.sun * $st.sun.dir
  $sm = Get-SunMax $st
  if ($st.sun.x -gt $sm) { $st.sun.x = $sm; $st.sun.dir = -1 }
  if ($st.sun.x -lt (Get-SunMin $st)) { $st.sun.x = Get-SunMin $st; $st.sun.dir = 1 }
  $wantLead = 60 * $st.sun.dir
  if ($st.lead -lt $wantLead) { $st.lead = [Math]::Min([double]$wantLead, [double]($st.lead + 0.5)) }
  elseif ($st.lead -gt $wantLead) { $st.lead = [Math]::Max([double]$wantLead, [double]($st.lead - 0.5)) }

  if ($st.phase -eq 'move') {
    $moving = $false
    foreach ($a in $st.actors) {
      if ($a.ov -eq 'hangry') { $moving = $true; continue }
      $d = $a.tx - $a.x
      if ([Math]::Abs($d) -gt 1.5) {
        $a.x = $a.x + [Math]::Sign($d) * 2; $a.flip = ($d -lt 0)
        $a.anim = if ($a.name -eq 'dogis') { 'hwalk' } else { 'walk' }
        $moving = $true
      } else {
        $a.x = $a.tx; $a.anim = $a.nextAnim; $a.flip = $a.nextFlip
      }
    }
    if (-not $moving) { $st.phase = 'run'; $st.t = 0 }
  } else {
    if ($s.follow) {
      $v = 0
      if (-not $hold) {
        $v = ((Get-FollowTarget $st) - $st.groupX) * 0.05
        if ($v -gt 2) { $v = 2 }
        if ($v -lt -2) { $v = -2 }
        if ([Math]::Abs($v) -lt 0.15) { $v = 0 }
      }
      $st.vel = $v
      $st.groupX = $st.groupX + $v
      Clamp-World $st
      $walking = ($v -ne 0)
      $faceLeft = if ($walking) { $v -lt 0 } else { $st.sun.x -lt ($st.groupX + $STAGE_W / 2) }
      foreach ($a in $st.actors) {
        if ($a.name -eq 'dogis') { $a.anim = if ($walking) { 'hwalk' } else { 'hstand' } }
        else { $a.anim = if ($walking) { 'walk' } else { 'stand' } }
        $a.flip = $faceLeft
      }
    }
    if ($st.t -gt $st.dur) { Apply-Scene $st (Get-NextScene $st) }
  }

  # kareler
  foreach ($a in $st.actors) {
    if ($a.ovT -gt 0) {
      $a.ovT--
      if ($a.ovT -eq 0) { $a.ov = ''; $a.fi = 0; $a.fh = 0 }
    }
    $an = if ($a.ov) { $a.ov } else { $a.anim }
    $set = Get-AnimSet $a
    $a.fh++
    if ($a.fh -ge $set.hold) { $a.fh = 0; $a.fi = ($a.fi + 1) % $set.f.Count }
    if ($an -eq 'jump') {
      $f = $set.f[$a.fi]
      $a.y = if ($f -eq 'jump_2') { -5 } elseif ($f -eq 'jump_3') { -3 } else { 0 }
    } elseif ($set.bob) {
      $a.y = $set.bob[$a.fi % $set.bob.Count]
    } else {
      $a.y = 0
    }
  }

  # zurafa ve cicek
  $dc = $st.dc
  if ($dc.blink -gt 0) {
    $dc.blink--
  } else {
    $dc.blinkWait--
    if ($dc.blinkWait -le 0) { $dc.blink = 3; $dc.blinkWait = RandInt 50 140 }
  }
  if ($dc.seq -lt 0) {
    $dc.wait--
    if ($dc.wait -le 0) { $dc.seq = 0; $dc.seqT = 0 }
  } else {
    $dc.seqT++
    if ($dc.seqT -ge $SNIFF[$dc.seq][1]) {
      $dc.seqT = 0; $dc.seq++
      if ($dc.seq -eq 3) { [void]$st.fx.Add(@{ kind = 'fx_heart_s'; x = (Get-DecorX $st) + 12; y = -6; life = 22 }) }
      if ($dc.seq -ge $SNIFF.Count) { $dc.seq = -1; $dc.wait = RandInt 220 480 }
    }
  }

  # sahne efektleri
  if ($st.phase -eq 'run') {
    if ($st.scene -eq 'pet' -and ($st.t % 22) -eq 0) {
      $p = $st.actors[1]
      foreach ($a in $st.actors) { if ($a.anim -eq 'rub') { $p = $a; break } }
      $k = if ((Rnd) -lt 0.5) { 'fx_heart' } else { 'fx_heart_s' }
      [void]$st.fx.Add(@{ kind = $k; x = $st.groupX + $p.x + 4; y = -4; life = 26 })
    }
    if ($st.scene -eq 'nap' -and ($st.t % 16) -eq 0) {
      $sl = @($st.actors | Where-Object { $_.anim -eq 'sleep' })
      $p = if ($sl.Count -gt 0) { $sl[[int][Math]::Floor([double](Rnd) * $sl.Count)] } else { $st.actors[1] }
      [void]$st.fx.Add(@{ kind = 'zzz'; x = $st.groupX + $p.x + 8; y = -2; life = 30 })
    }
    if ($st.scene -eq 'play' -and ($st.t % 30) -eq 0) {
      [void]$st.fx.Add(@{ kind = 'fx_spark'; x = $st.groupX + $st.actors[0].x - 12; y = -14; life = 12 })
    }
  }
  $keep = New-Object System.Collections.ArrayList
  foreach ($f in $st.fx) {
    $f.life--; $f.y = $f.y - 0.5
    if ($f.life -gt 0) { [void]$keep.Add($f) }
  }
  $st.fx = $keep

  Build-Draw $st
}

# ---- cizim listesi ---------------------------------------------------------------
function Add-Draw($out, $k, $x, $y, $f, $id) {
  [void]$out.Add(@{ k = $k; x = $x; y = $y; f = [bool]$f; id = $id })
}

function Build-Draw($st) {
  $out = New-Object System.Collections.ArrayList
  # 1) gunes
  Add-Draw $out ('sun_' + (1 + [Math]::Floor([double]$st.clock / 2) % 4)) ([Math]::Floor([double]$st.sun.x) - $SUN_CX) $SUN_TOP $false ''
  # 2) zurafa + cicek
  $dx = Get-DecorX $st
  $sniffing = ($st.dc.seq -ge 0)
  $div = if ($sniffing) { 4 } else { 12 }
  $fl = $FLWIG[[int]([Math]::Floor([double]$st.clock / $div) % 4)]
  Add-Draw $out $fl ($dx + $FLOWER_DX) $HEADROOM $false ''
  if ($sniffing) { $gf = $SNIFF[$st.dc.seq][0] }
  elseif ($st.dc.blink -gt 0) { $gf = 'giraffe_blink' }
  elseif (([Math]::Floor([double]$st.clock / 14) % 2) -eq 1) { $gf = 'giraffe_idle_2' }
  else { $gf = 'giraffe_idle_1' }
  Add-Draw $out $gf $dx $HEADROOM $false ''
  # 3) karakterler
  foreach ($a in $st.actors) {
    Add-Draw $out (Get-FrameName $a) ([Math]::Floor([double]$st.groupX + $a.x)) ($HEADROOM + $a.y) $a.flip $a.name
  }
  # 4) Dogis'in ofke isareti ve buhar
  $dog = $st.actors[0]
  if ($dog.ov -eq 'hangry') {
    $bx = [Math]::Floor([double]$st.groupX + $dog.x); $by = $HEADROOM + $dog.y
    $ax = if ($dog.flip) { 7 } else { 20 }
    Add-Draw $out ('fx_anger_' + (1 + [Math]::Floor([double]$st.clock / 4) % 2)) ($bx + $ax) ($by - 29) $false ''
    if ((Get-FrameName $dog) -eq 'dogis_angry_2') {
      $hx = if ($dog.flip) { -5 } else { 5 }
      Add-Draw $out 'fx_huff' ($bx + $hx) ($by - 21) $dog.flip ''
    }
  }
  # 5) ucan efektler
  foreach ($f in $st.fx) {
    $k = $f.kind
    if ($k -eq 'zzz') { $k = 'fx_zzz_' + [Math]::Max(1, [Math]::Min(3, 3 - [Math]::Floor([double](30 - $f.life) / 10))) }
    Add-Draw $out $k ([Math]::Floor([double]$f.x)) ([Math]::Floor([double]$HEADROOM + $f.y - 14)) $false ''
  }
  $st.draw = $out
}

# ---- karsilastirma testi icin tek satirlik ozet -------------------------------------
function Get-Digest($st) {
  $sb = New-Object System.Text.StringBuilder
  $fl = { param($v) [string][long][Math]::Floor([double]$v * 1000) }
  [void]$sb.Append([string]$st.clock + '|' + $st.scene + '|' + $st.phase + '|' + (& $fl $st.groupX) + '|' +
    (& $fl $st.sun.x) + '|' + $st.sun.dir + '|' + (& $fl $st.lead) + '|' + $st.dg.pets + '/' + $st.dg.need + '|' + $st.fx.Count)
  foreach ($d in $st.draw) {
    $ff = if ($d.f) { 1 } else { 0 }
    [void]$sb.Append('|' + $d.k + ',' + [long]$d.x + ',' + [long]$d.y + ',' + $ff + ',' + $d.id)
  }
  return $sb.ToString()
}

# ---------------------------------------------------------------- ayarlar
$KEY       = [System.Drawing.Color]::FromArgb(255, 0, 255)   # saydamlik anahtari
$UserScale = 2                   # menudeki "Boyut Nx"
$PxMul     = Get-PixelScale      # DPI carpani: %100-125 -> 1, %150-225 -> 2 (net pikseller)
$Scale     = $UserScale * $PxMul
$script:Paused = $false

$wa = Get-WorkArea
Rng-Seed ([double]((Get-Date).Ticks % 2147483646))
$script:S = New-State ([Math]::Floor([double]$wa.Width / $Scale))

# ---------------------------------------------------------------- cizim
function Draw-Frame($g, $name, $px, $py, $flip) {
  $cell = $FRAMES[$name]
  if ($null -eq $cell) { return }
  $sx = $cell[0]; $sy = $cell[1]
  if ($flip) { $img = $SheetF; $sx = $SHEET_W - $sx - $CELL_W } else { $img = $Sheet }
  $src = New-Object System.Drawing.Rectangle $sx, $sy, $CELL_W, $CELL_H
  $dst = New-Object System.Drawing.Rectangle ([int]$px), ([int]$py), ($CELL_W * $script:Scale), ($CELL_H * $script:Scale)
  $g.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
}

# ---------------------------------------------------------------- pencere
if ($script:DesktopOk) {
  $form = New-Object TaskbarKedileri.DesktopForm
  try { $form.RequestedMode = $DesktopModeSetting }
  catch { Write-CatLog "Gecersiz CATBAR_MODE '$DesktopModeSetting' (Auto/Desktop/Bottom) - Auto kullaniliyor" }
} else {
  # Yedek (C# derlenemezse): siradan, ustte-tutulmayan pencere.
  $form = New-Object System.Windows.Forms.Form
  $form.TopMost = $false
}
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar   = $false
$form.StartPosition   = 'Manual'
$form.BackColor       = $KEY
$form.TransparencyKey = $KEY
$form.Text            = 'Taskbar Kedileri'
$form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance,NonPublic').SetValue($form, $true, $null)

function Update-Bounds {
  $wa = Get-WorkArea
  $script:PxMul = Get-PixelScale
  $script:Scale = $script:UserScale * $script:PxMul
  $h  = ($CELL_H + $HEADROOM) * $script:Scale
  # Bounds HER ZAMAN ekran koordinati; DesktopForm Progman/WorkerW icindeyken kendisi cevirir.
  $form.Bounds = New-Object System.Drawing.Rectangle $wa.X, ($wa.Bottom - $h), $wa.Width, $h
  Set-ScreenW $script:S ([Math]::Floor([double]$wa.Width / $script:Scale))
}
Update-Bounds

if ($script:DesktopOk) {
  # taskbar tasindi / boyut / otomatik gizle, cozunurluk ya da DPI degisti, Explorer yeniden basladi
  $form.Add_WorkAreaChanged({ Update-Bounds; $form.Invalidate() })
  $form.Add_ModeChanged({ Write-CatLog ('Masaustu modu: {0} | {1}' -f $form.Mode, $form.ModeDetail) })
  $form.Add_LogMessage({ param($s, $e) Write-CatLog ('DesktopHost: ' + $e.Message) })
}

$form.Add_Paint({
  param($sender, $e)
  $g = $e.Graphics
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::None
  $g.Clear($KEY)
  $z = $script:Scale
  foreach ($d in $script:S.draw) { Draw-Frame $g $d.k ($d.x * $z) ($d.y * $z) $d.f }
})

# ---------------------------------------------------------------- etkilesim
# Kedi: ziplar + kalp. Dogis: sevinir; 2-3 sevmede bikar (kollar kavusur, yuz kizarir).
$HitFn = {
  param($k, $lx, $ly)
  $c = $FRAMES[$k]
  if ($null -eq $c) { return $false }
  return ($SheetBmp.GetPixel([int]($c[0] + $lx), [int]($c[1] + $ly)).A -gt 0)
}
$form.Add_MouseDown({
  param($sender, $e)
  if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
  $z = $script:Scale
  $sx = [Math]::Floor([double]$e.X / $z); $sy = [Math]::Floor([double]$e.Y / $z)
  [void](Click-At $script:S $sx $sy $CELL_W $CELL_H $HitFn)
  $form.Invalidate()
})

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miPause = $menu.Items.Add('Duraklat')
$miPause.Add_Click({
  $script:Paused = -not $script:Paused
  $miPause.Text = if ($script:Paused) { 'Devam et' } else { 'Duraklat' }
})
[void]$menu.Items.Add('-')
foreach ($z in 1,2,3) {
  $mi = $menu.Items.Add("Boyut $($z)x")
  $mi.Tag = $z
  # GetNewClosure KULLANMA: kapanis kendi kapsaminda calisir, Update-Bounds'u bulamaz.
  $mi.Add_Click({ param($s,$e2) $script:UserScale = [int]$s.Tag; Update-Bounds; $form.Invalidate() })
}
[void]$menu.Items.Add('-')
$miScene = $menu.Items.Add('Sahneyi degistir')
$miScene.Add_Click({
  $others = @($ORDER | Where-Object { $_ -ne $script:S.scene })
  Apply-Scene $script:S ($others | Get-Random)
})

if ($script:DesktopOk) {
  [void]$menu.Items.Add('-')
  $miMode     = New-Object System.Windows.Forms.ToolStripMenuItem 'Konum'
  $miModeInfo = New-Object System.Windows.Forms.ToolStripMenuItem 'Aktif: ?'
  $miModeInfo.Enabled = $false
  [void]$miMode.DropDownItems.Add($miModeInfo)
  foreach ($pair in @(@('Otomatik', 'Auto'), @('Masaustune yerlestir', 'Desktop'), @('Pencerelerin altinda', 'Bottom'))) {
    $it = New-Object System.Windows.Forms.ToolStripMenuItem $pair[0]
    $it.Tag = $pair[1]
    $it.Add_Click({ param($s,$e2) $form.RequestedMode = [string]$s.Tag })
    [void]$miMode.DropDownItems.Add($it)
  }
  $miMode.Add_DropDownOpening({
    $miModeInfo.Text = 'Aktif: ' + $form.Mode
    foreach ($it in $miMode.DropDownItems) {
      if ($it.Tag) { $it.Checked = ([string]$it.Tag -eq [string]$form.RequestedMode) }
    }
  })
  [void]$menu.Items.Add($miMode)
}

[void]$menu.Items.Add('-')
$miExit = $menu.Items.Add('Cikis')
$miExit.Add_Click({ $form.Close() })
$form.ContextMenuStrip = $menu

# ---------------------------------------------------------------- dongu
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $TICK
$timer.Add_Tick({
  if (-not $script:Paused) { Step-State $script:S }
  $form.Invalidate()
})
$timer.Start()

$form.Add_FormClosed({ $timer.Stop(); [System.Windows.Forms.Application]::Exit() })
# Run($form) DEGIL: Explorer yeniden baslayinca cocuk pencereyi yok eder; formsuz
# dongu ayakta kalir, DesktopForm penceresini yeniden kurar. "Cikis" yine Exit cagirir.
$form.Show()
[System.Windows.Forms.Application]::Run()

}
catch {
  $msg = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Exception.GetType().Name): $($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n"
  Add-Content -Path $LogPath -Value $msg -Encoding UTF8
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
  [System.Windows.Forms.MessageBox]::Show("Kedi widget'i baslatilamadi.`r`n`r`n$($_.Exception.Message)`r`n`r`nAyrinti: $LogPath", 'Taskbar Kedileri') | Out-Null
}
