// =====================================================================
//  Taskbar Kedileri - Electron surumu (macOS / Windows / Linux)
//  Windows'taki catbar.ps1 ile ayni sprite sheet'i ve ayni sahne
//  motorunu (ortak/scene.js) kullanir.
// =====================================================================
const { app, BrowserWindow, screen, Tray, Menu, ipcMain, nativeImage } = require('electron');
const path = require('path');
const fs = require('fs');

const META = JSON.parse(fs.readFileSync(path.join(__dirname, 'ortak', 'sprites.json'), 'utf8'));
const CELL_H = META.cell_h;
const HEADROOM = 14;              // kalp / zzz efektleri icin ust bosluk

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
}

function createWindow() {
  win = new BrowserWindow({
    ...widgetBounds(),
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

  // Her Space'te gorun, AMA tam ekran uygulamalarin ustune cikma.
  // 'screen-saver' seviyesi + visibleOnFullScreen:true kediler tam ekran
  // videonun uzerinde duruyordu; 'floating' normal pencerelerin ustunde
  // kalmaya yetiyor ve tam ekrana girilince macOS pencereyi gizliyor.
  win.setAlwaysOnTop(true, 'floating');
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: false });

  // Varsayilan: tiklamalar alttaki pencereye gecer. forward:true sayesinde
  // renderer yine de mousemove alir; imlec dolu bir pikselin uzerine
  // gelince gecirgenligi kapatir.
  win.setIgnoreMouseEvents(true, { forward: true });

  win.loadFile(path.join(__dirname, 'index.html'));
  win.once('ready-to-show', () => win.showInactive());
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
