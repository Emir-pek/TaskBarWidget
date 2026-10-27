// =====================================================================
//  ORTAK SAHNE MOTORU
//  onizleme.html ve Electron (masaustu/) bu dosyayi dogrudan calistirir.
//  Windows surumu kaynak/engine.ps1 bunun BIREBIR portudur; ikisi
//  kaynak/test/parity.* ile ayni tohumla tick tick karsilastirilir.
//
//  Butun koordinatlar "sprite pikseli" cinsindendir (cizici Scale ile
//  carpar). Motor her tick sonunda st.draw listesini uretir:
//    { k: kare adi, x, y: hucrenin sol-ust kosesi, f: aynala, id: tiklanabilir aktor }
//  Cizicilerin tek isi bu listeyi sirayla basmaktir.
// =====================================================================

const STAGE_W      = 200;  // grubun ic genisligi
const TICK         = 80;   // ms
const HEADROOM     = 34;   // karakter hucrelerinin ustu: gunes + efekt boslugu
const SUN_TOP      = 0;    // gunes hucresinin ust kenari
const SUN_CX       = 16;   // gunes kanvasinin merkez sutunu
const DECOR_W      = 37;   // zurafa (29) + cicek (19 + 18) toplam ayak izi
const DECOR_MARGIN = 6;    // ekranin sag kenarina bosluk
const FLOWER_DX    = 19;   // cicek kanvasinin zurafa kanvasina gore x kaymasi

// ---- tohumlu rastgele sayi (Park-Miller MINSTD) ----------------------
// Ara degerler 2^53'un altinda kaldigi icin JS ve PowerShell ayni diziyi uretir.
let RNG = 1;
function seedRng(s) { RNG = (Math.floor(Math.abs(s)) % 2147483646) + 1; }
function rnd() { RNG = (RNG * 48271) % 2147483647; return (RNG - 1) / 2147483646; }
function randInt(a, b) { return a + Math.floor(rnd() * (b - a + 1)); }
function shuffle3() {
  const p = [0, 1, 2];
  for (let i = 2; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1));
    const t = p[i]; p[i] = p[j]; p[j] = t;
  }
  return p;
}

// ---- animasyonlar: [kare adlari], her kare kac tick ------------------
const ANIM = {
  walk:   { f: ["walk_1", "walk_2", "walk_3", "walk_4"], hold: 2 },
  stand:  { f: ["stand"], hold: 8 },
  sit:    { f: ["sit_a", "sit_a", "sit_a", "sit_blink"], hold: 8 },
  sitwag: { f: ["sit_a", "sit_b"], hold: 6 },
  lookup: { f: ["lookup", "lookup", "lookup", "sit_blink"], hold: 8 },
  jump:   { f: ["jump_1", "jump_2", "jump_3", "jump_2", "jump_1"], hold: 2 },
  sleep:  { f: ["sleep_a", "sleep_b"], hold: 14, bob: [0, -1] },
  yawn:   { f: ["sleep_a", "yawn", "yawn", "stretch", "stretch", "sleep_a"], hold: 5 },
  rub:    { f: ["rub_a", "rub_b"], hold: 5 },
  happy:  { f: ["sit_happy", "sit_b"], hold: 5 },
};
const HANIM = {
  hwalk:  { f: ["dogis_walk_1", "dogis_walk_2", "dogis_walk_3", "dogis_walk_4"], hold: 3 },
  hstand: { f: ["dogis_stand"], hold: 10 },
  hwave:  { f: ["dogis_wave_1", "dogis_wave_2", "dogis_wave_3", "dogis_wave_2"], hold: 3 },
  hpet:   { f: ["dogis_crouch_1", "dogis_crouch_2"], hold: 6 },   // Dogis bir kediyi seviyor
  hjoy:   { f: ["dogis_pet_1", "dogis_pet_2"], hold: 4 },         // Dogis seviliyor
  hangry: { f: ["dogis_angry_1", "dogis_angry_2"], hold: 5 },     // Dogis bikti
};

