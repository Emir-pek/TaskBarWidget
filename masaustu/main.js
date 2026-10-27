// =====================================================================
//  Taskbar Kedileri - Electron surumu (macOS / Windows / Linux)
//  Windows'taki catbar.ps1 ile ayni sprite sheet'i ve ayni sahne
//  motorunu (ortak/scene.js) kullanir.
// =====================================================================
const { app, BrowserWindow, screen, Tray, Menu, ipcMain, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');

// ===== macOS: gercek masaustu widget katmani ==========================
const IS_MAC = process.platform === 'darwin';

// NSNormalWindowLevel = 0. -1 => butun uygulama pencerelerinin ALTINDA,
// duvar kagidi (-2147483623) ve Finder ikon katmaninin (-2147483603) USTUNDE.
const MAC_LEVEL = -1;

// AppKit NSWindowCollectionBehavior bitleri
const NSWCB_CAN_JOIN_ALL_SPACES = 1 << 0;
const NSWCB_STATIONARY          = 1 << 4;   // Mission Control / "Masaustunu Goster" etkilemez
const NSWCB_IGNORES_CYCLE       = 1 << 6;   // Cmd-` dongusune girmez
const MAC_BEHAVIOR = NSWCB_CAN_JOIN_ALL_SPACES | NSWCB_STATIONARY | NSWCB_IGNORES_CYCLE;

let objc;   // undefined: denenmedi, null: koffi yok
function loadObjc() {
  if (objc !== undefined) return objc;
  objc = null;
  try {
    const koffi = require('koffi');
    const lib = koffi.load('/usr/lib/libobjc.A.dylib');
    // arm64: objc_msgSend her imza icin tam tipli, variadic OLMAYAN prototiple cagrilmali.
    objc = {
      koffi,
      sel:       lib.func('void *sel_registerName(const char *name)'),
      className: lib.func('const char *object_getClassName(void *obj)'),
      msgPtr:    lib.func('objc_msgSend', 'void *',   ['void *', 'void *']),
      msgGetI64: lib.func('objc_msgSend', 'int64_t',  ['void *', 'void *']),
      msgGetU64: lib.func('objc_msgSend', 'uint64_t', ['void *', 'void *']),
      msgSetI64: lib.func('objc_msgSend', 'void',     ['void *', 'void *', 'int64_t']),
      msgSetU64: lib.func('objc_msgSend', 'void',     ['void *', 'void *', 'uint64_t']),
    };
  } catch (e) {
    console.warn('[kedi] koffi yok, Stationary uygulanamadi (yedek mod):', e.message);
  }
  return objc;
}

function applyMacDesktopLayer() {
  if (!IS_MAC || !win || win.isDestroyed()) return;
  const o = loadObjc();
  if (!o) return;
  try {
    const view = o.koffi.decode(win.getNativeWindowHandle(), 'void *'); // NSView* (contentView)
    if (!view) return;
    const nsw = o.msgPtr(view, o.sel('window'));
    if (!nsw) return;
    const cls = String(o.className(nsw));
    if (!cls.startsWith('Electron')) {           // ElectronNSWindow / ElectronNSPanel bekleniyor
      console.warn('[kedi] beklenmeyen pencere sinifi:', cls);
      return;
    }
    o.msgSetU64(nsw, o.sel('setCollectionBehavior:'), MAC_BEHAVIOR);
    o.msgSetI64(nsw, o.sel('setLevel:'), MAC_LEVEL);
    const lvl = o.msgGetI64(nsw, o.sel('level'));
    const cb = o.msgGetU64(nsw, o.sel('collectionBehavior'));
    console.log(`[kedi] macOS katman: class=${cls} level=${lvl} behavior=0x${Number(cb).toString(16)}`);
  } catch (e) {
    console.warn('[kedi] applyMacDesktopLayer hatasi:', e.message);
  }
}

// Seviye <= 0 iken Chromium, key olmayan pencereye mousemove gondermiyor
// (RenderWidgetHostViewCocoa: level > NSNormalWindowLevel sarti). Bu yuzden
// imleci ana surecte yokluyoruz; renderer ayni piksel testini yapiyor.
let cursorTimer = null;
function startCursorPoll() {
  if (!IS_MAC || cursorTimer) return;
  let inside = false, lx = -1, ly = -1;
  cursorTimer = setInterval(() => {
    if (!win || win.isDestroyed()) return;
    const p = screen.getCursorScreenPoint();
    const b = win.getBounds();
    const now = p.x >= b.x && p.x < b.x + b.width && p.y >= b.y && p.y < b.y + b.height;
    if (now) {
      const x = p.x - b.x, y = p.y - b.y;
      if (!inside || x !== lx || y !== ly) win.webContents.send('kedi:cursor', { x, y });
      lx = x; ly = y;
    } else if (inside) {
      win.webContents.send('kedi:cursor', null);   // pencereden cikti -> tekrar gecirgen
    }
    inside = now;
  }, 33);
}

const META = JSON.parse(fs.readFileSync(path.join(__dirname, 'ortak', 'sprites.json'), 'utf8'));
const CELL_H = META.cell_h;
const HEADROOM = 34;              // gunes + kalp / zzz efektleri icin ust bosluk (scene.js ile ayni)

let win = null;
let tray = null;
let scale = 2;
let paused = false;

// --- pencere, gorev cubugunun / Dock'un hemen ustune oturur ---------
function widgetBounds() {
  const wa = screen.getPrimaryDisplay().workArea;   // Dock ve menu cubugu haric
  const h = (CELL_H + HEADROOM) * scale;
  return { x: wa.x, y: wa.y + wa.height - h, width: wa.width, height: h };
}

function applyBounds() {
  if (!win) return;
  const b = widgetBounds();
  win.setBounds(b);
  win.webContents.send('kedi:bounds', { width: b.width, height: b.height, scale });
  applyMacDesktopLayer();
}

function createWindow() {
  win = new BrowserWindow({
    ...widgetBounds(),
    // macOS: tiklayinca uygulamayi aktiflestirmeyen panel + ilk tiklamayi web icerigine ilet
    ...(IS_MAC ? { type: 'panel', acceptFirstMouse: true } : {}),
    transparent: true,
    frame: false,
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    fullscreenable: false,
    hasShadow: false,
    skipTaskbar: true,
    focusable: false,            // masaustu widget'i: tiklayinca odagi calmasin
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      backgroundThrottling: false,
    },
  });

  // MASAUSTU WIDGET'I: acilan her pencere kedilerin ONUNE gecer.
  if (IS_MAC) {
    // Normal pencerelerin ALTINDA, masaustunun USTUNDE (seviye -1). Saf JS; koffi olmasa da calisir.
    win.setAlwaysOnTop(true, 'normal', MAC_LEVEL);
    // NOT: setVisibleOnAllWorkspaces cagirmiyoruz: panel zaten tum Space'lere katiliyor ve
    // skipTransformProcessType olmadan app.dock.hide()'i geri aliyor (Dock ikonu geri gelir).
    applyMacDesktopLayer();          // koffi: Stationary + IgnoresCycle + seviye -1
  } else {
    // Windows / Linux: ustte-tutma YOK. (Windows'ta asil surum catbar.ps1;
    // Linux'ta Electron bu pencereyi override-redirect actigi icin pencere
    // yoneticisine gore degisebilir - Linux resmi hedef degil.)
    win.setAlwaysOnTop(false);
  }

  // Varsayilan: tiklamalar alttaki pencereye gecer. forward:true sayesinde
  // renderer yine de mousemove alir; imlec dolu bir pikselin uzerine
  // gelince gecirgenligi kapatir.
  win.setIgnoreMouseEvents(true, { forward: true });

  win.loadFile(path.join(__dirname, 'index.html'));
  win.once('ready-to-show', () => { win.showInactive(); applyMacDesktopLayer(); });
  if (IS_MAC) win.on('show', applyMacDesktopLayer);
  startCursorPoll();
}

