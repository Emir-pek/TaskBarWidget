// ---- ORTAK SAHNE MOTORU (PowerShell'e birebir portlanacak) ----
const CW = 30, CH = 33;          // sprite hucre olcusu
const STAGE_W = 200;             // pencere ic genisligi
const TICK = 80;                 // ms

const CATS = ["tarcin", "maya", "zilli"];

// anim: [kare adlari], her karenin kac tick surecegi
const ANIM = {
  walk:   { f: ["walk_1","walk_2","walk_3","walk_4"], hold: 2 },
  stand:  { f: ["stand"], hold: 8 },
  sit:    { f: ["sit_a","sit_a","sit_a","sit_blink"], hold: 8 },
  sitwag: { f: ["sit_a","sit_b"], hold: 6 },
  lookup: { f: ["lookup","lookup","lookup","sit_blink"], hold: 8 },
  jump:   { f: ["jump_1","jump_2","jump_3","jump_2","jump_1"], hold: 2 },
  sleep:  { f: ["sleep_a","sleep_b"], hold: 14, bob: [0,-1] },
  yawn:   { f: ["sleep_a","yawn","yawn","stretch","stretch","sleep_a"], hold: 5 },
  rub:    { f: ["rub_a","rub_b"], hold: 5 },
  happy:  { f: ["sit_happy","sit_b"], hold: 5 },
};
const HANIM = {
  hwalk:  { f: ["human_walk_1","human_walk_2","human_walk_3","human_walk_4"], hold: 3 },
  hstand: { f: ["human_stand"], hold: 10 },
  hwave:  { f: ["human_wave_1","human_wave_2","human_wave_3","human_wave_2"], hold: 3 },
  hpet:   { f: ["human_crouch_1","human_crouch_2"], hold: 6 },
};

// sahne tanimlari: her aktor icin hedef x ve anim
const SCENES = {
  parade: { dur: [180, 300], move: 2,
            human: { x: 150, a: "hwalk" },
            cats:  [{ x: 108, a: "walk" }, { x: 68, a: "walk" }, { x: 28, a: "walk" }] },
  play:   { dur: [200, 320], move: 0, flipHuman: true,
            human: { x: 152, a: "hwave" },
            cats:  [{ x: 112, a: "jump" }, { x: 74, a: "lookup" }, { x: 34, a: "sit" }] },
  pet:    { dur: [200, 320], move: 0, flipHuman: true,
            human: { x: 146, a: "hpet" },
            cats:  [{ x: 116, a: "rub" }, { x: 76, a: "happy" }, { x: 36, a: "sitwag" }] },
  nap:    { dur: [250, 400], move: 0,
            human: { x: 150, a: "hstand" },
            cats:  [{ x: 104, a: "sleep" }, { x: 66, a: "yawn" }, { x: 26, a: "sleep" }] },
};
const ORDER = ["parade", "play", "pet", "nap"];

function makeState(screenW) {
  return {
    scene: "parade", t: 0, dur: 200, phase: "run",
    groupX: Math.floor(screenW / 2 - STAGE_W / 2), dir: 1, screenW,
    actors: [
      { name: "human", x: 150, tx: 150, anim: "hwalk", fi: 0, fh: 0, flip: false, y: 0 },
      { name: "tarcin", x: 108, tx: 108, anim: "walk", fi: 0, fh: 0, flip: false, y: 0 },
      { name: "maya",  x: 68,  tx: 68,  anim: "walk", fi: 0, fh: 0, flip: false, y: 0 },
      { name: "zilli",  x: 28,  tx: 28,  anim: "walk", fi: 0, fh: 0, flip: false, y: 0 },
    ],
    fx: [],   // {kind,x,y,life}
  };
}

function applyScene(st, name) {
  const s = SCENES[name];
  st.scene = name; st.t = 0; st.phase = "move";
  st.dur = s.dur[0] + Math.floor(Math.random() * (s.dur[1] - s.dur[0]));
  st.actors[0].tx = s.human.x; st.actors[0].nextAnim = s.human.a;
  st.actors[0].nextFlip = !!s.flipHuman;
  const perm = [0, 1, 2].sort(() => Math.random() - 0.5);   // roller karisir
  for (let i = 0; i < 3; i++) {
    const slot = perm[i];
    st.actors[i + 1].tx = s.cats[slot].x;
    st.actors[i + 1].nextAnim = s.cats[slot].a;
    st.actors[i + 1].nextFlip = false;
  }
}

function frameName(a) {
  const set = a.name === "human" ? HANIM[a.anim] : ANIM[a.anim];
  const f = set.f[a.fi % set.f.length];
  return a.name === "human" ? f : a.name + "_" + f;
}

function step(st) {
  st.t++;
  const s = SCENES[st.scene];

  // --- gecis: aktorler hedef pozisyona yurur ---
  if (st.phase === "move") {
    let moving = false;
    for (const a of st.actors) {
      const d = a.tx - a.x;
      if (Math.abs(d) > 1.5) {
        a.x += Math.sign(d) * 2; a.flip = d < 0;
        a.anim = a.name === "human" ? "hwalk" : "walk";
        moving = true;
      } else {
        a.x = a.tx;
        a.anim = a.nextAnim; a.flip = a.nextFlip;
      }
    }
    if (!moving) { st.phase = "run"; st.t = 0; }
  } else {
    // --- sahne calisiyor ---
    if (s.move) {
      st.groupX += s.move * st.dir;
      if (st.groupX < 8) { st.groupX = 8; st.dir = 1; flipAll(st, false); }
      if (st.groupX > st.screenW - STAGE_W - 8) {
        st.groupX = st.screenW - STAGE_W - 8; st.dir = -1; flipAll(st, true);
      }
    }
    if (st.t > st.dur) {
      const others = ORDER.filter(n => n !== st.scene);
      applyScene(st, others[Math.floor(Math.random() * others.length)]);
    }
  }

  // --- kare ilerlet ---
  for (const a of st.actors) {
    const set = a.name === "human" ? HANIM[a.anim] : ANIM[a.anim];
    a.fh++;
    if (a.fh >= set.hold) { a.fh = 0; a.fi = (a.fi + 1) % set.f.length; }
    // ziplama yuksekligi
    if (a.anim === "jump") {
      const f = set.f[a.fi];
      a.y = (f === "jump_2") ? -5 : (f === "jump_3" ? -3 : 0);
    } else if (set.bob) {
      a.y = set.bob[a.fi % set.bob.length];
    } else a.y = 0;
  }

  // --- efektler ---
  if (st.phase === "run") {
    if (st.scene === "pet" && st.t % 22 === 0) {
      const p = st.actors.find(a => a.anim === "rub") || st.actors[1];
      st.fx.push({ kind: Math.random() < .5 ? "fx_heart" : "fx_heart_s", x: p.x + 4, y: -4, life: 26 });
    }
    if (st.scene === "nap" && st.t % 16 === 0) {
      const sl = st.actors.filter(a => a.anim === "sleep");
      const p = sl.length ? sl[Math.floor(Math.random() * sl.length)] : st.actors[1];
      st.fx.push({ kind: "zzz", x: p.x + 8, y: -2, life: 30 });
    }
    if (st.scene === "play" && st.t % 30 === 0)
      st.fx.push({ kind: "fx_spark", x: st.actors[0].x - 12, y: -14, life: 12 });
  }
  st.fx = st.fx.filter(f => { f.life--; f.y -= 0.5; return f.life > 0; });
}

function flipAll(st, v) { for (const a of st.actors) a.flip = v; }