// ---- sahneler --------------------------------------------------------
// follow: grup gunesi takip eder. sun: gunesin hizi (piksel/tick).
const SCENES = {
  parade: { dur: [180, 300], follow: true, sun: 0.6,
            dogis: { x: 150, a: "hwalk" },
            cats:  [{ x: 108, a: "walk" }, { x: 68, a: "walk" }, { x: 28, a: "walk" }] },
  play:   { dur: [200, 320], follow: false, sun: 0.1, flipDogis: true,
            dogis: { x: 152, a: "hwave" },
            cats:  [{ x: 112, a: "jump" }, { x: 74, a: "lookup" }, { x: 34, a: "sit" }] },
  pet:    { dur: [200, 320], follow: false, sun: 0.1, flipDogis: true,
            dogis: { x: 146, a: "hpet" },
            cats:  [{ x: 116, a: "rub" }, { x: 76, a: "happy" }, { x: 36, a: "sitwag" }] },
  nap:    { dur: [250, 400], follow: false, sun: 0.1, flipDogis: false,
            dogis: { x: 150, a: "hstand" },
            cats:  [{ x: 104, a: "sleep" }, { x: 66, a: "yawn" }, { x: 26, a: "sleep" }] },
};
const ORDER = ["parade", "play", "pet", "nap"];

// zurafanin koklama dizisi: [kare, tick]
const SNIFF = [["giraffe_lean", 4], ["giraffe_sniff_1", 6], ["giraffe_sniff_2", 6],
               ["giraffe_sniff_1", 6], ["giraffe_sniff_2", 6], ["giraffe_sniff_1", 5],
               ["giraffe_lean", 4]];
const FLWIG = ["flower_1", "flower_2", "flower_1", "flower_3"];

// ---- durum -----------------------------------------------------------
function newActor(name, x, anim) {
  return { name, x, tx: x, anim, nextAnim: anim, fi: 0, fh: 0,
           flip: false, nextFlip: false, y: 0, ov: "", ovT: 0 };
}

function makeState(screenW) {
  const st = {
    scene: "parade", t: 0, clock: 0, dur: 200, phase: "run", screenW,
    groupX: 0, vel: 0, lead: 60,
    sun: { x: 0, dir: 1 },
    dg: { pets: 0, need: 3, last: -1000 },
    dc: { wait: 0, seq: -1, seqT: 0, blink: 0, blinkWait: 0 },
    actors: [newActor("dogis", 150, "hwalk"), newActor("tarcin", 108, "walk"),
             newActor("maya", 68, "walk"), newActor("zilli", 28, "walk")],
    fx: [], draw: [],
  };
  st.groupX = Math.floor(screenW / 2 - STAGE_W / 2);
  st.sun.x = st.groupX + STAGE_W / 2 + 60;
  st.dg.need = randInt(2, 3);
  st.dc.wait = randInt(150, 300);
  st.dc.blinkWait = randInt(40, 120);
  clampWorld(st);
  buildDraw(st);
  return st;
}

// ---- yerlesim ---------------------------------------------------------
function decorX(st)   { return st.screenW - DECOR_MARGIN - DECOR_W; }   // zurafa kanvasinin solu
function groupMax(st) { return Math.max(8, decorX(st) - 8 - STAGE_W); }
function sunMin(st)   { return 24; }
function sunMax(st)   { return Math.max(25, decorX(st) - 24); }

function clampWorld(st) {
  if (st.groupX > groupMax(st)) st.groupX = groupMax(st);
  if (st.groupX < 8) st.groupX = 8;
  if (st.sun.x > sunMax(st)) st.sun.x = sunMax(st);
  if (st.sun.x < sunMin(st)) st.sun.x = sunMin(st);
}
function setScreen(st, w) { st.screenW = w; clampWorld(st); buildDraw(st); }

// grubun gitmek istedigi yer: gunesin biraz gerisi (lead yone gore yumusakca doner)
function followTarget(st) {
  let t = st.sun.x - STAGE_W / 2 - st.lead;
  if (t > groupMax(st)) t = groupMax(st);
  if (t < 8) t = 8;
  return t;
}

