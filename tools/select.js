const fs = require('fs');
const res = JSON.parse(fs.readFileSync('classified.json'));
const ORDER = ['Mã hậu pháo', 'Trùng pháo', 'Bạch diện tướng', 'Pháo đáy', 'Song chiếu', 'Thí quân', 'Xe Mã', 'Mã Pháo', 'Tốt sát', 'Song xe', 'Mã sát', 'Pháo mượn ngòi', 'Pháo sát', 'Xe sát'];
const LIM = { 'Xe sát': 6, 'Pháo sát': 4, 'Pháo mượn ngòi': 3 };
for (const r of res) r.primary = ORDER.find(t => r.themes.includes(t));
const pick = [];
for (const t of ORDER) {
  const g = res.filter(r => r.primary === t);
  // trộn độ khó: lấy xen kẽ 1, 2, 3 nước; ưu tiên ít quân (dễ nhìn)
  const by = [1, 2, 3].map(n => g.filter(r => r.n === n).sort((a, b) => a.pieces - b.pieces));
  const lim = LIM[t] || 6; const chosen = [];
  let i = 0; while (chosen.length < lim && by.some(x => x.length)) { const b = by[i % 3]; if (b.length) chosen.push(b.shift()); i++; }
  pick.push(...chosen);
}
pick.sort((a, b) => a.n - b.n || ORDER.indexOf(a.primary) - ORDER.indexOf(b.primary));
const out = pick.map((r, i) => ({ id: i + 1, fen: r.fen, n: r.n, sol: r.sol, themes: r.themes, theme: r.primary }));
fs.writeFileSync('../site/js/puzzles.js', '/* Thế cờ sát cục: đào từ ván máy tự đánh, engine kiểm chứng đòn thắng duy nhất */\nself.PUZZLES = ' + JSON.stringify(out) + ';\n');
const c = {}; out.forEach(r => c[r.theme] = (c[r.theme] || 0) + 1);
console.log(out.length, c, [1,2,3].map(n=>out.filter(r=>r.n===n).length));
