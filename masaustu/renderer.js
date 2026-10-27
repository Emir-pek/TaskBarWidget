// =====================================================================
//  Cizim katmani. Sahne mantigi ortak/scene.js icinde (onizleme ve
//  Windows surumu ile ayni). Motor her tick st.draw listesini uretir;
//  burada sadece o liste basilir.
// =====================================================================
const cv = document.getElementById('cv');
const ctx = cv.getContext('2d');

let META = null, SHEET = null, st = null, ALPHA = null, SW = 0;
let scale = 2, paused = false;
let cssW = window.innerWidth, cssH = window.innerHeight;

async function boot() {
  META = await fetch('ortak/sprites.json').then((r) => r.json());
  SHEET = new Image();
  SHEET.src = 'ortak/sprites.png';
  await SHEET.decode();
  // tiklama testi icin sheet'in saydamlik maskesi (ekrandan okumaya gerek yok)
  const off = document.createElement('canvas');
  off.width = SW = SHEET.width; off.height = SHEET.height;
  const g = off.getContext('2d');
  g.drawImage(SHEET, 0, 0);
  ALPHA = g.getImageData(0, 0, off.width, off.height).data;

  resize(cssW, cssH, scale);
  seedRng(Date.now() % 2147483646);
  st = makeState(Math.floor(cssW / scale));
  setInterval(tick, TICK);
  window.kedi.ready();
}

function resize(w, h, z) {
  cssW = w; cssH = h; scale = z;
  const dpr = window.devicePixelRatio || 1;      // Retina'da net kalsin
  cv.style.width = w + 'px';
  cv.style.height = h + 'px';
  cv.width = Math.round(w * dpr);
  cv.height = Math.round(h * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.imageSmoothingEnabled = false;
  if (st) setScreen(st, Math.floor(w / scale));
}

function draw(name, px, py, flip) {
  const f = META.frames[name];
  if (!f) return;
  ctx.save();
  if (flip) { ctx.translate(px + f.w * scale, py); ctx.scale(-1, 1); }
  else ctx.translate(px, py);
  ctx.drawImage(SHEET, f.x, f.y, f.w, f.h, 0, 0, f.w * scale, f.h * scale);
  ctx.restore();
}

// Pencere, sahnenin (HEADROOM + hucre) yuksekligiyle ayni; alt kenar = taskbar/Dock.
function originY() { return cssH - (HEADROOM + META.cell_h) * scale; }

function render() {
  ctx.clearRect(0, 0, cssW, cssH);
  const oy = originY();
  for (const d of st.draw) draw(d.k, d.x * scale, oy + d.y * scale, d.f);
}

function tick() {
  if (!paused) step(st);
  render();
}

// --- fare: saydam pikselde tiklama gecsin, karakterde gecmesin -------
function opaque(k, lx, ly) {
  const f = META.frames[k];
  if (!f) return false;
  return ALPHA[((f.y + ly) * SW + f.x + lx) * 4 + 3] > 8;
}
function toSprite(cx, cy) {
  return [Math.floor(cx / scale), Math.floor((cy - originY()) / scale)];
}
function hitTest(cx, cy) {
  if (!st) return false;
  const [sx, sy] = toSprite(cx, cy);
  const cw = META.cell_w, ch = META.cell_h;
  for (const d of st.draw) {
    if (!d.id) continue;                       // gunes / zurafa / efektler tiklanmaz
    const lx = sx - d.x, ly = sy - d.y;
    if (lx < 0 || ly < 0 || lx >= cw || ly >= ch) continue;
    if (opaque(d.k, d.f ? cw - 1 - lx : lx, ly)) return true;
  }
  return false;
}

let ignoring = true;
function updateHover(cx, cy) {
  const over = cx != null && hitTest(cx, cy);
  if (over === ignoring) {
    ignoring = !over;
    window.kedi.setIgnore(ignoring);
  }
}
window.addEventListener('mousemove', (e) => updateHover(e.clientX, e.clientY));      // Windows/Linux
window.kedi.on('cursor', (p) => (p ? updateHover(p.x, p.y) : updateHover(null)));    // macOS yoklama

window.addEventListener('mousedown', (e) => {
  if (e.button !== 0 || !st) return;
  const [sx, sy] = toSprite(e.clientX, e.clientY);
  clickAt(st, sx, sy, META.cell_w, META.cell_h, opaque);   // kedi: zipla, Dogis: sevin / bik
});

window.addEventListener('contextmenu', (e) => { e.preventDefault(); window.kedi.menu(); });

// --- ana surecten gelen komutlar -------------------------------------
window.kedi.on('bounds', ({ width, height, scale: z }) => resize(width, height, z));
window.kedi.on('paused', (v) => { paused = v; });
window.kedi.on('scene', () => {
  const others = ORDER.filter((n) => n !== st.scene);
  applyScene(st, others[Math.floor(Math.random() * others.length)]);
});

boot();