// ---- sahne gecisi -----------------------------------------------------
function applyScene(st, name) {
  const s = SCENES[name];
  st.scene = name; st.t = 0; st.phase = "move"; st.vel = 0;
  st.dur = s.dur[0] + Math.floor(rnd() * (s.dur[1] - s.dur[0]));
  st.actors[0].tx = s.dogis.x; st.actors[0].nextAnim = s.dogis.a;
  st.actors[0].nextFlip = !!s.flipDogis;
  const perm = shuffle3();                      // roller her sahnede karisir
  for (let i = 0; i < 3; i++) {
    const slot = perm[i];
    st.actors[i + 1].tx = s.cats[slot].x;
    st.actors[i + 1].nextAnim = s.cats[slot].a;
    st.actors[i + 1].nextFlip = false;
  }
}

function pickNextScene(st) {
  // gunes cok uzaklastiysa once ona yetis
  if (st.scene !== "parade" && Math.abs(followTarget(st) - st.groupX) > 40) return "parade";
  const others = ORDER.filter(n => n !== st.scene);
  return others[Math.floor(rnd() * others.length)];
}

// ---- etkilesim --------------------------------------------------------
function setOv(a, anim, ticks) { a.ov = anim; a.ovT = ticks; a.fi = 0; a.fh = 0; }

function findActor(st, id) {
  for (const a of st.actors) if (a.name === id) return a;
  return null;
}

// Bir aktore tiklandi. Donus: "joy" | "angry" | "jump" | ""
function poke(st, id) {
  const a = findActor(st, id);
  if (!a) return "";
  if (id === "dogis") {
    const d = st.dg;
    if (a.ov === "hangry") {                    // zaten sinirli: biraz daha uzar
      if (a.ovT < 25) a.ovT = 25;
      return "angry";
    }
    if (st.clock - d.last > 150) d.pets = 0;    // ~12 sn sevilmediyse sayac sifirlanir
    d.pets++; d.last = st.clock;
    if (d.pets >= d.need) {                     // 2 ya da 3 sevmede bikar
      setOv(a, "hangry", 64);
      d.pets = 0; d.need = randInt(2, 3);
      st.fx = st.fx.filter(f => f.own !== "dogis");   // kalpler soner
      return "angry";
    }
    setOv(a, "hjoy", 24);
    st.fx.push({ kind: "fx_heart", x: st.groupX + a.x, y: -6, life: 24, own: "dogis" });
    return "joy";
  }
  setOv(a, "jump", 26);
  st.fx.push({ kind: "fx_heart", x: st.groupX + a.x + 6, y: -4, life: 24 });
  return "jump";
}

// Ekran (sprite pikseli) koordinatina tiklama. hit(kare, lx, ly) -> opak mi?
function clickAt(st, sx, sy, cw, ch, hit) {
  for (let i = st.draw.length - 1; i >= 0; i--) {
    const d = st.draw[i];
    if (!d.id) continue;
    const lx = sx - d.x, ly = sy - d.y;
    if (lx < 0 || ly < 0 || lx >= cw || ly >= ch) continue;
    if (hit(d.k, d.f ? cw - 1 - lx : lx, ly)) { poke(st, d.id); return d.id; }
  }
  return "";
}

// ---- kare adi ----------------------------------------------------------
function frameName(a) {
  const an = a.ov || a.anim;
  if (a.name === "dogis") {
    const set = HANIM[an];
    return set.f[a.fi % set.f.length];
  }
  const set = ANIM[an];
  return a.name + "_" + set.f[a.fi % set.f.length];
}

