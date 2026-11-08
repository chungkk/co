require('../site/js/engine.js');
const { Pos, Search, MATE } = globalThis.XQ;
const S = new Search(), V = new Search();
const seed = +process.argv[2] || 1, games = +process.argv[3] || 10;
let rs = seed * 7919; const rnd = () => { rs = (rs * 1103515245 + 12345) & 0x7fffffff; return rs / 0x7fffffff; };
const out = [];
const t0 = Date.now();
for (let g = 0; g < games; g++) {
  const p = Pos.start(); let found = 0;
  for (let ply = 0; ply < 160; ply++) {
    const r = S.run(p, { depth: 3 + (rnd() < .5 ? 1 : 0), multipv: 4, timeMs: 400 });
    if (!r.multi.length) break;
    const best = r.multi[0];
    if (best.score > MATE - 500 && ply > 16 && found < 2) {
      const n = MATE - best.score; // plies
      if (n <= 5 && !p.inCheck(p.side)) {
        const v = V.run(p.clone(), { depth: 7, multipv: 2, timeMs: 4000 });
        const b = v.multi[0], s2 = v.multi[1];
        const nb = MATE - b.score;
        if (b.score > MATE - 500 && nb <= 5 && (!s2 || s2.score < MATE - 500 || (MATE - s2.score) > nb + 2)) {
          out.push({ fen: p.toFen(), plies: nb, sol: b.pv.slice(0, nb), game: seed + ':' + g, ply });
          found++;
        }
      }
    }
    let cands = r.multi.filter(x => x.score >= best.score - 60);
    let pick = best.score > MATE - 500 ? best : cands[(rnd() * cands.length) | 0];
    // thỉnh thoảng đi nước kém để tạo thế cờ đa dạng
    if (best.score < MATE - 500 && rnd() < 0.06 && r.all.length > 3) pick = r.all[(rnd() * Math.min(8, r.all.length)) | 0];
    p.make(pick.move);
    if (p.legalMoves().length === 0 || p.repCount() >= 3) { if (process.env.DBG) console.log("end", ply, p.toFen(), p.inCheck(p.side)); break; }
  }
}
require('fs').writeFileSync('mined-' + seed + '.json', JSON.stringify(out));
console.log('seed', seed, 'puzzles', out.length, ((Date.now() - t0) / 1000).toFixed(0) + 's');
