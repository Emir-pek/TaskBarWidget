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