// ---- tick ---------------------------------------------------------------
function step(st) {
  st.t++; st.clock++;
  const s = SCENES[st.scene];
  const dog = st.actors[0];
  const hold = dog.ov === "hangry";             // Dogis sinirliyken grup onu bekler

  // --- gunes suzulur, kenarlarda doner ---
  st.sun.x += s.sun * st.sun.dir;
  if (st.sun.x > sunMax(st)) { st.sun.x = sunMax(st); st.sun.dir = -1; }
  if (st.sun.x < sunMin(st)) { st.sun.x = sunMin(st); st.sun.dir = 1; }
  const wantLead = 60 * st.sun.dir;
  if (st.lead < wantLead) st.lead = Math.min(wantLead, st.lead + 0.5);
  else if (st.lead > wantLead) st.lead = Math.max(wantLead, st.lead - 0.5);

  if (st.phase === "move") {
    // --- gecis: herkes yeni yerine yurur ---
    let moving = false;
    for (const a of st.actors) {
      if (a.ov === "hangry") { moving = true; continue; }
      const d = a.tx - a.x;
      if (Math.abs(d) > 1.5) {
        a.x += Math.sign(d) * 2; a.flip = d < 0;
        a.anim = a.name === "dogis" ? "hwalk" : "walk";
        moving = true;
      } else {
        a.x = a.tx; a.anim = a.nextAnim; a.flip = a.nextFlip;
      }
    }
    if (!moving) { st.phase = "run"; st.t = 0; }
  } else {
    if (s.follow) {
      // --- gunesin pesinden ---
      let v = 0;
      if (!hold) {
        v = (followTarget(st) - st.groupX) * 0.05;
        if (v > 2) v = 2;
        if (v < -2) v = -2;
        if (Math.abs(v) < 0.15) v = 0;
      }
      st.vel = v;
      st.groupX += v;
      clampWorld(st);
      const walking = v !== 0;
      const faceLeft = walking ? v < 0 : st.sun.x < st.groupX + STAGE_W / 2;
      for (const a of st.actors) {
        if (a.name === "dogis") a.anim = walking ? "hwalk" : "hstand";
        else a.anim = walking ? "walk" : "stand";
        a.flip = faceLeft;
      }
    }
    if (st.t > st.dur) applyScene(st, pickNextScene(st));
  }

  // --- kareler ---
  for (const a of st.actors) {
    if (a.ovT > 0) {
      a.ovT--;
      if (a.ovT === 0) { a.ov = ""; a.fi = 0; a.fh = 0; }
    }
    const an = a.ov || a.anim;
    const set = a.name === "dogis" ? HANIM[an] : ANIM[an];
    a.fh++;
    if (a.fh >= set.hold) { a.fh = 0; a.fi = (a.fi + 1) % set.f.length; }
    if (an === "jump") {
      const f = set.f[a.fi];
      a.y = f === "jump_2" ? -5 : (f === "jump_3" ? -3 : 0);
    } else if (set.bob) {
      a.y = set.bob[a.fi % set.bob.length];
    } else {
      a.y = 0;
    }
  }

  // --- zurafa ve cicek ---
  const dc = st.dc;
  if (dc.blink > 0) {
    dc.blink--;
  } else {
    dc.blinkWait--;
    if (dc.blinkWait <= 0) { dc.blink = 3; dc.blinkWait = randInt(50, 140); }
  }
  if (dc.seq < 0) {
    dc.wait--;
    if (dc.wait <= 0) { dc.seq = 0; dc.seqT = 0; }
  } else {
    dc.seqT++;
    if (dc.seqT >= SNIFF[dc.seq][1]) {
      dc.seqT = 0; dc.seq++;
      if (dc.seq === 3) st.fx.push({ kind: "fx_heart_s", x: decorX(st) + 12, y: -6, life: 22 });
      if (dc.seq >= SNIFF.length) { dc.seq = -1; dc.wait = randInt(220, 480); }
    }
  }

  // --- sahne efektleri ---
  if (st.phase === "run") {
    if (st.scene === "pet" && st.t % 22 === 0) {
      let p = st.actors[1];
      for (const a of st.actors) if (a.anim === "rub") { p = a; break; }
      st.fx.push({ kind: rnd() < 0.5 ? "fx_heart" : "fx_heart_s", x: st.groupX + p.x + 4, y: -4, life: 26 });
    }
    if (st.scene === "nap" && st.t % 16 === 0) {
      const sl = st.actors.filter(a => a.anim === "sleep");
      const p = sl.length ? sl[Math.floor(rnd() * sl.length)] : st.actors[1];
      st.fx.push({ kind: "zzz", x: st.groupX + p.x + 8, y: -2, life: 30 });
    }
    if (st.scene === "play" && st.t % 30 === 0)
      st.fx.push({ kind: "fx_spark", x: st.groupX + st.actors[0].x - 12, y: -14, life: 12 });
  }
  st.fx = st.fx.filter(f => { f.life--; f.y -= 0.5; return f.life > 0; });

  buildDraw(st);
}