// --- tepsi / menu cubugu menusu -------------------------------------
function buildMenu() {
  return Menu.buildFromTemplate([
    {
      label: paused ? 'Devam et' : 'Duraklat',
      click: () => {
        paused = !paused;
        win.webContents.send('kedi:paused', paused);
        tray.setContextMenu(buildMenu());
      },
    },
    { type: 'separator' },
    ...[1, 2, 3].map((z) => ({
      label: `Boyut ${z}x`,
      type: 'radio',
      checked: scale === z,
      click: () => { scale = z; applyBounds(); tray.setContextMenu(buildMenu()); },
    })),
    { type: 'separator' },
    { label: 'Sahneyi degistir', click: () => win.webContents.send('kedi:scene') },
    { type: 'separator' },
    { label: 'Cikis', click: () => app.quit() },
  ]);
}

function createTray() {
  const icon = nativeImage.createFromPath(path.join(__dirname, 'ortak', 'tray.png'));
  tray = new Tray(icon.resize({ width: 18, height: 18 }));
  tray.setToolTip('Taskbar Kedileri');
  tray.setContextMenu(buildMenu());
}

// --- renderer'dan gelenler ------------------------------------------
ipcMain.on('kedi:set-ignore', (_e, v) => {
  if (win) win.setIgnoreMouseEvents(v, { forward: true });
});
ipcMain.on('kedi:menu', () => { if (tray) tray.popUpContextMenu(buildMenu()); });
ipcMain.on('kedi:ready', () => applyBounds());

// --- yasam dongusu ---------------------------------------------------
app.whenReady().then(() => {
  if (process.platform === 'darwin' && app.dock) app.dock.hide();  // Dock'ta ikon olmasin
  createWindow();
  createTray();

  screen.on('display-metrics-changed', applyBounds);   // Dock gizlenir/tasinirsa
  screen.on('display-added', applyBounds);
  screen.on('display-removed', applyBounds);

  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});

app.on('window-all-closed', () => app.quit());
