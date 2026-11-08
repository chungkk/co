require('../site/js/engine.js');
const { Pos, Search, MATE, K, A, B, N, R, C, P } = globalThis.XQ;
const fs = require('fs');
let all = [];
for (const f of fs.readdirSync('.').filter(f => /^mined-\d+\.json$/.test(f))) all = all.concat(JSON.parse(fs.readFileSync(f)));
const seen = new Set();
const absT = p => Math.abs(p);
function attackersTo(pos, sq, side) { const out = []; for (const m of pos.gen(true, side)) if ((m >> 7) === sq) out.push(m & 127); return out; }
function mirror(fen) { // xoay 180° + đổi màu → bên đi luôn là Đỏ
  const p = Pos.fromFen(fen); const q = new Pos();
  for (let s = 0; s < 90; s++) q.b[89 - s] = -p.b[s];
  q.side = -p.side; q.recompute(); return q;
}
const res = [];
for (const z of all) {
  let pos = Pos.fromFen(z.fen), sol = z.sol;
  if (pos.side < 0) { pos = mirror(z.fen); sol = sol.map(m => (89 - (m & 127)) | ((89 - (m >> 7)) << 7)); }
  const key = pos.toFen(); if (seen.has(key)) continue; seen.add(key);
  // chạy lời giải
  const q = pos.clone(); const movers = []; let ok = true; let sac = false;
  for (let i = 0; i < sol.length; i++) {
    if (!q.legalMoves().includes(sol[i])) { ok = false; break; }
    if (i % 2 === 0) { movers.push(absT(q.b[sol[i] & 127]));
      const t = sol[i] >> 7, val = [0,0,2,2,4,9,4.5,1][absT(q.b[sol[i] & 127])], cap = q.b[t];
      q.make(sol[i]);
      if (q.legalMoves().length && attackersTo(q, t, q.side).length && val >= 4 && !(cap && Math.abs(cap) >= absT(q.b[t]))) sac = true;
      continue; }
    q.make(sol[i]);
  }
  if (!ok || q.legalMoves().length !== 0 || !q.inCheck(q.side)) continue;
  const k = q.kB, kr = (k / 9) | 0, kc = k % 9;
  const checkers = attackersTo(q, k, 1);
  const themes = [];
  if (checkers.length >= 2) themes.push('Song chiếu');
  for (const cs of checkers) {
    const t = absT(q.b[cs]);
    if (t === C) {
      const cr = (cs / 9) | 0, cc = cs % 9, dr = Math.sign(kr - cr), dc = Math.sign(kc - cc);
      let r = cr + dr, c = cc + dc, scr = 0;
      while (r !== kr || c !== kc) { if (q.b[r * 9 + c]) scr = q.b[r * 9 + c]; r += dr; c += dc; }
      if (scr === N) themes.push('Mã hậu pháo');
      else if (scr === C) themes.push('Trùng pháo');
      else if (scr < 0 && (scr === -A || scr === -B) && cr === kr) themes.push('Pháo đáy');
      else if (scr < 0) themes.push('Pháo mượn ngòi');
      else themes.push('Pháo sát');
    } else if (t === R) themes.push(movers.filter(x => x === R).length >= 2 || q.b.filter(x => x === R).length >= 2 && movers.includes(R) && sol.length > 1 ? 'Song xe' : 'Xe sát');
    else if (t === N) themes.push(movers.includes(R) ? 'Xe Mã' : movers.includes(C) ? 'Mã Pháo' : 'Mã sát');
    else if (t === P) themes.push('Tốt sát');
  }
  // bạch diện tướng: ô thoát của tướng đen bị Tướng đỏ khống chế qua lộ mặt
  const rk = q.kR;
  for (const [dr, dc] of [[0, 1], [0, -1], [1, 0], [-1, 0]]) {
    const r = kr + dr, c = kc + dc; if (c < 3 || c > 5 || r < 0 || r > 2) continue;
    if (c === rk % 9 && q.b[r * 9 + c] <= 0) {
      let clear = true; for (let rr = r + 1; rr < ((rk / 9) | 0); rr++) if (q.b[rr * 9 + c]) clear = false;
      if (clear) { themes.push('Bạch diện tướng'); break; }
    }
  }
  if (sac) themes.push('Thí quân');
  const pieces = q.b.filter(x => x !== 0).length;
  res.push({ fen: key, n: (z.plies + 1) / 2, sol, themes: [...new Set(themes)], pieces });
}
const cnt = {}; for (const r of res) for (const t of r.themes) cnt[t] = (cnt[t] || 0) + 1;
console.log(res.length, cnt, res.filter(r=>r.n===1).length, res.filter(r=>r.n===2).length, res.filter(r=>r.n===3).length);
fs.writeFileSync('classified.json', JSON.stringify(res));