// ---- cizim listesi ------------------------------------------------------
function buildDraw(st) {
  const out = [];
  // 1) gunes
  out.push({ k: "sun_" + (1 + Math.floor(st.clock / 2) % 4),
             x: Math.floor(st.sun.x) - SUN_CX, y: SUN_TOP, f: false, id: "" });
  // 2) zurafa + cicek (cicek once: zurafanin burnu cicegin ustune gelir)
  const dx = decorX(st);
  const sniffing = st.dc.seq >= 0;
  const fl = FLWIG[Math.floor(st.clock / (sniffing ? 4 : 12)) % 4];
  out.push({ k: fl, x: dx + FLOWER_DX, y: HEADROOM, f: false, id: "" });
  let gf;
  if (sniffing) gf = SNIFF[st.dc.seq][0];
  else if (st.dc.blink > 0) gf = "giraffe_blink";
  else gf = Math.floor(st.clock / 14) % 2 === 1 ? "giraffe_idle_2" : "giraffe_idle_1";
  out.push({ k: gf, x: dx, y: HEADROOM, f: false, id: "" });
  // 3) karakterler
  for (const a of st.actors)
    out.push({ k: frameName(a), x: Math.floor(st.groupX + a.x), y: HEADROOM + a.y, f: a.flip, id: a.name });
  // 4) Dogis'in ofke isareti ve burnundan cikan buhar
  const dog = st.actors[0];
  if (dog.ov === "hangry") {
    const bx = Math.floor(st.groupX + dog.x), by = HEADROOM + dog.y;
    out.push({ k: "fx_anger_" + (1 + Math.floor(st.clock / 4) % 2),
               x: bx + (dog.flip ? 7 : 20), y: by - 29, f: false, id: "" });
    if (frameName(dog) === "dogis_angry_2")
      out.push({ k: "fx_huff", x: bx + (dog.flip ? -5 : 5), y: by - 21, f: dog.flip, id: "" });
  }
  // 5) ucan efektler
  for (const f of st.fx) {
    let k = f.kind;
    if (k === "zzz") k = "fx_zzz_" + Math.max(1, Math.min(3, 3 - Math.floor((30 - f.life) / 10)));
    out.push({ k, x: Math.floor(f.x), y: Math.floor(HEADROOM + f.y - 14), f: false, id: "" });
  }
  st.draw = out;
}

// ---- karsilastirma testi icin tek satirlik ozet -----------------------------
function digest(st) {
  const fl = v => Math.floor(v * 1000);
  let s = st.clock + "|" + st.scene + "|" + st.phase + "|" + fl(st.groupX) + "|" + fl(st.sun.x) +
          "|" + st.sun.dir + "|" + fl(st.lead) + "|" + st.dg.pets + "/" + st.dg.need + "|" + st.fx.length;
  for (const d of st.draw) s += "|" + d.k + "," + d.x + "," + d.y + "," + (d.f ? 1 : 0) + "," + d.id;
  return s;
}

if (typeof module !== "undefined") {
  module.exports = { STAGE_W, TICK, HEADROOM, ANIM, HANIM, SCENES, ORDER, seedRng, rnd,
    makeState, step, setScreen, poke, clickAt, frameName, buildDraw, digest, decorX };
}
