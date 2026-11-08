// Nhận diện tên đòn sát từ lời giải (thế cuối phải là chiếu bí, bên giải là Đỏ).
require('../site/js/engine.js');
const { K, A, B, N, R, C, P } = globalThis.XQ;
const absT = (p) => Math.abs(p);
function attackersTo(pos, sq, side) { const out = []; for (const m of pos.gen(true, side)) if ((m >> 7) === sq) out.push(m & 127); return out; }
const ORDER = ['Mã hậu pháo', 'Trùng pháo', 'Bạch diện tướng', 'Pháo đáy', 'Song chiếu', 'Thí quân', 'Xe Mã', 'Mã Pháo', 'Tốt sát', 'Song xe', 'Mã sát', 'Pháo mượn ngòi', 'Pháo sát', 'Xe sát'];
function themeOf(start, sol) {
  const q = start.clone(), movers = [];
  let sac = false;
  for (let i = 0; i < sol.length; i++) {
    if (i % 2 === 0) {
      const t = sol[i] >> 7, pc = absT(q.b[sol[i] & 127]), val = [0, 0, 2, 2, 4, 9, 4.5, 1][pc], cap = q.b[t];
      movers.push(pc);
      q.make(sol[i]);
      if (q.legalMoves().length && attackersTo(q, t, q.side).length && val >= 4 && !(cap && Math.abs(cap) >= pc)) sac = true;
    } else q.make(sol[i]);
  }
  if (q.legalMoves().length !== 0) return null;
  const k = q.kB, kr = (k / 9) | 0, kc = k % 9, themes = [];
  const checkers = attackersTo(q, k, 1);
  if (checkers.length >= 2) themes.push('Song chiếu');
  for (const cs of checkers) {
    const t = absT(q.b[cs]);
    if (t === C) {
      const cr = (cs / 9) | 0, cc = cs % 9, dr = Math.sign(kr - cr), dc = Math.sign(kc - cc);
      let r = cr + dr, c = cc + dc, scr = 0;
      while (r !== kr || c !== kc) { if (q.b[r * 9 + c]) scr = q.b[r * 9 + c]; r += dr; c += dc; }
      if (scr === N) themes.push('Mã hậu pháo');
      else if (scr === C) themes.push('Trùng pháo');
      else if ((scr === -A || scr === -B) && cr === kr) themes.push('Pháo đáy');
      else if (scr < 0) themes.push('Pháo mượn ngòi');
      else themes.push('Pháo sát');
    } else if (t === R) themes.push(movers.filter((x) => x === R).length >= 2 ? 'Song xe' : 'Xe sát');
    else if (t === N) themes.push(movers.includes(R) ? 'Xe Mã' : movers.includes(C) ? 'Mã Pháo' : 'Mã sát');
    else if (t === P) themes.push('Tốt sát');
  }
  const rk = q.kR;
  for (const [dr, dc] of [[0, 1], [0, -1], [1, 0], [-1, 0]]) {
    const r = kr + dr, c = kc + dc;
    if (c < 3 || c > 5 || r < 0 || r > 2) continue;
    if (c === rk % 9 && q.b[r * 9 + c] <= 0) {
      let clear = true;
      for (let rr = r + 1; rr < ((rk / 9) | 0); rr++) if (q.b[rr * 9 + c]) clear = false;
      if (clear) { themes.push('Bạch diện tướng'); break; }
    }
  }
  if (sac) themes.push('Thí quân');
  const uniq = [...new Set(themes)];
  return { themes: uniq, theme: ORDER.find((t) => uniq.includes(t)) || 'Xe sát' };
}
module.exports = { themeOf };
