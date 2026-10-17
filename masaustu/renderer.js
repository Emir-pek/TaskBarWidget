// =====================================================================
//  Cizim katmani. Sahne mantigi ortak/scene.js icinde (onizleme ile ayni).
// =====================================================================
const cv = document.getElementById('cv');
const ctx = cv.getContext('2d', { willReadFrequently: true });

let META = null, SHEET = null, st = null;
let scale = 2, paused = false;
let cssW = window.innerWidth, cssH = window.innerHeight;

const HEADROOM = 14;

async function boot() {
  META = await fetch('ortak/sprites.json').then((r) => r.json());
  SHEET = new Image();
  SHEET.src = 'ortak/sprites.png';
  await SHEET.decode();
  resize(cssW, cssH, scale);
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
  if (st) {
    st.screenW = Math.floor(w / scale);
    const max = st.screenW - STAGE_W - 8;
    if (st.groupX > max) st.groupX = Math.max(8, max);
  }
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

function render() {
  ctx.clearRect(0, 0, cssW, cssH);
  for (const a of st.actors)
    draw(frameName(a), (st.groupX + a.x) * scale, (HEADROOM + a.y) * scale, a.flip);
  for (const f of st.fx) {
    const n = f.kind === 'zzz'
      ? 'fx_zzz_' + Math.max(1, Math.min(3, 3 - Math.floor((30 - f.life) / 10)))
      : f.kind;
    draw(n, (st.groupX + f.x) * scale, (HEADROOM + f.y - 14) * scale, false);
  }
}

function tick() {
  if (!paused) step(st);
  render();
}

// --- fare: saydam pikselde tiklama gecsin, karakterde gecmesin -------
let ignoring = true;
function hitTest(cx, cy) {
  const dpr = window.devicePixelRatio || 1;
  const x = Math.round(cx * dpr), y = Math.round(cy * dpr);
  if (x < 0 || y < 0 || x >= cv.width || y >= cv.height) return false;
  return ctx.getImageData(x, y, 1, 1).data[3] > 8;
}

window.addEventListener('mousemove', (e) => {
  const over = hitTest(e.clientX, e.clientY);
  if (over === ignoring) {
    ignoring = !over;
    window.kedi.setIgnore(ignoring);
  }
});

function actorAt(cx) {
  const sx = cx / scale - st.groupX;
  const cw = META.cell_w;
  for (const a of st.actors) {
    if (a.name === 'dogis') continue;      // insana tiklama tepkisi yok
    if (sx >= a.x && sx <= a.x + cw) return a;
  }
  return null;
}

window.addEventListener('mousedown', (e) => {
  if (e.button !== 0) return;
  const a = actorAt(e.clientX);
  if (!a) return;
  a.anim = 'jump'; a.fi = 0; a.fh = 0;
  st.fx.push({ kind: 'fx_heart', x: a.x + 6, y: -4, life: 24 });
  setTimeout(() => { if (a.anim === 'jump') a.anim = a.nextAnim || 'sit'; }, 26 * TICK);
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
