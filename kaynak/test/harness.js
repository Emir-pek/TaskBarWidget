// Motor saglik testi: node kaynak/test/harness.js
const path = require("path");
const S = require(path.join(__dirname, "..", "scene.js"));
const J = require(path.join(__dirname, "..", "assets", "sprites.json"));
const CW = J.cell_w, CH = J.cell_h;
let fail = 0;
const bad = m => { if (fail++ < 20) console.log("HATA:", m); };
for (const W of [400, 960, 1920, 3840]) {
  S.seedRng(12345 + W);
  const st = S.makeState(W);
  const seen = new Set(), scenes = {};
  let angry = 0, joys = 0, maxPetsBeforeAngry = 0, petsRun = 0, sniffs = 0;
  for (let t = 0; t < 30000; t++) {
    // her ~300 tickte Dogis'e arka arkaya 1-4 kez tikla
    if (t % 300 === 150 || t % 300 === 158 || t % 300 === 166) {
      const r = S.poke(st, "dogis");
      if (r === "joy") { joys++; petsRun++; }
      if (r === "angry") { if (petsRun + 1 > maxPetsBeforeAngry) maxPetsBeforeAngry = petsRun + 1; petsRun = 0; angry++; }
    }
    if (t % 300 === 0) petsRun = 0;
    if (t % 977 === 0) S.poke(st, ["tarcin", "maya", "zilli"][t % 3]);
    S.step(st);
    scenes[st.scene] = (scenes[st.scene] || 0) + 1;
    if (st.dc.seq === 1 && st.dc.seqT === 0) sniffs++;
    for (const d of st.draw) {
      seen.add(d.k);
      if (!J.frames[d.k]) bad(`W${W} t${t} bilinmeyen kare ${d.k}`);
      if (!Number.isInteger(d.x) || !Number.isInteger(d.y)) bad(`tamsayi degil ${d.k} ${d.x},${d.y}`);
      if (d.y < -2) bad(`W${W} t${t} ust tasma ${d.k} y=${d.y}`);
      if (d.x < -CW || d.x > W) bad(`W${W} yatay tasma ${d.k} x=${d.x}`);
    }
    const sun = st.draw[0];
    if (sun.x < 0 || sun.x + 33 > W) bad(`W${W} gunes disarda ${sun.x}`);
    const dx = S.decorX(st);
    for (const d of st.draw) if (d.id && d.x + CW / 2 + 10 > dx) bad(`W${W} t${t} ${d.id} zurafaya girdi x=${d.x} decor=${dx}`);
  }
  const all = Object.keys(J.frames).filter(k => !seen.has(k));
  console.log(`W=${W} sahneler`, scenes, `joy=${joys} angry=${angry} enCokSevme=${maxPetsBeforeAngry} koklama=${sniffs}`);
  if (all.length) console.log("  hic cizilmeyen kareler:", all.join(" "));
  if (angry === 0) bad("Dogis hic sinirlenmedi");
  if (maxPetsBeforeAngry > 3) bad("3'ten fazla sevmede sinirlendi");
  if (sniffs === 0) bad("zurafa hic koklamadi");
}
console.log(fail ? `BASARISIZ (${fail})` : "TAMAM");
process.exit(fail ? 1 : 0);
