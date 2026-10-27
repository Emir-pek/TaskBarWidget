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
