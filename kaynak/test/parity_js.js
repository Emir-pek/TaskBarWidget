// node parity_js.js <tohum> <genislik> <tick>  -> her tick bir ozet satiri
const S = require(require("path").join(__dirname, "..", "scene.js"));
const [seed, W, N] = process.argv.slice(2).map(Number);
S.seedRng(seed);
const st = S.makeState(W);
const out = [S.digest(st)];
for (let t = 0; t < N; t++) {
  const m = t % 300;
  if (m === 150 || m === 158 || m === 166 || m === 230) out.push("poke " + S.poke(st, "dogis"));
  if (t % 977 === 0) out.push("poke " + S.poke(st, ["tarcin", "maya", "zilli"][t % 3]));
  if (t === N >> 1) S.setScreen(st, W - 333);
  S.step(st);
  out.push(S.digest(st));
}
process.stdout.write(out.join("\n") + "\n");
