// =====================================================================
//  Cizim katmani. Sahne mantigi ortak/scene.js icinde (onizleme ve
//  Windows surumu ile ayni). Motor her tick st.draw listesini uretir;
//  burada sadece o liste basilir.
//
//  Kaynak tasarrufu:
//   - Cizim sprite cozunurlugunde yapilir; buyutmeyi compositor CSS ile
//     yapar (image-rendering: pixelated). Retina'da 16 kat az piksel.
//   - Sahne 3 kucuk katmana bolunur: gunes, karakterler, zurafa+cicek.
//     Her katman yalnizca kendi icerigi degisince yeniden cizilir; yer
//     degistirmesi (gunesin suzulmesi, grubun yurumesi) sadece CSS
//     transform'dur -> yeniden raster yok, ekranda kucuk hasar alani.
//   - Pencere gorunmezken (ustu tamamen ortulu, ekran kilitli) motor durur.
// =====================================================================
let META = null, SHEET = null, st = null, ALPHA = null, SW = 0;
let scale = 2, paused = false;
let cssW = window.innerWidth, cssH = window.innerHeight;
let timer = null;

const STAGE_H = () => HEADROOM + META.cell_h;
const PAD_Y = 6;                    // efektler sahnenin biraz ustune tasabilir

// ---- katmanlar ----------------------------------------------------------
function makeLayer(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  c.className = 'layer';
  document.body.appendChild(c);
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  return { cv: c, ctx, w, h, ox: 0, oy: 0, sig: null, pos: '' };
}
let L = null;   // { sun, actors, decor, full }

function buildLayers() {
  if (L) for (const k in L) L[k].cv.remove();
  const cw = META.cell_w, ch = META.cell_h;
  L = {
    full:   makeLayer(Math.max(1, st.screenW), STAGE_H() + PAD_Y),   // nadir: hicbir katmana sigmayan
    decor:  makeLayer(19 + cw, ch),
    actors: makeLayer(STAGE_W + 3 * cw, STAGE_H() + PAD_Y),
    sun:    makeLayer(cw, ch),
  };
  for (const k in L) styleLayer(L[k]);
}
function styleLayer(l) {
  l.cv.style.width = l.w * scale + 'px';
  l.cv.style.height = l.h * scale + 'px';
  l.pos = '';
}
function place(l, ox, oy) {
  l.ox = ox; l.oy = oy;
  const t = `translate(${ox * scale}px,${originY() + oy * scale}px)`;
  if (t !== l.pos) { l.pos = t; l.cv.style.transform = t; }   // compositor: yeniden cizim yok
}
function fits(l, d) {
  const cw = META.cell_w, ch = META.cell_h;
  return d.x >= l.ox && d.y >= l.oy && d.x + cw <= l.ox + l.w && d.y + ch <= l.oy + l.h;
}

function drawTo(l, d) {
  const f = META.frames[d.k];
  if (!f) return;
  const x = d.x - l.ox, y = d.y - l.oy, c = l.ctx;
  if (d.f) {
    c.save();
    c.translate(x + f.w, y); c.scale(-1, 1);
    c.drawImage(SHEET, f.x, f.y, f.w, f.h, 0, 0, f.w, f.h);
    c.restore();
  } else {
    c.drawImage(SHEET, f.x, f.y, f.w, f.h, x, y, f.w, f.h);
  }
}

function originY() { return cssH - STAGE_H() * scale; }

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

  seedRng(Date.now() % 2147483646);
  st = makeState(Math.floor(cssW / scale));
  resize(cssW, cssH, scale);
  setRunning(!document.hidden);
  window.kedi.ready();
}

function resize(w, h, z) {
  cssW = w; cssH = h; scale = z;
  if (!st) return;
  setScreen(st, Math.floor(w / z));
  buildLayers();
  render();
}

function render() {
  const sun = L.sun, dec = L.decor, act = L.actors, full = L.full;
  const groups = { sun: [], decor: [], actors: [], full: [] };
  place(dec, decorX(st), HEADROOM);
  place(act, Math.floor(st.groupX) - 8, -PAD_Y);
  place(full, 0, -PAD_Y);
  for (const d of st.draw) {
    if (d.k.startsWith('sun_')) { place(sun, d.x, d.y); groups.sun.push(d); }
    else if (fits(dec, d) && (d.k.startsWith('giraffe_') || d.k.startsWith('flower_') || !fits(act, d))) groups.decor.push(d);
    else if (fits(act, d)) groups.actors.push(d);
    else groups.full.push(d);
  }
  for (const k in groups) {
    const l = L[k];
    let sig = '';
    for (const d of groups[k]) sig += d.k + ':' + (d.x - l.ox) + ',' + (d.y - l.oy) + (d.f ? 'f' : '') + ';';
    if (sig === l.sig) continue;                 // icerik ayni: hic dokunma
    l.sig = sig;
    l.ctx.clearRect(0, 0, l.w, l.h);
    for (const d of groups[k]) drawTo(l, d);
  }
}

function tick() {
  if (!paused) step(st);
  render();
}

// Gorunmezken (macOS/Windows pencere ortulme takibi, ekran kilidi) motoru durdur.
function setRunning(on) {
  if (on && !timer) { render(); timer = setInterval(tick, TICK); }
  if (!on && timer) { clearInterval(timer); timer = null; }
  window.kedi.visible(on);
}
document.addEventListener('visibilitychange', () => setRunning(!document.hidden));

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
